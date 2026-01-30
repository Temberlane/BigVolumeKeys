//
//  VolumeKeyInterceptor.swift
//  BigVolumeKeys
//
//  Intercepts volume keys using event tap
//

import Foundation
import CoreGraphics
import Carbon
import AppKit

class VolumeKeyInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onVolumeUp: (Float) -> Void  // Now takes volume step
    private let onVolumeDown: (Float) -> Void  // Now takes volume step
    private let onMute: () -> Void

    // Volume key codes from NSEvent
    private let NX_KEYTYPE_SOUND_UP: Int32 = 0
    private let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    private let NX_KEYTYPE_MUTE: Int32 = 7

    // Key hold tracking for logarithmic ramping
    private var keyHoldStartTime: Date?
    private var currentHeldKey: Int32?

    // Volume step constants
    private let baseVolumeStep: Float = 0.10  // 10% base step
    private let maxVolumeStep: Float = 0.20   // 20% max step when held
    private let rampDuration: TimeInterval = 2.0  // Time to reach max step

    var isActive: Bool {
        eventTap != nil
    }

    init(onVolumeUp: @escaping (Float) -> Void,
         onVolumeDown: @escaping (Float) -> Void,
         onMute: @escaping () -> Void) {
        self.onVolumeUp = onVolumeUp
        self.onVolumeDown = onVolumeDown
        self.onMute = onMute
    }

    /// Calculate volume step with logarithmic ramping based on hold duration
    private func calculateVolumeStep() -> Float {
        guard let startTime = keyHoldStartTime else {
            return baseVolumeStep
        }

        let holdDuration = Date().timeIntervalSince(startTime)

        // Logarithmic ramping: step = base + (max - base) * log(1 + t) / log(1 + maxT)
        let normalizedTime = min(holdDuration, rampDuration)
        let rampFactor = log(1.0 + normalizedTime) / log(1.0 + rampDuration)
        let step = baseVolumeStep + (maxVolumeStep - baseVolumeStep) * Float(rampFactor)

        return step
    }

    deinit {
        stop()
    }

    // MARK: - Control

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask = CGEventMask(1 << NX_SYSDEFINED)

        // Create event tap
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }

                let interceptor = Unmanaged<VolumeKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap")
            return false
        }

        eventTap = tap

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let runLoopSource = runLoopSource else {
            CFMachPortInvalidate(tap)
            eventTap = nil
            return false
        }

        // Add to main run loop
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: tap, enable: true)

        print("Volume key interceptor started")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        print("Volume key interceptor stopped")
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Check if event tap was disabled (e.g., due to timeout)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            print("Event tap disabled, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // Only handle system-defined events (NX_SYSDEFINED = 14)
        guard type.rawValue == UInt32(NX_SYSDEFINED) else {
            return Unmanaged.passRetained(event)
        }

        // Extract event data
        let nsEvent = NSEvent(cgEvent: event)
        guard nsEvent?.type == .systemDefined,
              nsEvent?.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        // Get key code and flags from event data
        let data1 = Int64(nsEvent?.data1 ?? 0)
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = Int32(data1 & 0x0000FFFF)

        // Handle key events:
        // 0xA00 = key down (initial press)
        // 0xA01 = key repeat (held down)
        // 0xB00 = key up
        let isKeyDown = keyFlags == 0xA00
        let isKeyRepeat = keyFlags == 0xA01
        let isKeyUp = keyFlags == 0xB00

        // Reset hold tracking on key up
        if isKeyUp {
            if keyCode == currentHeldKey {
                keyHoldStartTime = nil
                currentHeldKey = nil
            }
            return Unmanaged.passRetained(event)
        }

        // Only handle key down and repeat events
        guard isKeyDown || isKeyRepeat else {
            return Unmanaged.passRetained(event)
        }

        // Check if it's a volume key
        var handled = false

        if keyCode == NX_KEYTYPE_SOUND_UP || keyCode == NX_KEYTYPE_SOUND_DOWN {
            // Start tracking hold time on initial press
            if isKeyDown {
                keyHoldStartTime = Date()
                currentHeldKey = keyCode
            }

            // Calculate step with logarithmic ramping
            let step = calculateVolumeStep()

            if keyCode == NX_KEYTYPE_SOUND_UP {
                Task { @MainActor in
                    self.onVolumeUp(step)
                }
            } else {
                Task { @MainActor in
                    self.onVolumeDown(step)
                }
            }
            handled = true
        } else if keyCode == NX_KEYTYPE_MUTE && isKeyDown {
            // Only handle mute on initial press, not repeat
            Task { @MainActor in
                self.onMute()
            }
            handled = true
        }

        // Return nil to suppress the event (prevent default behavior)
        // Return event to allow it through
        return handled ? nil : Unmanaged.passRetained(event)
    }
}
