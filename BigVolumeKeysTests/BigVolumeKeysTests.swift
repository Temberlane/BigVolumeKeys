//
//  BigVolumeKeysTests.swift
//  BigVolumeKeysTests
//
//  Integration tests for BigVolumeKeys
//

import XCTest
@testable import BigVolumeKeys

final class BigVolumeKeysTests: XCTestCase {

    // MARK: - Integration Tests

    @MainActor
    func testEndToEndVolumeControlWorkflow() async {
        // Create mock audio manager
        let mockManager = MockAudioDeviceManager()
        let device = AudioDevice(
            id: 1,
            name: "Test Device",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )
        mockManager.mockCurrentDevice = device
        mockManager.mockVolumes[1] = 0.5

        // Create volume controller
        let controller = VolumeController(audioManager: mockManager)

        // Simulate volume key presses
        controller.increaseVolume()
        XCTAssertEqual(Double(mockManager.lastSetVolumeValue ?? 0), 0.55, accuracy: 0.01)

        controller.decreaseVolume()
        mockManager.mockVolumes[1] = 0.55  // Simulate manager update
        XCTAssertEqual(Double(mockManager.lastSetVolumeValue ?? 0), 0.50, accuracy: 0.01)

        controller.toggleMute()
        XCTAssertEqual(mockManager.lastSetMuteValue, true)
    }

    @MainActor
    func testMultiOutputDeviceWorkflow() async {
        let mockManager = MockAudioDeviceManager()
        let multiDevice = AudioDevice(
            id: 1,
            name: "Multi-Output Device",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: true
        )
        mockManager.mockCurrentDevice = multiDevice
        mockManager.mockVolumes[1] = 0.5
        mockManager.mockSubDevices[1] = [10, 20]  // Two sub-devices

        let controller = VolumeController(audioManager: mockManager)

        // Volume change should affect both sub-devices
        controller.increaseVolume()
        XCTAssertEqual(mockManager.setVolumeCallCount, 2, "Should set volume on both sub-devices")
    }

    @MainActor
    func testVolumeStepConsistency() async {
        let mockManager = MockAudioDeviceManager()
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.0,
            isMuted: false,
            isMultiOutput: false
        )
        mockManager.mockCurrentDevice = device
        mockManager.mockVolumes[1] = 0.0

        let controller = VolumeController(audioManager: mockManager)

        // 20 increases should get to 100%
        for i in 0..<20 {
            controller.increaseVolume()
            mockManager.mockVolumes[1] = mockManager.lastSetVolumeValue ?? 0

            let expectedVolume = min(1.0, Float(i + 1) * 0.05)
            XCTAssertEqual(Double(mockManager.lastSetVolumeValue ?? 0), Double(expectedVolume), accuracy: 0.001,
                          "Step \(i + 1) should be \(expectedVolume)")
        }

        // Final volume should be 1.0
        XCTAssertEqual(Double(mockManager.mockVolumes[1] ?? 0), 1.0, accuracy: 0.001)
    }

    @MainActor
    func testVolumeBoundaryBehavior() async {
        let mockManager = MockAudioDeviceManager()
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.98,
            isMuted: false,
            isMultiOutput: false
        )
        mockManager.mockCurrentDevice = device
        mockManager.mockVolumes[1] = 0.98

        let controller = VolumeController(audioManager: mockManager)

        // Increase should cap at 1.0
        controller.increaseVolume()
        XCTAssertEqual(Double(mockManager.lastSetVolumeValue ?? 0), 1.0, accuracy: 0.001)

        // Further increases should stay at 1.0
        mockManager.mockVolumes[1] = 1.0
        controller.increaseVolume()
        XCTAssertEqual(Double(mockManager.lastSetVolumeValue ?? 0), 1.0, accuracy: 0.001)
    }

    @MainActor
    func testMuteUnmuteOnVolumeUp() async {
        let mockManager = MockAudioDeviceManager()
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.5,
            isMuted: true,  // Start muted
            isMultiOutput: false
        )
        mockManager.mockCurrentDevice = device
        mockManager.mockVolumes[1] = 0.5
        mockManager.mockMuteStates[1] = true

        let controller = VolumeController(audioManager: mockManager)

        // Volume up should unmute first
        controller.increaseVolume()

        XCTAssertEqual(mockManager.lastSetMuteValue, false, "Should unmute on volume up")
        XCTAssertGreaterThanOrEqual(mockManager.setMuteCallCount, 1)
    }

    // MARK: - Performance Tests

    @MainActor
    func testVolumeControlPerformance() async {
        let mockManager = MockAudioDeviceManager()
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )
        mockManager.mockCurrentDevice = device
        mockManager.mockVolumes[1] = 0.5

        let controller = VolumeController(audioManager: mockManager)

        measure {
            for _ in 0..<1000 {
                controller.increaseVolume()
                controller.decreaseVolume()
            }
        }
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testGracefulHandlingOfMissingDevice() async {
        let mockManager = MockAudioDeviceManager()
        mockManager.mockCurrentDevice = nil

        let controller = VolumeController(audioManager: mockManager)

        // None of these should crash
        controller.increaseVolume()
        controller.decreaseVolume()
        controller.toggleMute()
        controller.mute()
        controller.unmute()

        XCTAssertEqual(mockManager.setVolumeCallCount, 0)
        XCTAssertEqual(mockManager.setMuteCallCount, 0)
    }

    @MainActor
    func testHandlingOfFailedVolumeSet() async {
        let mockManager = MockAudioDeviceManager()
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )
        mockManager.mockCurrentDevice = device
        mockManager.mockVolumes[1] = 0.5
        mockManager.shouldFailSetVolume = true

        let controller = VolumeController(audioManager: mockManager)

        // Should not crash even when setVolume fails
        controller.increaseVolume()
        XCTAssertEqual(mockManager.setVolumeCallCount, 1, "Should still attempt to set volume")
    }
}
