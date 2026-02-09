//
//  VolumeKeyCallbackTests.swift
//  BigVolumeKeysTests
//
//  Tests that volume key callbacks correctly adjust slider values,
//  simulating the exact flow used in AppState when keys are intercepted.
//

import XCTest
import CoreAudio
@testable import BigVolumeKeys

@MainActor
final class VolumeKeyCallbackTests: XCTestCase {

    var mockAudioManager: MockAudioDeviceManager!
    var volumeController: VolumeController!

    // Simulates AppState.sliderValue
    var sliderValue: Double = 0.5

    // Matches VolumeKeyInterceptor.baseVolumeStep
    let baseStep: Float = 0.10

    override func setUp() async throws {
        mockAudioManager = MockAudioDeviceManager()
        volumeController = VolumeController(audioManager: mockAudioManager)
        sliderValue = 0.5
    }

    override func tearDown() async throws {
        mockAudioManager = nil
        volumeController = nil
    }

    // MARK: - Helpers

    /// Replicates the exact callback logic from AppState.startInterception onVolumeUp
    private func simulateVolumeUpKey(step: Float? = nil) {
        let s = step ?? baseStep
        let newVolume = volumeController.increaseVolume(currentVolume: Float(sliderValue), step: s)
        sliderValue = Double(newVolume)
        // Sync mock so next call reads updated volume
        if let deviceID = mockAudioManager.mockCurrentDevice?.id {
            mockAudioManager.mockVolumes[deviceID] = Float(sliderValue)
        }
    }

    /// Replicates the exact callback logic from AppState.startInterception onVolumeDown
    private func simulateVolumeDownKey(step: Float? = nil) {
        let s = step ?? baseStep
        let newVolume = volumeController.decreaseVolume(currentVolume: Float(sliderValue), step: s)
        sliderValue = Double(newVolume)
        if let deviceID = mockAudioManager.mockCurrentDevice?.id {
            mockAudioManager.mockVolumes[deviceID] = Float(sliderValue)
        }
    }

    /// Replicates the exact callback logic from AppState.startInterception onMute
    private func simulateMuteKey() {
        volumeController.toggleMute()
    }

