//
//  AudioDeviceTests.swift
//  BigVolumeKeysTests
//
//  Tests for AudioDevice model
//

import XCTest
import CoreAudio
@testable import BigVolumeKeys

final class AudioDeviceTests: XCTestCase {

    // MARK: - Initialization Tests

    func testAudioDeviceInitialization() {
        let device = AudioDevice(
            id: 123,
            name: "Test Speaker",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.id, 123)
        XCTAssertEqual(device.name, "Test Speaker")
        XCTAssertEqual(device.volume, 0.5)
        XCTAssertFalse(device.isMuted)
        XCTAssertFalse(device.isMultiOutput)
    }

    func testAudioDeviceMultiOutputInitialization() {
        let device = AudioDevice(
            id: 456,
            name: "Multi-Output Device",
            volume: 0.75,
            isMuted: true,
            isMultiOutput: true
        )

        XCTAssertEqual(device.id, 456)
        XCTAssertEqual(device.name, "Multi-Output Device")
        XCTAssertEqual(device.volume, 0.75)
        XCTAssertTrue(device.isMuted)
        XCTAssertTrue(device.isMultiOutput)
    }

    // MARK: - Volume Percentage Tests

    func testVolumePercentageAtZero() {
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.0,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.volumePercentage, 0)
    }

    func testVolumePercentageAtFull() {
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 1.0,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.volumePercentage, 100)
    }

    func testVolumePercentageAtHalf() {
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.volumePercentage, 50)
    }

    func testVolumePercentageRoundsDown() {
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.654,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.volumePercentage, 65)
    }

    func testVolumePercentageAt5Percent() {
        let device = AudioDevice(
            id: 1,
            name: "Test",
            volume: 0.05,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.volumePercentage, 5)
    }

    // MARK: - Equatable Tests

    func testDevicesWithSameIDareEqual() {
        let device1 = AudioDevice(
            id: 100,
            name: "Speaker A",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        let device2 = AudioDevice(
            id: 100,
            name: "Speaker B",  // Different name
            volume: 0.8,        // Different volume
            isMuted: true,      // Different mute state
            isMultiOutput: true // Different multi-output state
        )

        XCTAssertEqual(device1, device2, "Devices with same ID should be equal")
    }

    func testDevicesWithDifferentIDareNotEqual() {
        let device1 = AudioDevice(
            id: 100,
            name: "Speaker",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        let device2 = AudioDevice(
            id: 101,
            name: "Speaker",  // Same name
            volume: 0.5,      // Same volume
            isMuted: false,   // Same mute state
            isMultiOutput: false
        )

        XCTAssertNotEqual(device1, device2, "Devices with different ID should not be equal")
    }

    // MARK: - Identifiable Tests

    func testIdentifiableConformance() {
        let device = AudioDevice(
            id: 999,
            name: "Test",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.id, 999)
    }

    // MARK: - Edge Cases

    func testVolumeAtBoundaries() {
        // Test exactly at boundaries
        let deviceMin = AudioDevice(id: 1, name: "Test", volume: 0.0, isMuted: false, isMultiOutput: false)
        let deviceMax = AudioDevice(id: 2, name: "Test", volume: 1.0, isMuted: false, isMultiOutput: false)

        XCTAssertEqual(deviceMin.volume, 0.0)
        XCTAssertEqual(deviceMax.volume, 1.0)
        XCTAssertEqual(deviceMin.volumePercentage, 0)
        XCTAssertEqual(deviceMax.volumePercentage, 100)
    }

    func testEmptyDeviceName() {
        let device = AudioDevice(
            id: 1,
            name: "",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.name, "")
    }

    func testUnicodeDeviceName() {
        let device = AudioDevice(
            id: 1,
            name: "スピーカー 🔊",
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.name, "スピーカー 🔊")
    }

    func testLongDeviceName() {
        let longName = String(repeating: "A", count: 1000)
        let device = AudioDevice(
            id: 1,
            name: longName,
            volume: 0.5,
            isMuted: false,
            isMultiOutput: false
        )

        XCTAssertEqual(device.name.count, 1000)
    }
}
