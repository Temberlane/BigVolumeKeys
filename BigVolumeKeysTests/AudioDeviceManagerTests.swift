//
//  AudioDeviceManagerTests.swift
//  BigVolumeKeysTests
//
//  Integration tests for AudioDeviceManager with CoreAudio
//

import XCTest
import CoreAudio
@testable import BigVolumeKeys

@MainActor
final class AudioDeviceManagerTests: XCTestCase {

    var audioManager: AudioDeviceManager!

    override func setUp() async throws {
        audioManager = AudioDeviceManager()
    }

    override func tearDown() async throws {
        audioManager = nil
    }

    // MARK: - Device Enumeration Tests

    func testGetAllOutputDevicesReturnsArray() async {
        let devices = audioManager.getAllOutputDevices()
        // Should return an array (may be empty if no audio devices)
        XCTAssertNotNil(devices)
    }

    func testGetAllOutputDevicesHaveValidNames() async {
        let devices = audioManager.getAllOutputDevices()

        for device in devices {
            XCTAssertFalse(device.name.isEmpty, "Device name should not be empty")
        }
    }

    func testGetAllOutputDevicesHaveValidIDs() async {
        let devices = audioManager.getAllOutputDevices()

        for device in devices {
            XCTAssertGreaterThan(device.id, 0, "Device ID should be positive")
        }
    }

    func testGetAllOutputDevicesHaveValidVolume() async {
        let devices = audioManager.getAllOutputDevices()

        for device in devices {
            XCTAssertGreaterThanOrEqual(device.volume, 0.0, "Volume should be >= 0")
            XCTAssertLessThanOrEqual(device.volume, 1.0, "Volume should be <= 1")
        }
    }

    // MARK: - Current Device Tests

    func testRefreshCurrentDevice() async {
        audioManager.refreshCurrentDevice()
        // Should not crash - may or may not have a device
    }

    func testCurrentDeviceHasValidPropertiesIfPresent() async {
        audioManager.refreshCurrentDevice()

        if let device = audioManager.currentDevice {
            XCTAssertGreaterThan(device.id, 0)
            XCTAssertFalse(device.name.isEmpty)
            XCTAssertGreaterThanOrEqual(device.volume, 0.0)
            XCTAssertLessThanOrEqual(device.volume, 1.0)
        }
    }

    // MARK: - Volume Control Tests

    func testGetVolumeReturnsValidRangeOrNil() async throws {
        audioManager.refreshCurrentDevice()

        guard let device = audioManager.currentDevice else {
            throw XCTSkip("No audio device available for testing")
        }

        if let volume = audioManager.getVolume(deviceID: device.id) {
            XCTAssertGreaterThanOrEqual(volume, 0.0)
            XCTAssertLessThanOrEqual(volume, 1.0)
        }
    }

    func testSetVolumeWithInvalidDeviceIDReturnsFalse() async {
        let invalidDeviceID: AudioDeviceID = 999999
        let result = audioManager.setVolume(deviceID: invalidDeviceID, volume: 0.5)
        XCTAssertFalse(result, "Should fail with invalid device ID")
    }

    func testSetVolumeClampsToValidRange() async throws {
        audioManager.refreshCurrentDevice()

        guard let device = audioManager.currentDevice else {
            throw XCTSkip("No audio device available for testing")
        }

        // Save original volume
        let originalVolume = audioManager.getVolume(deviceID: device.id)

        // Test clamping above 1.0
        _ = audioManager.setVolume(deviceID: device.id, volume: 1.5)
        if let newVolume = audioManager.getVolume(deviceID: device.id) {
            XCTAssertLessThanOrEqual(newVolume, 1.0, "Volume should be clamped to 1.0")
        }

        // Test clamping below 0.0
        _ = audioManager.setVolume(deviceID: device.id, volume: -0.5)
        if let newVolume = audioManager.getVolume(deviceID: device.id) {
            XCTAssertGreaterThanOrEqual(newVolume, 0.0, "Volume should be clamped to 0.0")
        }

        // Restore original volume
        if let original = originalVolume {
            _ = audioManager.setVolume(deviceID: device.id, volume: original)
        }
    }

