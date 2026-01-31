//
//  BigVolumeKeysApp.swift
//  BigVolumeKeys
//
//  Created by Thomas Li on 2026-01-30.
//

import SwiftUI

@main
struct BigVolumeKeysApp: App {
    @State private var permissionsManager = PermissionsManager.shared
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        print("🚀 BigVolumeKeysApp.init() called")
        // Request permissions on launch
        PermissionsManager.shared.requestPermissions()

        // Log bundle URL path
        print("Bundle path: \(Bundle.main.bundleURL.path)")
    }

    var body: some Scene {
        MenuBarExtra("BigVolumeKeys", systemImage: menuBarIcon) {
            ContentView()
                .environment(permissionsManager)
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("🔄 App became active - Ensuring polling is active")
                PermissionsManager.shared.ensurePollingActive()
                appState.checkPermissions()
            }
        }
    }

    private var menuBarIcon: String {
        guard let device = appState.currentDevice else {
            return "speaker.slash"
        }

        if device.isMuted {
            return "speaker.slash.fill"
        }

        if device.volume == 0 {
            return "speaker.fill"
        } else if device.volume < 0.33 {
            return "speaker.wave.1"
        } else if device.volume < 0.66 {
            return "speaker.wave.2"
        } else {
            return "speaker.wave.3"
        }
    }
}
