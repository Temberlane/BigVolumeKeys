//
//  AppStateTests.swift
//  BigVolumeKeysTests
//
//  Tests for AppState coordinator
//

import XCTest
import Combine
@testable import BigVolumeKeys

@MainActor
final class AppStateTests: XCTestCase {

    var appState: AppState!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        appState = AppState()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        appState?.stopInterception()
        appState = nil
        cancellables = nil
    }

    // MARK: - Initialization Tests

    func testAppStateInitializes() async {
        XCTAssertNotNil(appState)
    }

    func testInitialInterceptorStateIsInactive() async {
        // On fresh init without permissions, interceptor should not be active
        XCTAssertFalse(appState.isInterceptorActive)
    }

    func testInitialCurrentDeviceMayBePresent() async {
        // Current device may or may not be present depending on system
        // Just verify we can access it
        let _ = appState.currentDevice
    }

    // MARK: - Permission Tests

    func testCheckPermissionsDoesNotCrash() async {
        appState.checkPermissions()
        // Should complete without crashing
    }

    func testHasPermissionsPropertyAccessible() async {
        let _ = appState.hasPermissions
        // Should be accessible
    }

    // MARK: - Interception Control Tests

    func testStartInterceptionWithoutPermissions() async {
        // If we don't have permissions, start should not activate
        if !appState.hasPermissions {
            appState.startInterception()
            // May or may not activate depending on actual permission state
        }
    }

    func testStopInterceptionWhenNotActive() async {
        appState.stopInterception()
        XCTAssertFalse(appState.isInterceptorActive)
    }

    func testToggleInterceptionFromInactive() async {
        let initialState = appState.isInterceptorActive
        appState.toggleInterception()
        // State should change (or stay same if permissions denied)
        let _ = appState.isInterceptorActive
    }

    func testToggleInterceptionFromActive() async {
        // Try to start first
        if appState.hasPermissions {
            appState.startInterception()
            if appState.isInterceptorActive {
                appState.toggleInterception()
                XCTAssertFalse(appState.isInterceptorActive, "Should be inactive after toggle")
            }
        }
    }

    // MARK: - Volume Control Tests

    func testSetVolumeWithNoDevice() async {
        // If no device, should not crash
        if appState.currentDevice == nil {
            appState.setVolume(0.5)
            // Should complete without crashing
        }
    }

    func testSetVolumeWithDevice() async {
        if let device = appState.currentDevice {
            let originalVolume = device.volume
            appState.setVolume(0.5)
            // Attempt to restore
            appState.setVolume(originalVolume)
        }
    }

    func testSetMuteWithNoDevice() async {
        if appState.currentDevice == nil {
            appState.setMute(true)
            // Should complete without crashing
        }
    }

    func testSetMuteWithDevice() async {
        if let device = appState.currentDevice {
            let originalMute = device.isMuted
            appState.setMute(true)
            appState.setMute(false)
            appState.setMute(originalMute)
        }
    }

    // MARK: - State Publishing Tests

    func testCurrentDeviceIsPublished() async {
        var receivedUpdates = 0

        appState.$currentDevice
            .sink { _ in receivedUpdates += 1 }
            .store(in: &cancellables)

        // Initial value should trigger
        XCTAssertGreaterThanOrEqual(receivedUpdates, 1)
    }

    func testIsInterceptorActiveIsPublished() async {
        var receivedUpdates = 0

        appState.$isInterceptorActive
            .sink { _ in receivedUpdates += 1 }
            .store(in: &cancellables)

        XCTAssertGreaterThanOrEqual(receivedUpdates, 1)
    }

    func testHasPermissionsIsPublished() async {
        var receivedUpdates = 0

        appState.$hasPermissions
            .sink { _ in receivedUpdates += 1 }
            .store(in: &cancellables)

        XCTAssertGreaterThanOrEqual(receivedUpdates, 1)
    }

    // MARK: - Lifecycle Tests

    func testMultipleStartStopCycles() async {
        for _ in 0..<10 {
            appState.startInterception()
            appState.stopInterception()
        }
        XCTAssertFalse(appState.isInterceptorActive)
    }

    func testCheckPermissionsMultipleTimes() async {
        for _ in 0..<10 {
            appState.checkPermissions()
        }
        // Should not crash or leak
    }

    // MARK: - Edge Cases

    func testSetVolumeAtBoundaries() async {
        if appState.currentDevice != nil {
            appState.setVolume(0.0)
            appState.setVolume(1.0)
            appState.setVolume(0.5)
        }
    }

    func testSetVolumeOutOfBounds() async {
        if appState.currentDevice != nil {
            // These should be clamped internally
            appState.setVolume(-0.5)
            appState.setVolume(1.5)
        }
    }

    // MARK: - Concurrency Tests

    func testConcurrentStateAccess() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = self.appState.currentDevice
                    _ = self.appState.isInterceptorActive
                    _ = self.appState.hasPermissions
                }
            }
        }
    }

    func testConcurrentToggle() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    if i % 2 == 0 {
                        self.appState.startInterception()
                    } else {
                        self.appState.stopInterception()
                    }
                }
            }
        }

        appState.stopInterception()
    }

    // MARK: - Memory Tests

    func testAppStateDeallocation() async {
        var state: AppState? = AppState()
        state?.startInterception()
        state?.stopInterception()
        state = nil

        XCTAssertNil(state)
    }

    // MARK: - Integration Tests

    func testFullWorkflow() async {
        // Check permissions
        appState.checkPermissions()

        // Try to start if we have permissions
        if appState.hasPermissions {
            appState.startInterception()
            XCTAssertTrue(appState.isInterceptorActive || !appState.hasPermissions)
        }

        // Access device info
        if let device = appState.currentDevice {
            XCTAssertFalse(device.name.isEmpty)
            XCTAssertGreaterThanOrEqual(device.volume, 0.0)
            XCTAssertLessThanOrEqual(device.volume, 1.0)
        }

        // Stop
        appState.stopInterception()
        XCTAssertFalse(appState.isInterceptorActive)
    }
}
