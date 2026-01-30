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

        var subDevices: [SubDevice] = []
        if isMultiOutput, let subDeviceInfos = getSubDeviceInfos(deviceID: deviceID) {
            subDevices = subDeviceInfos
        }

        return AudioDevice(
            id: deviceID,
            name: name,
            volume: volume,
            isMuted: isMuted,
            isMultiOutput: isMultiOutput,
            subDevices: subDevices
        )
    }

    func getDeviceName(deviceID: AudioDeviceID) -> String? {
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

    /// Get the settable volume element for a device (element 0 for main, or per-channel elements 1, 2, etc.)
    private func getSettableVolumeElement(deviceID: AudioDeviceID) -> UInt32? {
        // First try element 0 (main/master volume)
        if canSetVolumeOnElement(deviceID: deviceID, element: kAudioObjectPropertyElementMain) {
            return kAudioObjectPropertyElementMain
        }

        // If element 0 doesn't work, try per-channel elements (1, 2, etc.)
        // Most devices have at most 8 channels
        for element: UInt32 in 1...8 {
            if canSetVolumeOnElement(deviceID: deviceID, element: element) {
                return element
            }
        }

        return nil
    }

    /// Check if volume can be set on a specific element
    private func canSetVolumeOnElement(deviceID: AudioDeviceID, element: UInt32) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )

        var isSettable: DarwinBoolean = false
        let result = AudioObjectIsPropertySettable(deviceID, &propertyAddress, &isSettable)
        return result == noErr && isSettable.boolValue
    }

    func getVolume(deviceID: AudioDeviceID) -> Float? {
        // Try element 0 first
        if let volume = getVolumeOnElement(deviceID: deviceID, element: kAudioObjectPropertyElementMain) {
            return volume
        }

        // Try per-channel elements as fallback
        for element: UInt32 in 1...8 {
            if let volume = getVolumeOnElement(deviceID: deviceID, element: element) {
                return volume
            }
        }

        return nil
    }

    private func getVolumeOnElement(deviceID: AudioDeviceID, element: UInt32) -> Float? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
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
        guard let element = getSettableVolumeElement(deviceID: deviceID) else {
            // Don't log repeatedly - this is now handled at the UI level
            return false
        }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )

        var newVolume = max(0.0, min(1.0, volume))
        let dataSize = UInt32(MemoryLayout<Float32>.size)

        // If setting per-channel volume, set all available channels
        var success = true
        if element != kAudioObjectPropertyElementMain {
            // Set volume on all available channels
            for channelElement: UInt32 in 1...8 {
                if canSetVolumeOnElement(deviceID: deviceID, element: channelElement) {
                    propertyAddress.mElement = channelElement
                    let result = AudioObjectSetPropertyData(deviceID,
                                                           &propertyAddress,
                                                           0,
                                                           nil,
                                                           dataSize,
                                                           &newVolume)
                    if result != noErr {
                        success = false
                    }
                }
            }
        } else {
            // Set main element volume
            let result = AudioObjectSetPropertyData(deviceID,
                                                   &propertyAddress,
                                                   0,
                                                   nil,
                                                   dataSize,
                                                   &newVolume)
            success = result == noErr
        }

        if success {
            Task { @MainActor in
                refreshCurrentDevice()
            }
        }

        return success
    }

    func canSetVolume(deviceID: AudioDeviceID) -> Bool {
        return getSettableVolumeElement(deviceID: deviceID) != nil
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
            return nil
        }

        // Safely convert CFArray to Swift [String]
        guard let array = cfArray as? [String] else {
            return nil
        }

        return array.compactMap { uid in
            getDeviceIDFromUID(uid: uid)
        }
    }

    func getSubDeviceInfos(deviceID: AudioDeviceID) -> [SubDevice]? {
        guard let subDeviceIDs = getSubDevices(deviceID: deviceID) else {
            return nil
        }

        return subDeviceIDs.compactMap { subDeviceID in
            guard let name = getDeviceName(deviceID: subDeviceID) else { return nil }
            let volume = getVolume(deviceID: subDeviceID) ?? 0.5
            let isMuted = getMuteState(deviceID: subDeviceID) ?? false
            let canSet = canSetVolume(deviceID: subDeviceID)

            return SubDevice(
                id: subDeviceID,
                name: name,
                volume: volume,
                isMuted: isMuted,
                isManuallyAdded: false,
                canSetVolume: canSet
            )
        }
    }

    private func getDeviceIDFromUID(uid: String) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID()
        var uidString: CFString = uid as CFString

        // Use withUnsafeMutablePointer to ensure pointer lifetime for AudioValueTranslation
        let result = withUnsafeMutablePointer(to: &uidString) { uidPtr in
            withUnsafeMutablePointer(to: &deviceID) { devicePtr in
                var translation = AudioValueTranslation(
                    mInputData: uidPtr,
                    mInputDataSize: UInt32(MemoryLayout<CFString>.size),
                    mOutputData: devicePtr,
                    mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                var translationSize = UInt32(MemoryLayout<AudioValueTranslation>.size)

                return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                  &propertyAddress,
                                                  0,
                                                  nil,
                                                  &translationSize,
                                                  &translation)
            }
        }

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
