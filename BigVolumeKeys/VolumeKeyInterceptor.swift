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
    private let onVolumeUp: () -> Void
    private let onVolumeDown: () -> Void
    private let onMute: () -> Void

    // Volume key codes from NSEvent
    private let NX_KEYTYPE_SOUND_UP: Int32 = 0
    private let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    private let NX_KEYTYPE_MUTE: Int32 = 7

    var isActive: Bool {
        eventTap != nil
    }

    init(onVolumeUp: @escaping () -> Void,
         onVolumeDown: @escaping () -> Void,
         onMute: @escaping () -> Void) {
        self.onVolumeUp = onVolumeUp
        self.onVolumeDown = onVolumeDown
        self.onMute = onMute
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

        // Only handle key down events (keyFlags == 0xA00)
        // Key up is 0xB00, key repeat is 0xA01
        guard keyFlags == 0xA00 else {
            return Unmanaged.passRetained(event)
        }

        // Check if it's a volume key
        var handled = false

        if keyCode == NX_KEYTYPE_SOUND_UP {
            Task { @MainActor in
                self.onVolumeUp()
            }
            handled = true
        } else if keyCode == NX_KEYTYPE_SOUND_DOWN {
            Task { @MainActor in
                self.onVolumeDown()
            }
            handled = true
        } else if keyCode == NX_KEYTYPE_MUTE {
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
