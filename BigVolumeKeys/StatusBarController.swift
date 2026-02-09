//
//  StatusBarController.swift
//  BigVolumeKeys
//
//  Manages NSStatusItem with left-click popover and right-click context menu
//

import AppKit
import SwiftUI
import Combine
import ServiceManagement

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appState: AppState
    private var permissionsManager: PermissionsManager
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    init(appState: AppState, permissionsManager: PermissionsManager) {
        self.appState = appState
        self.permissionsManager = permissionsManager
        super.init()

        setupStatusItem()
        setupPopover()
        observeDeviceChanges()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.slash", accessibilityDescription: "BigVolumeKeys")
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environment(permissionsManager)
                .environmentObject(appState)
        )
    }

    private func observeDeviceChanges() {
        appState.$currentDevice
            .receive(on: RunLoop.main)
            .sink { [weak self] device in
                self?.updateIcon(for: device)
            }
            .store(in: &cancellables)
    }

    // MARK: - Icon

    private func updateIcon(for device: AudioDevice?) {
        let iconName: String
        guard let device = device else {
            iconName = "speaker.slash"
            statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "BigVolumeKeys")
            return
        }

        if device.isMuted {
            iconName = "speaker.slash.fill"
        } else if device.volume == 0 {
            iconName = "speaker.fill"
        } else if device.volume < 0.33 {
            iconName = "speaker.wave.1"
        } else if device.volume < 0.66 {
            iconName = "speaker.wave.2"
        } else {
            iconName = "speaker.wave.3"
        }

        statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "BigVolumeKeys")
    }

    // MARK: - Click Handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            removeEventMonitor()
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            addEventMonitor()
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        // Settings submenu
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()

        let loginItem = NSMenuItem(title: "Start on Login", action: #selector(toggleStartOnLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        settingsSubmenu.addItem(loginItem)

        settingsItem.submenu = settingsSubmenu
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu at the status item
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleStartOnLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle login item: \(error)")
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Event Monitor (close popover on outside click)

    private func addEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.popover.isShown {
                self.popover.performClose(nil)
                self.removeEventMonitor()
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
