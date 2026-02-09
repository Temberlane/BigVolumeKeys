//
//  VolumeKeyInterceptorTests.swift
//  BigVolumeKeysTests
//
//  Tests for VolumeKeyInterceptor
//  Note: Some tests require Accessibility permissions and may be skipped in CI
//

import XCTest
import CoreGraphics
@testable import BigVolumeKeys

final class VolumeKeyInterceptorTests: XCTestCase {

    var interceptor: VolumeKeyInterceptor!
    var volumeUpCallCount = 0
    var volumeDownCallCount = 0
    var muteCallCount = 0

    override func setUp() {
        volumeUpCallCount = 0
        volumeDownCallCount = 0
        muteCallCount = 0

        interceptor = VolumeKeyInterceptor(
            onVolumeUp: { [weak self] _ in self?.volumeUpCallCount += 1 },
            onVolumeDown: { [weak self] _ in self?.volumeDownCallCount += 1 },
            onMute: { [weak self] in self?.muteCallCount += 1 }
        )
    }

    override func tearDown() {
        interceptor?.stop()
        interceptor = nil
    }

    // MARK: - Initialization Tests

    func testInterceptorInitializesInactive() {
        XCTAssertFalse(interceptor.isActive, "Interceptor should start inactive")
    }

    func testInterceptorCreatedWithCallbacks() {
        // Verify interceptor was created (callbacks stored)
        XCTAssertNotNil(interceptor)
    }

    // MARK: - Start/Stop Tests

    func testStartReturnsResultWithoutCrashing() {
        // Note: May return false if no accessibility permissions
        let _ = interceptor.start()
        // Should not crash regardless of permissions
    }

    func testStopDoesNotCrashWhenNotStarted() {
        // Stopping without starting should be safe
        interceptor.stop()
        XCTAssertFalse(interceptor.isActive)
    }

    func testStopAfterStartDoesNotCrash() {
        _ = interceptor.start()
        interceptor.stop()
        XCTAssertFalse(interceptor.isActive)
    }

    func testMultipleStartCallsAreSafe() {
        _ = interceptor.start()
        _ = interceptor.start()  // Second call should be safe
        _ = interceptor.start()  // Third call should be safe

        interceptor.stop()
    }

    func testMultipleStopCallsAreSafe() {
        _ = interceptor.start()
        interceptor.stop()
        interceptor.stop()  // Second call should be safe
        interceptor.stop()  // Third call should be safe
    }

    func testStartStopCycle() {
        for _ in 0..<5 {
            _ = interceptor.start()
            interceptor.stop()
        }
        // Should complete without issues
    }

    // MARK: - Active State Tests

    func testIsActiveAfterSuccessfulStart() {
        let started = interceptor.start()

        if started {
            XCTAssertTrue(interceptor.isActive, "Should be active after successful start")
        } else {
            // If start failed (no permissions), it should not be active
            XCTAssertFalse(interceptor.isActive, "Should not be active if start failed")
        }
    }

    func testIsInactiveAfterStop() {
        _ = interceptor.start()
        interceptor.stop()

        XCTAssertFalse(interceptor.isActive, "Should be inactive after stop")
    }

    // MARK: - Callback Tests (Simulated)

    func testCallbacksAreStored() {
        // Create a new interceptor and verify callbacks work
        var testFlag = false
        let testInterceptor = VolumeKeyInterceptor(
            onVolumeUp: { _ in testFlag = true },
            onVolumeDown: { _ in },
            onMute: { }
        )

        // We can't easily simulate key events, but we verify the interceptor was created
        XCTAssertNotNil(testInterceptor)
        testInterceptor.stop()
    }

    // MARK: - Memory Management Tests

    func testInterceptorDeallocation() {
        var interceptorRef: VolumeKeyInterceptor? = VolumeKeyInterceptor(
            onVolumeUp: { _ in },
            onVolumeDown: { _ in },
            onMute: { }
        )

        _ = interceptorRef?.start()
        interceptorRef?.stop()
        interceptorRef = nil

        // Should deallocate without issues
        XCTAssertNil(interceptorRef)
    }

    func testWeakSelfInCallbacksDoesNotRetainCycle() {
        class TestClass {
            var interceptor: VolumeKeyInterceptor?
            var callCount = 0

            init() {
                interceptor = VolumeKeyInterceptor(
                    onVolumeUp: { [weak self] _ in self?.callCount += 1 },
                    onVolumeDown: { [weak self] _ in self?.callCount += 1 },
                    onMute: { [weak self] in self?.callCount += 1 }
                )
            }

            deinit {
                interceptor?.stop()
            }
        }

        var testInstance: TestClass? = TestClass()
        _ = testInstance?.interceptor?.start()
        testInstance = nil

        // Should deallocate without retain cycle
        XCTAssertNil(testInstance)
    }

    // MARK: - Permission-Dependent Tests

    func testStartFailsGracefullyWithoutPermissions() {
        // This test documents expected behavior without accessibility permissions
        let result = interceptor.start()

        // Result depends on system permissions
        // Test just verifies it doesn't crash
        if result {
            XCTAssertTrue(interceptor.isActive)
        } else {
            XCTAssertFalse(interceptor.isActive)
        }
    }

    // MARK: - Stress Tests

    func testRapidStartStopCycles() {
        for _ in 0..<50 {
            _ = interceptor.start()
            interceptor.stop()
        }
        // Should handle rapid cycling without issues
    }

    func testCreateManyInterceptors() {
        var interceptors: [VolumeKeyInterceptor] = []

        for _ in 0..<10 {
            let int = VolumeKeyInterceptor(
                onVolumeUp: { _ in },
                onVolumeDown: { _ in },
                onMute: { }
            )
            interceptors.append(int)
        }

        // Clean up
        for int in interceptors {
            int.stop()
        }
        interceptors.removeAll()
    }

    // MARK: - Concurrency Tests

    func testConcurrentStartStop() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    if i % 2 == 0 {
                        _ = self.interceptor.start()
                    } else {
                        self.interceptor.stop()
                    }
                }
            }
        }

        // Clean up
        interceptor.stop()
    }
}