    private func createDevice(
        id: AudioDeviceID = 1,
        volume: Float = 0.5,
        isMuted: Bool = false,
        isMultiOutput: Bool = false
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            name: "Test Speaker",
            volume: volume,
            isMuted: isMuted,
            isMultiOutput: isMultiOutput
        )
    }

    private func setupDevice(volume: Float = 0.5, isMuted: Bool = false, isMultiOutput: Bool = false) {
        let device = createDevice(volume: volume, isMuted: isMuted, isMultiOutput: isMultiOutput)
        mockAudioManager.mockCurrentDevice = device
        mockAudioManager.mockVolumes[1] = volume
        mockAudioManager.mockMuteStates[1] = isMuted
        sliderValue = Double(volume)
    }

    // MARK: - Volume Up Key Tests

    func testVolumeUpKeyIncreasesSliderValue() async {
        setupDevice(volume: 0.5)

        simulateVolumeUpKey()

        XCTAssertGreaterThan(sliderValue, 0.5, "Slider should increase after volume up key")
        XCTAssertEqual(sliderValue, 0.6, accuracy: 0.001, "Should increase by base step (10%)")
    }

    func testVolumeUpKeyFromZero() async {
        setupDevice(volume: 0.0)

        simulateVolumeUpKey()

        XCTAssertEqual(sliderValue, 0.1, accuracy: 0.001, "Should go from 0% to 10%")
        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 1, "Should call setVolume on device")
    }

    func testVolumeUpKeyCapsAtMax() async {
        setupDevice(volume: 0.95)

        simulateVolumeUpKey()

        XCTAssertEqual(sliderValue, 1.0, accuracy: 0.001, "Should cap at 100%")
    }

    func testVolumeUpKeyAtMaxStaysAtMax() async {
        setupDevice(volume: 1.0)

        simulateVolumeUpKey()

        XCTAssertEqual(sliderValue, 1.0, accuracy: 0.001, "Should stay at 100%")
    }

    func testVolumeUpKeyUnmutesWhenMuted() async {
        setupDevice(volume: 0.5, isMuted: true)

        simulateVolumeUpKey()

        XCTAssertEqual(mockAudioManager.lastSetMuteValue, false, "Should unmute on volume up")
        XCTAssertGreaterThan(sliderValue, 0.5, "Slider should still increase")
    }

    // MARK: - Volume Down Key Tests

    func testVolumeDownKeyDecreasesSliderValue() async {
        setupDevice(volume: 0.5)

        simulateVolumeDownKey()

        XCTAssertLessThan(sliderValue, 0.5, "Slider should decrease after volume down key")
        XCTAssertEqual(sliderValue, 0.4, accuracy: 0.001, "Should decrease by base step (10%)")
    }

    func testVolumeDownKeyFromFull() async {
        setupDevice(volume: 1.0)

        simulateVolumeDownKey()

        XCTAssertEqual(sliderValue, 0.9, accuracy: 0.001, "Should go from 100% to 90%")
        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 1, "Should call setVolume on device")
    }

    func testVolumeDownKeyFloorsAtZero() async {
        setupDevice(volume: 0.05)

        simulateVolumeDownKey()

        XCTAssertEqual(sliderValue, 0.0, accuracy: 0.001, "Should floor at 0%")
    }

    func testVolumeDownKeyAtZeroStaysAtZero() async {
        setupDevice(volume: 0.0)

        simulateVolumeDownKey()

        XCTAssertEqual(sliderValue, 0.0, accuracy: 0.001, "Should stay at 0%")
    }

    // MARK: - Mute Key Tests

    func testMuteKeyTogglesMuteOn() async {
        setupDevice(volume: 0.5, isMuted: false)

        simulateMuteKey()

        XCTAssertEqual(mockAudioManager.lastSetMuteValue, true, "Should mute")
    }

    func testMuteKeyTogglesMuteOff() async {
        setupDevice(volume: 0.5, isMuted: true)

        simulateMuteKey()

        XCTAssertEqual(mockAudioManager.lastSetMuteValue, false, "Should unmute")
    }

    func testMuteKeyDoesNotChangeSliderValue() async {
        setupDevice(volume: 0.5, isMuted: false)
        let volumeBefore = sliderValue

        simulateMuteKey()

        XCTAssertEqual(sliderValue, volumeBefore, "Mute should not change slider value")
    }

    // MARK: - Consecutive Key Press Tests

    func testConsecutiveVolumeUpKeys() async {
        setupDevice(volume: 0.0)

        // 5 presses at 10% each = 50%
        for _ in 0..<5 {
            simulateVolumeUpKey()
        }

        XCTAssertEqual(sliderValue, 0.5, accuracy: 0.001, "5 presses from 0% should reach 50%")
        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 5)
    }

    func testConsecutiveVolumeDownKeys() async {
        setupDevice(volume: 1.0)

        // 10 presses at 10% each = 0%
        for _ in 0..<10 {
            simulateVolumeDownKey()
        }

        XCTAssertEqual(sliderValue, 0.0, accuracy: 0.001, "10 presses from 100% should reach 0%")
    }

    func testVolumeUpThenDownReturnsToOriginal() async {
        setupDevice(volume: 0.5)

        simulateVolumeUpKey()
        XCTAssertEqual(sliderValue, 0.6, accuracy: 0.001)

        simulateVolumeDownKey()
        XCTAssertEqual(sliderValue, 0.5, accuracy: 0.001, "Should return to original volume")
    }

    func testFullRangeVolumeUpDoesNotExceedMax() async {
        setupDevice(volume: 0.0)

        // Press 15 times (more than needed to reach 100%)
        for _ in 0..<15 {
            simulateVolumeUpKey()
        }

        XCTAssertEqual(sliderValue, 1.0, accuracy: 0.001, "Should never exceed 1.0")
    }

    func testFullRangeVolumeDownDoesNotGoBelowZero() async {
        setupDevice(volume: 1.0)

        // Press 15 times (more than needed to reach 0%)
        for _ in 0..<15 {
            simulateVolumeDownKey()
        }

        XCTAssertEqual(sliderValue, 0.0, accuracy: 0.001, "Should never go below 0.0")
    }

    // MARK: - Custom Step Size Tests (simulating key hold ramping)

    func testVolumeUpWithLargerStep() async {
        setupDevice(volume: 0.4)

        // Simulates held key at max ramp (20% step)
        simulateVolumeUpKey(step: 0.20)

        // 0.4 + 0.20 = 0.60, roundToStep(0.60, 0.20) = 0.60
        XCTAssertEqual(sliderValue, 0.6, accuracy: 0.001, "Should increase by 20%")
    }

    func testVolumeDownWithLargerStep() async {
        setupDevice(volume: 0.6)

        simulateVolumeDownKey(step: 0.20)

        // 0.6 - 0.20 = 0.40, roundToStep(0.40, 0.20) = 0.40
        XCTAssertEqual(sliderValue, 0.4, accuracy: 0.001, "Should decrease by 20%")
    }

    // MARK: - Multi-Output Device Tests

    func testVolumeUpOnMultiOutputDevice() async {
        setupDevice(volume: 0.5, isMultiOutput: true)
        mockAudioManager.mockSubDevices[1] = [10, 20]
        mockAudioManager.mockVolumes[10] = 0.5
        mockAudioManager.mockVolumes[20] = 0.5

        simulateVolumeUpKey()

        XCTAssertGreaterThan(sliderValue, 0.5, "Slider should increase for multi-output device")
        // Sub-devices should each get a setVolume call
        XCTAssertGreaterThanOrEqual(mockAudioManager.setVolumeCallCount, 2,
                                     "Should set volume on both sub-devices")
    }

    func testVolumeDownOnMultiOutputDevice() async {
        setupDevice(volume: 0.5, isMultiOutput: true)
        mockAudioManager.mockSubDevices[1] = [10, 20]
        mockAudioManager.mockVolumes[10] = 0.5
        mockAudioManager.mockVolumes[20] = 0.5

        simulateVolumeDownKey()

        XCTAssertLessThan(sliderValue, 0.5, "Slider should decrease for multi-output device")
        XCTAssertGreaterThanOrEqual(mockAudioManager.setVolumeCallCount, 2)
    }

    // MARK: - No Device Tests

    func testVolumeUpWithNoDeviceDoesNotCrash() async {
        mockAudioManager.mockCurrentDevice = nil
        sliderValue = 0.5

        simulateVolumeUpKey()

        XCTAssertEqual(sliderValue, 0.5, "Slider should not change without a device")
        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 0)
    }

    func testVolumeDownWithNoDeviceDoesNotCrash() async {
        mockAudioManager.mockCurrentDevice = nil
        sliderValue = 0.5

        simulateVolumeDownKey()

        XCTAssertEqual(sliderValue, 0.5, "Slider should not change without a device")
    }

    func testMuteWithNoDeviceDoesNotCrash() async {
        mockAudioManager.mockCurrentDevice = nil

        simulateMuteKey()

        XCTAssertEqual(mockAudioManager.setMuteCallCount, 0)
    }

    // MARK: - setVolume Failure Tests

    func testVolumeUpStillReturnsNewValueOnSetFailure() async {
        setupDevice(volume: 0.5)
        mockAudioManager.shouldFailSetVolume = true

        simulateVolumeUpKey()

        // VolumeController still returns the calculated volume even if setVolume fails
        XCTAssertEqual(sliderValue, 0.6, accuracy: 0.001,
                       "Slider value should update even if hardware setVolume fails")
    }

    // MARK: - Mute + Volume Interaction Tests

    func testMuteThenVolumeUpUnmutesAndAdjusts() async {
        setupDevice(volume: 0.5, isMuted: false)

        // Mute
        simulateMuteKey()
        XCTAssertEqual(mockAudioManager.lastSetMuteValue, true)

        // Update mock state to reflect muted
        mockAudioManager.mockMuteStates[1] = true
        mockAudioManager.mockCurrentDevice = createDevice(volume: 0.5, isMuted: true)

        // Volume up should unmute and increase
        simulateVolumeUpKey()
        XCTAssertEqual(mockAudioManager.lastSetMuteValue, false, "Should unmute")
        XCTAssertGreaterThan(sliderValue, 0.5, "Slider should increase")
    }
}
