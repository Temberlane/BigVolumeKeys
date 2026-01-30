//
//  PermissionsManager.swift
//  BigVolumeKeys
//
//  Created by Thomas Li on 2026-01-30.
//

import Foundation
import ApplicationServices
import IOKit.hid
import Observation
import AppKit

@Observable
class PermissionsManager {
    var hasAccessibilityPermission = false
    var hasInputMonitoringPermission = false
    private var hasRequestedAccessibility = false
    private var hasRequestedInputMonitoring = false
    private var pollTimer: Timer?

    static let shared = PermissionsManager()

    private init() {
        print("🔧 PermissionsManager.init() called - Creating singleton")
        // Do initial check synchronously (safe since we're in init)
        checkPermissionsWithoutPrompt()
        // Start polling on main thread
        DispatchQueue.main.async { [weak self] in
            print("🔧 PermissionsManager init async block executing")
            self?.startPolling()
        }
    }

    deinit {
        stopPolling()
    }

    private func startPolling() {
        print("🔧 PermissionsManager.startPolling() - Setting up timer")
        // Ensure timer runs on main run loop
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                print("⏰ Timer fired - Checking permissions")
                DispatchQueue.main.async {
                    self?.checkPermissionsWithoutPrompt()
                }
            }
            // Add to common run loop modes to ensure it fires even during UI interactions
            if let timer = self?.pollTimer {
                RunLoop.main.add(timer, forMode: .common)
                print("✅ Timer added to run loop")
            } else {
                print("❌ Failed to create timer")
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        print("PermissionsManager: Stopped polling")
    }

    func ensurePollingActive() {
        print("🔧 ensurePollingActive() called")
        debugTimerState()
        DispatchQueue.main.async { [weak self] in
            // Always restart the timer to ensure it's active
            self?.pollTimer?.invalidate()
            self?.startPolling()
            // Also do an immediate check
            self?.checkPermissionsWithoutPrompt()
        }
    }

    func debugTimerState() {
        print("🔍 Timer state: \(pollTimer != nil ? "Active" : "nil")")
        print("🔍 Timer valid: \(pollTimer?.isValid ?? false)")
    }

    func checkPermissionsWithoutPrompt() {
        print("🔍 Checking permissions...")
        // Check accessibility without prompting
        let accessibilityStatus = AXIsProcessTrusted()

        // Check input monitoring by attempting to create an event tap (without prompt)
        let inputMonitoringStatus = checkInputMonitoringWithEventTap()

        // Update properties
        let accessibilityChanged = hasAccessibilityPermission != accessibilityStatus
        let inputMonitoringChanged = hasInputMonitoringPermission != inputMonitoringStatus

        hasAccessibilityPermission = accessibilityStatus
        hasInputMonitoringPermission = inputMonitoringStatus

        print("📊 Results - Accessibility: \(accessibilityStatus), Input: \(inputMonitoringStatus)")
        if accessibilityChanged || inputMonitoringChanged {
            print("🔄 Permission status CHANGED")
        }
    }

    private func checkInputMonitoringWithEventTap() -> Bool {
        // Try to create an event tap - if it succeeds, we have permission
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Use listenOnly to avoid triggering a prompt
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            // Event tap creation failed - no permission
            return false
        }

        // Clean up and return success
        CFMachPortInvalidate(eventTap)
        return true
    }

    func requestPermissions() {
        print("PermissionsManager: requestPermissions() called")

        // Request accessibility permission first if not granted
        if !hasAccessibilityPermission && !hasRequestedAccessibility {
            print("PermissionsManager: Requesting accessibility permission")
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
            hasRequestedAccessibility = true

            // Re-check to get updated status after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkPermissionsWithoutPrompt()
            }
            return
        }

        // Only request input monitoring after accessibility is granted (or was already requested)
        if !hasInputMonitoringPermission && !hasRequestedInputMonitoring {
            print("PermissionsManager: Requesting input monitoring permission")
            triggerInputMonitoringPrompt()
            hasRequestedInputMonitoring = true
        }

        // Re-check without prompt to update status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkPermissionsWithoutPrompt()
        }
    }

    private func triggerInputMonitoringPrompt() {
        // Create a temporary event tap to trigger the Input Monitoring permission prompt
        // This is the most reliable way to get macOS to show the app in Input Monitoring settings
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            // If event tap creation fails, the app doesn't have permission
            return
        }

        // Clean up the event tap immediately - we only needed to create it to trigger the prompt
        CFMachPortInvalidate(eventTap)
    }

    func openSystemPreferences() {
        // Open Security & Privacy preferences
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}
