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
    let volumeStep: Float = 0.10  // 5% increments

    init(audioManager: AudioDeviceManaging) {
        self.audioManager = audioManager
    }

    // MARK: - Volume Control

    func increaseVolume(currentVolume: Float) -> Float {
        guard let device = audioManager.currentDevice else { return currentVolume }

        // Unmute if currently muted
        if device.isMuted {
            unmute()
        }

        let newVolume = min(1.0, roundToStep(currentVolume + volumeStep))
        setDeviceVolume(device: device, volume: newVolume)

        return newVolume
    }

    func decreaseVolume(currentVolume: Float) -> Float {
        guard let device = audioManager.currentDevice else { return currentVolume }

        let newVolume = max(0.0, roundToStep(currentVolume - volumeStep))
        setDeviceVolume(device: device, volume: newVolume)

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

    private func setDeviceVolume(device: AudioDevice, volume: Float) {
        if device.isMultiOutput {
            setMultiOutputVolume(deviceID: device.id, volume: volume)
        } else {
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
            // Control each sub-device individually
            for subDeviceID in subDevices {
                _ = audioManager.setVolume(deviceID: subDeviceID, volume: volume)
            }
        } else {
            // Fallback to controlling the aggregate device directly
            _ = audioManager.setVolume(deviceID: deviceID, volume: volume)
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

    private func roundToStep(_ value: Float) -> Float {
        // Round to nearest 0.05
        return round(value / volumeStep) * volumeStep
    }
}
