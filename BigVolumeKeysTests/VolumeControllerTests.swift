//
//  VolumeControllerTests.swift
//  BigVolumeKeysTests
//
//  Tests for VolumeController
//

import XCTest
import CoreAudio
@testable import BigVolumeKeys

@MainActor
final class VolumeControllerTests: XCTestCase {

    var mockAudioManager: MockAudioDeviceManager!
    var volumeController: VolumeController!

    override func setUp() async throws {
        mockAudioManager = MockAudioDeviceManager()
        volumeController = VolumeController(audioManager: mockAudioManager)
    }

    override func tearDown() async throws {
        mockAudioManager = nil
        volumeController = nil
    }

    // MARK: - Increase Volume Tests

    func testIncreaseVolumeNoDevice() async {
        mockAudioManager.mockCurrentDevice = nil

        volumeController.increaseVolume()

        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 0, "Should not set volume when no device")
    }

    func testIncreaseVolumeFromZero() async {
        let device = createTestDevice(id: 1, volume: 0.0, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.0

        volumeController.increaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.01, accuracy: 0.001)
    }

    func testIncreaseVolumeFromMiddle() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5

        volumeController.increaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.51, accuracy: 0.001)
    }

    func testIncreaseVolumeCapsAtMax() async {
        let device = createTestDevice(id: 1, volume: 0.995, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.995

        volumeController.increaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 1.0, accuracy: 0.001, "Volume should cap at 1.0")
    }

    func testIncreaseVolumeAtMax() async {
        let device = createTestDevice(id: 1, volume: 1.0, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 1.0

        volumeController.increaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 1.0, accuracy: 0.001, "Volume should stay at max")
    }

    func testIncreaseVolumeUnmutesWhenMuted() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: true)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5
        mockAudioManager.mockMuteStates[1] = true

        volumeController.increaseVolume()

        XCTAssertEqual(mockAudioManager.setMuteCallCount, 1, "Should call setMute")
        XCTAssertEqual(mockAudioManager.lastSetMuteValue, false, "Should unmute")
    }

    // MARK: - Decrease Volume Tests

    func testDecreaseVolumeNoDevice() async {
        mockAudioManager.mockCurrentDevice = nil

        volumeController.decreaseVolume()

        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 0, "Should not set volume when no device")
    }

    func testDecreaseVolumeFromFull() async {
        let device = createTestDevice(id: 1, volume: 1.0, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 1.0

        volumeController.decreaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.99, accuracy: 0.001)
    }

    func testDecreaseVolumeFromMiddle() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5

        volumeController.decreaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.49, accuracy: 0.001)
    }

    func testDecreaseVolumeFloorsAtZero() async {
        let device = createTestDevice(id: 1, volume: 0.005, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.005

        volumeController.decreaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.0, accuracy: 0.001, "Volume should floor at 0.0")
    }

    func testDecreaseVolumeAtZero() async {
        let device = createTestDevice(id: 1, volume: 0.0, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.0

        volumeController.decreaseVolume()

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.0, accuracy: 0.001, "Volume should stay at zero")
    }

    func testDecreaseVolumeDoesNotUnmute() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: true)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5

        volumeController.decreaseVolume()

        XCTAssertEqual(mockAudioManager.setMuteCallCount, 0, "Should not affect mute state on decrease")
    }

    // MARK: - Toggle Mute Tests

    func testToggleMuteNoDevice() async {
        mockAudioManager.mockCurrentDevice = nil

        volumeController.toggleMute()

        XCTAssertEqual(mockAudioManager.setMuteCallCount, 0, "Should not set mute when no device")
    }

    func testToggleMuteFromUnmuted() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockMuteStates[1] = false

        volumeController.toggleMute()

        XCTAssertEqual(mockAudioManager.lastSetMuteValue, true, "Should mute when currently unmuted")
    }

    func testToggleMuteFromMuted() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: true)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockMuteStates[1] = true

        volumeController.toggleMute()

        XCTAssertEqual(mockAudioManager.lastSetMuteValue, false, "Should unmute when currently muted")
    }

    // MARK: - Mute/Unmute Direct Tests

    func testMuteDirectly() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false)
        mockAudioManager.mockCurrentDevice = device

        volumeController.mute()

        XCTAssertEqual(mockAudioManager.lastSetMuteValue, true)
    }

    func testUnmuteDirectly() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: true)
        mockAudioManager.mockCurrentDevice = device

        volumeController.unmute()

        XCTAssertEqual(mockAudioManager.lastSetMuteValue, false)
    }

    // MARK: - Multi-Output Device Tests

    func testIncreaseVolumeMultiOutputWithSubDevices() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false, isMultiOutput: true)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5
        mockAudioManager.mockSubDevices[1] = [10, 20, 30]  // 3 sub-devices

        volumeController.increaseVolume()

        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 3, "Should set volume on all sub-devices")
    }

    func testDecreaseVolumeMultiOutputWithSubDevices() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false, isMultiOutput: true)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5
        mockAudioManager.mockSubDevices[1] = [10, 20]  // 2 sub-devices

        volumeController.decreaseVolume()

        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 2, "Should set volume on all sub-devices")
    }

    func testMuteMultiOutputWithSubDevices() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false, isMultiOutput: true)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockSubDevices[1] = [10, 20, 30]

        volumeController.mute()

        XCTAssertEqual(mockAudioManager.setMuteCallCount, 3, "Should mute all sub-devices")
    }

    func testMultiOutputFallbackToAggregateDevice() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false, isMultiOutput: true)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5
        mockAudioManager.mockSubDevices[1] = nil  // No sub-devices available

        volumeController.increaseVolume()

        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 1, "Should fall back to aggregate device")
        XCTAssertEqual(mockAudioManager.lastSetVolumeDeviceID, 1, "Should control the aggregate device directly")
    }

    // MARK: - Volume Step Tests

    func testVolumeStepIs10Percent() async {
        XCTAssertEqual(Double(volumeController.defaultVolumeStep), 0.10, accuracy: 0.001)
    }

    func testVolumeRoundsToNearestStep() async {
        // When current volume is 0.534, increasing should round to nearest 0.01
        let device = createTestDevice(id: 1, volume: 0.534, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.534

        volumeController.increaseVolume()

        // 0.534 + 0.01 = 0.544, rounded to 0.54
        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.54, accuracy: 0.001)
    }

    // MARK: - Error Handling Tests

    func testIncreaseVolumeWhenSetVolumeFails() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.5
        mockAudioManager.shouldFailSetVolume = true

        // Should not crash
        volumeController.increaseVolume()

        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 1, "Should attempt to set volume")
    }

    func testMuteWhenSetMuteFails() async {
        let device = createTestDevice(id: 1, volume: 0.5, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.shouldFailSetMute = true

        // Should not crash
        volumeController.mute()

        XCTAssertEqual(mockAudioManager.setMuteCallCount, 1, "Should attempt to set mute")
    }

    // MARK: - Rapid Operations Tests

    func testMultipleRapidVolumeIncreases() async {
        let device = createTestDevice(id: 1, volume: 0.0, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 0.0

        // Simulate rapid key presses (10 presses at 1% each = 10%)
        for _ in 0..<10 {
            volumeController.increaseVolume()
            mockAudioManager.mockVolumes[1] = mockAudioManager.lastSetVolumeValue ?? 0
        }

        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 10)
        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.10, accuracy: 0.001)
    }

    func testMultipleRapidVolumeDecreases() async {
        let device = createTestDevice(id: 1, volume: 1.0, isMuted: false)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = 1.0

        // 100 decreases at 1% each should reach zero
        for _ in 0..<105 {
            volumeController.decreaseVolume()
            mockAudioManager.mockVolumes[1] = mockAudioManager.lastSetVolumeValue ?? 1
        }

        XCTAssertEqual(Double(mockAudioManager.lastSetVolumeValue ?? 0), 0.0, accuracy: 0.001, "Should reach zero")
    }

    // MARK: - Helper Methods

    private func createTestDevice(
        id: AudioDeviceID,
        volume: Float,
        isMuted: Bool,
        isMultiOutput: Bool = false
    ) -> AudioDevice {
        return AudioDevice(
            id: id,
            name: "Test Device \(id)",
            volume: volume,
            isMuted: isMuted,
            isMultiOutput: isMultiOutput
        )
    }
}
