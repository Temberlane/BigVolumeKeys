//
//  BigVolumeKeysApp.swift
//  BigVolumeKeys
//
//  Created by Thomas Li on 2026-01-30.
//

import SwiftUI

@main
struct BigVolumeKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 BigVolumeKeysApp launched")
        PermissionsManager.shared.requestPermissions()
        print("Bundle path: \(Bundle.main.bundleURL.path)")

        let appState = AppState()
        self.appState = appState
        statusBarController = StatusBarController(appState: appState, permissionsManager: PermissionsManager.shared)
    }
}
