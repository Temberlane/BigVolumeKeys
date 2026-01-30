//
//  VolumeController.swift
//  BigVolumeKeys
//
//  Smart volume controller that handles multi-output devices
//

import Foundation
import CoreAudio

@MainActor
class VolumeController {
    private let audioManager: AudioDeviceManaging
    let defaultVolumeStep: Float = 0.10  // 10% default increments

    init(audioManager: AudioDeviceManaging) {
        self.audioManager = audioManager
    }

    // MARK: - Volume Control

    /// Convenience method that uses current device volume
    @discardableResult
    func increaseVolume(step: Float? = nil) -> Float {
        guard let device = audioManager.currentDevice else { return 0 }
        let currentVolume = audioManager.getVolume(deviceID: device.id) ?? device.volume
        return increaseVolume(currentVolume: currentVolume, step: step)
    }

    /// Convenience method that uses current device volume
    @discardableResult
    func decreaseVolume(step: Float? = nil) -> Float {
        guard let device = audioManager.currentDevice else { return 0 }
        let currentVolume = audioManager.getVolume(deviceID: device.id) ?? device.volume
        return decreaseVolume(currentVolume: currentVolume, step: step)
    }

    func increaseVolume(currentVolume: Float, step: Float? = nil) -> Float {
        guard let device = audioManager.currentDevice else { return currentVolume }

        let volumeStep = step ?? defaultVolumeStep

        // Unmute if currently muted
        if device.isMuted {
            unmute()
        }

        let newVolume = min(1.0, roundToStep(currentVolume + volumeStep, step: volumeStep))

        // For multi-output devices, apply relative delta to each sub-device
        if device.isMultiOutput {
            setDeviceVolume(device: device, volume: newVolume, delta: volumeStep)
        } else {
            setDeviceVolume(device: device, volume: newVolume)
        }

        return newVolume
    }

    func decreaseVolume(currentVolume: Float, step: Float? = nil) -> Float {
        guard let device = audioManager.currentDevice else { return currentVolume }

        let volumeStep = step ?? defaultVolumeStep

        let newVolume = max(0.0, roundToStep(currentVolume - volumeStep, step: volumeStep))

        // For multi-output devices, apply relative delta to each sub-device
        if device.isMultiOutput {
            setDeviceVolume(device: device, volume: newVolume, delta: -volumeStep)
        } else {
            setDeviceVolume(device: device, volume: newVolume)
        }

        return newVolume
    }

    func toggleMute() {
        guard let device = audioManager.currentDevice else { return }

        let currentMuteState = audioManager.getMuteState(deviceID: device.id) ?? device.isMuted
        setDeviceMute(device: device, muted: !currentMuteState)
    }

    func mute() {
        guard let device = audioManager.currentDevice else { return }
        setDeviceMute(device: device, muted: true)
    }

    func unmute() {
        guard let device = audioManager.currentDevice else { return }
        setDeviceMute(device: device, muted: false)
    }

    // MARK: - Private Helpers

    private func setDeviceVolume(device: AudioDevice, volume: Float, delta: Float? = nil) {
        if device.isMultiOutput {
            print("""
            🔎 setDeviceVolume: Expected device \(device.id) to be multi-output with sub-devices available.
            Actual: isMultiOutput=true (will attempt per-sub-device control).
            Meaning: we will try to adjust each sub-device; if no sub-devices are returned, we fall back to controlling the aggregate device directly.
            """)
            // For multi-output, apply relative delta instead of absolute volume
            if let delta = delta {
                applyVolumeStepToSubDevices(deviceID: device.id, delta: delta)
            } else {
                setMultiOutputVolume(deviceID: device.id, volume: volume)
            }
        } else {
            print("""
            🔎 setDeviceVolume: Expected device \(device.id) to accept direct volume changes.
            Actual: isMultiOutput=false (will set volume on the default output device).
            Meaning: CoreAudio should apply the volume to the single device; failures are logged in setVolume.
            """)
            _ = audioManager.setVolume(deviceID: device.id, volume: volume)
        }
        // Save the volume to user settings
        UserSettings.shared.lastVolume = volume
    }

    private func setDeviceMute(device: AudioDevice, muted: Bool) {
        if device.isMultiOutput {
            setMultiOutputMute(deviceID: device.id, muted: muted)
        } else {
            _ = audioManager.setMuteState(deviceID: device.id, muted: muted)
        }
    }

    private func setMultiOutputVolume(deviceID: AudioDeviceID, volume: Float) {
        // Try to get sub-devices
        if let subDevices = audioManager.getSubDevices(deviceID: deviceID) {
            print("""
            🔎 setMultiOutputVolume: Expected at least one sub-device for aggregate device \(deviceID).
            Actual: found \(subDevices.count) sub-device(s).
            Meaning: each sub-device will be set individually; if volume doesn't change, check each sub-device's setVolume logs.
            """)
            // Control each sub-device individually
            for subDeviceID in subDevices {
                _ = audioManager.setVolume(deviceID: subDeviceID, volume: volume)
            }
        } else {
            print("""
            🔎 setMultiOutputVolume: Expected sub-device list for aggregate device \(deviceID).
            Actual: sub-device list is nil.
            Meaning: falling back to controlling the aggregate device directly; if that fails, the aggregate device likely does not expose a writable volume property.
            """)
            // Fallback to controlling the aggregate device directly
            _ = audioManager.setVolume(deviceID: deviceID, volume: volume)
        }
    }

    /// Apply relative volume step to all sub-devices (for keyboard control)
    /// Each sub-device's volume is adjusted by the delta, clamping independently
    func applyVolumeStepToSubDevices(deviceID: AudioDeviceID, delta: Float) {
        if let subDevices = audioManager.getSubDevices(deviceID: deviceID) {
            print("""
            🔎 applyVolumeStepToSubDevices: Applying delta \(delta) to \(subDevices.count) sub-device(s).
            """)
            for subDeviceID in subDevices {
                let current = audioManager.getVolume(deviceID: subDeviceID) ?? 0.5
                let newVolume = max(0.0, min(1.0, current + delta))
                _ = audioManager.setVolume(deviceID: subDeviceID, volume: newVolume)
            }
        } else {
            // Fallback to controlling the aggregate device directly
            let current = audioManager.getVolume(deviceID: deviceID) ?? 0.5
            let newVolume = max(0.0, min(1.0, current + delta))
            _ = audioManager.setVolume(deviceID: deviceID, volume: newVolume)
        }
    }

    private func setMultiOutputMute(deviceID: AudioDeviceID, muted: Bool) {
        // Try to get sub-devices
        if let subDevices = audioManager.getSubDevices(deviceID: deviceID) {
            // Control each sub-device individually
            for subDeviceID in subDevices {
                _ = audioManager.setMuteState(deviceID: subDeviceID, muted: muted)
            }
        } else {
            // Fallback to controlling the aggregate device directly
            _ = audioManager.setMuteState(deviceID: deviceID, muted: muted)
        }
    }

    private func roundToStep(_ value: Float, step: Float? = nil) -> Float {
        let volumeStep = step ?? defaultVolumeStep
        return round(value / volumeStep) * volumeStep
    }
}
