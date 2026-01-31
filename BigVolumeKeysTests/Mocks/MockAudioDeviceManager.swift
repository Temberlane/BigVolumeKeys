//
//  MockAudioDeviceManager.swift
//  BigVolumeKeysTests
//
//  Mock implementation of AudioDeviceManaging for testing
//

import Foundation
import CoreAudio
@testable import BigVolumeKeys

@MainActor
class MockAudioDeviceManager: AudioDeviceManaging {
    // Configurable test state
    var mockCurrentDevice: AudioDevice?
    var mockAllDevices: [AudioDevice] = []
    var mockVolumes: [AudioDeviceID: Float] = [:]
    var mockMuteStates: [AudioDeviceID: Bool] = [:]
    var mockSubDevices: [AudioDeviceID: [AudioDeviceID]] = [:]

    // Call tracking
    var refreshCurrentDeviceCallCount = 0
    var setVolumeCallCount = 0
    var setMuteCallCount = 0
    var lastSetVolumeDeviceID: AudioDeviceID?
    var lastSetVolumeValue: Float?
    var lastSetMuteDeviceID: AudioDeviceID?
    var lastSetMuteValue: Bool?

    // Control behavior
    var shouldFailSetVolume = false
    var shouldFailSetMute = false

    var currentDevice: AudioDevice? {
        return mockCurrentDevice
    }

    func refreshCurrentDevice() {
        refreshCurrentDeviceCallCount += 1
    }

    func getAllOutputDevices() -> [AudioDevice] {
        return mockAllDevices
    }

    func getVolume(deviceID: AudioDeviceID) -> Float? {
        return mockVolumes[deviceID]
    }

    func setVolume(deviceID: AudioDeviceID, volume: Float) -> Bool {
        setVolumeCallCount += 1
        lastSetVolumeDeviceID = deviceID
        lastSetVolumeValue = volume

        if shouldFailSetVolume {
            return false
        }

        mockVolumes[deviceID] = volume
        return true
    }

    func getMuteState(deviceID: AudioDeviceID) -> Bool? {
        return mockMuteStates[deviceID]
    }

    func setMuteState(deviceID: AudioDeviceID, muted: Bool) -> Bool {
        setMuteCallCount += 1
        lastSetMuteDeviceID = deviceID
        lastSetMuteValue = muted

        if shouldFailSetMute {
            return false
        }

        mockMuteStates[deviceID] = muted
        return true
    }

    func getSubDevices(deviceID: AudioDeviceID) -> [AudioDeviceID]? {
        return mockSubDevices[deviceID]
    }

    // Helper to reset tracking
    func reset() {
        refreshCurrentDeviceCallCount = 0
        setVolumeCallCount = 0
        setMuteCallCount = 0
        lastSetVolumeDeviceID = nil
        lastSetVolumeValue = nil
        lastSetMuteDeviceID = nil
        lastSetMuteValue = nil
        shouldFailSetVolume = false
        shouldFailSetMute = false
    }
}
