//
//  VolumeHUDPanel.swift
//  BigVolumeKeys
//
//  Floating HUD panel that shows volume changes, mimicking the macOS system volume overlay
//

import AppKit
import SwiftUI

@MainActor
class VolumeHUDPanel {
    static let shared = VolumeHUDPanel()

    private var panel: NSPanel?
    private var hideTimer: Timer?
    private var hostingView: NSHostingView<VolumeHUDView>?

    private var currentVolume: Double = 0
    private var currentDeviceName: String = ""
    private var currentIsMuted: Bool = false

    private let hudWidth: CGFloat = 240
    private let hudHeight: CGFloat = 56

    private init() {}

    func show(volume: Double, deviceName: String, isMuted: Bool) {
        currentVolume = volume
        currentDeviceName = deviceName
        currentIsMuted = isMuted

        hideTimer?.invalidate()

        if panel == nil {
            createPanel()
        }

        updateContent()

        guard let panel = panel else { return }

        // If already visible, just reset the timer (no fade-in needed)
        if panel.isVisible && panel.alphaValue > 0.5 {
            scheduleHide()
            return
        }

        // Fade in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        scheduleHide()
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    private func hide() {
        guard let panel = panel, panel.isVisible else { return }

        let panelRef = panel
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panelRef.animator().alphaValue = 0
        }, completionHandler: {
            panelRef.orderOut(nil)
        })
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: hudWidth, height: hudHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none

        positionPanel(panel)

        let hudView = VolumeHUDView(
            volume: currentVolume,
            deviceName: currentDeviceName,
            isMuted: currentIsMuted
        )

        let hostingView = NSHostingView(rootView: hudView)
        hostingView.frame = NSRect(x: 0, y: 0, width: hudWidth, height: hudHeight)
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - hudWidth / 2
        let y = screenFrame.maxY - hudHeight - 72
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updateContent() {
        hostingView?.rootView = VolumeHUDView(
            volume: currentVolume,
            deviceName: currentDeviceName,
            isMuted: currentIsMuted
        )
    }
}

// MARK: - SwiftUI HUD View

struct VolumeHUDView: View {
    let volume: Double
    let deviceName: String
    let isMuted: Bool

    private var speakerIcon: String {
        if isMuted {
            return "speaker.slash.fill"
        } else if volume == 0 {
            return "speaker.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(deviceName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Image(systemName: speakerIcon)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 16)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track background
                        Capsule()
                            .fill(.white.opacity(0.25))

                        // Filled portion
                        Capsule()
                            .fill(.white)
                            .frame(width: max(0, geo.size.width * (isMuted ? 0 : volume)))
                    }
                }
                .frame(height: 4)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 240)
        .background(
            VisualEffectBackground()
        )
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