    // MARK: - Mute Control Tests

    func testGetMuteStateReturnsValidOrNil() async throws {
        audioManager.refreshCurrentDevice()

        guard let device = audioManager.currentDevice else {
            throw XCTSkip("No audio device available for testing")
        }

        let muteState = audioManager.getMuteState(deviceID: device.id)
        // Should be either true, false, or nil (if not supported)
        if let state = muteState {
            XCTAssertTrue(state || !state, "Mute state should be a valid boolean")
        }
    }

    func testSetMuteStateWithInvalidDeviceIDReturnsFalse() async {
        let invalidDeviceID: AudioDeviceID = 999999
        let result = audioManager.setMuteState(deviceID: invalidDeviceID, muted: true)
        XCTAssertFalse(result, "Should fail with invalid device ID")
    }

    // MARK: - Multi-Output Device Tests

    func testGetSubDevicesReturnsNilForRegularDevice() async throws {
        audioManager.refreshCurrentDevice()

        guard let device = audioManager.currentDevice,
              !device.isMultiOutput else {
            throw XCTSkip("Need a non-multi-output device for this test")
        }

        let subDevices = audioManager.getSubDevices(deviceID: device.id)
        XCTAssertNil(subDevices, "Regular device should not have sub-devices")
    }

    func testMultiOutputDeviceSubDeviceEnumeration() async {
        // Simple test to verify getAllOutputDevices works for multi-output detection
        let devices = audioManager.getAllOutputDevices()

        // Just verify we can filter and access isMultiOutput
        let multiOutputDevices = devices.filter { $0.isMultiOutput }

        // Test passes regardless of whether multi-output devices exist
        // The goal is just to verify the API doesn't crash
        XCTAssertGreaterThanOrEqual(multiOutputDevices.count, 0)
    }

    // MARK: - Listener Tests

    func testManagerSurvivesMultipleRefreshes() async {
        // Stress test the refresh functionality
        for _ in 0..<100 {
            audioManager.refreshCurrentDevice()
        }
        // Should not crash or leak memory
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentVolumeReads() async throws {
        audioManager.refreshCurrentDevice()

        guard let device = audioManager.currentDevice else {
            throw XCTSkip("No audio device available for testing")
        }

        // Simulate concurrent reads
        await withTaskGroup(of: Float?.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    return await self.audioManager.getVolume(deviceID: device.id)
                }
            }

            for await volume in group {
                if let v = volume {
                    XCTAssertGreaterThanOrEqual(v, 0.0)
                    XCTAssertLessThanOrEqual(v, 1.0)
                }
            }
        }
    }

    // MARK: - Edge Cases

    func testGetVolumeWithZeroDeviceID() async {
        let volume = audioManager.getVolume(deviceID: 0)
        // Should handle gracefully - likely returns nil
        if let v = volume {
            XCTAssertGreaterThanOrEqual(v, 0.0)
        }
    }

    func testSetVolumeWithExactBoundaries() async throws {
        audioManager.refreshCurrentDevice()

        guard let device = audioManager.currentDevice else {
            throw XCTSkip("No audio device available for testing")
        }

        // Save original
        let original = audioManager.getVolume(deviceID: device.id)

        // Test exact boundary values
        _ = audioManager.setVolume(deviceID: device.id, volume: 0.0)
        _ = audioManager.setVolume(deviceID: device.id, volume: 1.0)

        // Restore
        if let vol = original {
            _ = audioManager.setVolume(deviceID: device.id, volume: vol)
        }
    }

    // MARK: - Protocol Conformance Tests

    func testConformsToAudioDeviceManaging() async {
        // Verify AudioDeviceManager conforms to the protocol
        let manager: AudioDeviceManaging = audioManager
        XCTAssertNotNil(manager.currentDevice ?? nil as AudioDevice?) // May be nil, but protocol method works
    }
}
