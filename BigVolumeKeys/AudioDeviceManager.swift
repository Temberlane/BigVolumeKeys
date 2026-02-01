//
//  AudioDeviceManager.swift
//  BigVolumeKeys
//
//  Manages CoreAudio device enumeration, monitoring, and volume control
//

import Foundation
import CoreAudio
import Combine

@MainActor
class AudioDeviceManager: ObservableObject {
    @Published private(set) var currentDevice: AudioDevice?
    @Published private(set) var allDevices: [AudioDevice] = []

    private var deviceListenerAdded = false
    private var volumeListenerAdded = false
    private var muteListenerAdded = false

    init() {
        setupDefaultDeviceListener()
        refreshCurrentDevice()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Device Enumeration

    func refreshCurrentDevice() {
        guard let deviceID = getDefaultOutputDeviceID() else {
            currentDevice = nil
            return
        }

        currentDevice = getDeviceInfo(deviceID: deviceID)
    }

    func getAllOutputDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &propertyAddress,
                                             0,
                                             nil,
                                             &dataSize) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                        &propertyAddress,
                                        0,
                                        nil,
                                        &dataSize,
                                        &deviceIDs) == noErr else {
            return []
        }

        return deviceIDs.compactMap { deviceID in
            // Filter to output devices only
            guard hasOutputStreams(deviceID: deviceID) else { return nil }
            return getDeviceInfo(deviceID: deviceID)
        }
    }

    // MARK: - Device Information

    private func getDefaultOutputDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                        &propertyAddress,
                                        0,
                                        nil,
                                        &dataSize,
                                        &deviceID) == noErr else {
            return nil
        }

        return deviceID
    }

    private func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDevice? {
        guard let name = getDeviceName(deviceID: deviceID) else { return nil }

        let volume = getVolume(deviceID: deviceID) ?? 0.5
        let isMuted = getMuteState(deviceID: deviceID) ?? false
        let isMultiOutput = checkIfMultiOutput(deviceID: deviceID)

        return AudioDevice(
            id: deviceID,
            name: name,
            volume: volume,
            isMuted: isMuted,
            isMultiOutput: isMultiOutput
        )
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID,
                                             &propertyAddress,
                                             0,
                                             nil,
                                             &dataSize) == noErr else {
            return nil
        }

        var name: CFString = "" as CFString
        guard AudioObjectGetPropertyData(deviceID,
                                        &propertyAddress,
                                        0,
                                        nil,
                                        &dataSize,
                                        &name) == noErr else {
            return nil
        }

        return name as String
    }

    private func hasOutputStreams(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID,
                                             &propertyAddress,
                                             0,
                                             nil,
                                             &dataSize) == noErr else {
            return false
        }

        return dataSize > 0
    }

    private func checkIfMultiOutput(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyFullSubDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let result = AudioObjectGetPropertyDataSize(deviceID,
                                                    &propertyAddress,
                                                    0,
                                                    nil,
                                                    &dataSize)

        return result == noErr && dataSize > 0
    }

    // MARK: - Volume Control

    func getVolume(deviceID: AudioDeviceID) -> Float? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float32 = 0.0
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        let result = AudioObjectGetPropertyData(deviceID,
                                               &propertyAddress,
                                               0,
                                               nil,
                                               &dataSize,
                                               &volume)

        return result == noErr ? volume : nil
    }

    func setVolume(deviceID: AudioDeviceID, volume: Float) -> Bool {
        let isSettable = canSetVolume(deviceID: deviceID)
        if !isSettable {
            print("""
            🔎 setVolume: Expected device \(deviceID) to be settable. Actual: not settable.
            Meaning: The device doesn't expose a writable kAudioDevicePropertyVolumeScalar on the main output element, so volume changes will be ignored.
            """)
            return false
        }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var newVolume = max(0.0, min(1.0, volume))
        let dataSize = UInt32(MemoryLayout<Float32>.size)

        let result = AudioObjectSetPropertyData(deviceID,
                                               &propertyAddress,
                                               0,
                                               nil,
                                               dataSize,
                                               &newVolume)

        if result == noErr {
            Task { @MainActor in
                refreshCurrentDevice()
            }
        }

        print("""
        🔎 setVolume: Expected AudioObjectSetPropertyData to return noErr for device \(deviceID) with volume \(newVolume).
        Actual: \(result == noErr ? "noErr (success)" : "OSStatus \(result) (failure)").
        Meaning: success means CoreAudio accepted the new volume; failure means the device rejected the update or the property is not writable.
        """)

        return result == noErr
    }

    private func canSetVolume(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var isSettable: DarwinBoolean = false
        let result = AudioObjectIsPropertySettable(deviceID,
                                                   &propertyAddress,
                                                   &isSettable)

        print("""
        🔎 canSetVolume: Expected AudioObjectIsPropertySettable to return noErr and isSettable=true for device \(deviceID).
        Actual: \(result == noErr ? "noErr" : "OSStatus \(result)") + isSettable=\(isSettable.boolValue).
        Meaning: noErr+true means volume can be written; noErr+false means the device exposes volume but is read-only; non-noErr means CoreAudio could not query the property.
        """)

        return result == noErr && isSettable.boolValue
    }

    // MARK: - Mute Control

    func getMuteState(deviceID: AudioDeviceID) -> Bool? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var mute: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let result = AudioObjectGetPropertyData(deviceID,
                                               &propertyAddress,
                                               0,
                                               nil,
                                               &dataSize,
                                               &mute)

        return result == noErr ? mute != 0 : nil
    }

    func setMuteState(deviceID: AudioDeviceID, muted: Bool) -> Bool {
        guard canSetMute(deviceID: deviceID) else { return false }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var muteValue: UInt32 = muted ? 1 : 0
        let dataSize = UInt32(MemoryLayout<UInt32>.size)

        let result = AudioObjectSetPropertyData(deviceID,
                                               &propertyAddress,
                                               0,
                                               nil,
                                               dataSize,
                                               &muteValue)

        if result == noErr {
            Task { @MainActor in
                refreshCurrentDevice()
            }
        }

        return result == noErr
    }

    private func canSetMute(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var isSettable: DarwinBoolean = false
        let result = AudioObjectIsPropertySettable(deviceID,
                                                   &propertyAddress,
                                                   &isSettable)

        return result == noErr && isSettable.boolValue
    }

    // MARK: - Multi-Output Sub-devices

    func getSubDevices(deviceID: AudioDeviceID) -> [AudioDeviceID]? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyFullSubDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID,
                                             &propertyAddress,
                                             0,
                                             nil,
                                             &dataSize) == noErr else {
            print("⚠️ getSubDevices: No sub-devices property for device \(deviceID)")
            return nil
        }

        // The property returns a CFArray, not a C array
        var cfArray: CFArray?
        guard AudioObjectGetPropertyData(deviceID,
                                        &propertyAddress,
                                        0,
                                        nil,
                                        &dataSize,
                                        &cfArray) == noErr else {
            print("⚠️ getSubDevices: Failed to get property data for device \(deviceID)")
            return nil
        }

        // Safely convert CFArray to Swift [String]
        guard let array = cfArray as? [String] else {
            print("⚠️ getSubDevices: Failed to convert CFArray to [String] for device \(deviceID)")
            return nil
        }

        print("📱 getSubDevices: Found \(array.count) sub-device UIDs for device \(deviceID)")
        return array.compactMap { uid in
            getDeviceIDFromUID(uid: uid)
        }
    }

    private func getDeviceIDFromUID(uid: String) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var uidString = uid as CFString

        let result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                               &propertyAddress,
                                               UInt32(MemoryLayout<CFString>.size),
                                               &uidString,
                                               &dataSize,
                                               &deviceID)

        return result == noErr ? deviceID : nil
    }

    // MARK: - Listeners

    private func setupDefaultDeviceListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { _, _, _, userData in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<AudioDeviceManager>.fromOpaque(userData).takeUnretainedValue()

            Task { @MainActor in
                manager.refreshCurrentDevice()
            }

            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject),
                                      &propertyAddress,
                                      callback,
                                      selfPtr)

        deviceListenerAdded = true
    }

    nonisolated private func removeListeners() {
        // Listeners will be automatically removed when the app terminates
        // We can't reliably remove them in deinit due to actor isolation
    }
}
