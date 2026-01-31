//
//  AppState.swift
//  BigVolumeKeys
//
//  Coordinates all managers and exposes observable state to SwiftUI
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    // Published state
    @Published var currentDevice: AudioDevice?
    @Published var isInterceptorActive = false
    @Published var hasPermissions = false

    // Managers
    private let audioManager: AudioDeviceManager
    private let volumeController: VolumeController
    private var volumeKeyInterceptor: VolumeKeyInterceptor?
    private let permissionsManager: PermissionsManager

    init() {
        self.audioManager = AudioDeviceManager()
        self.volumeController = VolumeController(audioManager: audioManager)
        self.permissionsManager = PermissionsManager.shared

        // Setup observers
        setupObservers()

        // Start observing permissions with a timer as backup
        startPermissionObserver()

        // Check initial permissions
        checkPermissions()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe audio manager changes
        Task {
            for await _ in NotificationCenter.default.notifications(named: NSNotification.Name("AudioDeviceChanged")) {
                await updateCurrentDevice()
            }
        }
    }

    private func startPermissionObserver() {
        // Poll AppState's permission check every 5 seconds as backup
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }

    // MARK: - Permissions

    func checkPermissions() {
        let hasAccess = permissionsManager.hasAccessibilityPermission
        let hasMonitor = permissionsManager.hasInputMonitoringPermission

        hasPermissions = hasAccess && hasMonitor

        if hasPermissions && !isInterceptorActive {
            startInterception()
        } else if !hasPermissions && isInterceptorActive {
            stopInterception()
        }
    }

    // MARK: - Interception Control

    func startInterception() {
        guard hasPermissions else {
            print("Cannot start interception: missing permissions")
            return
        }

        guard volumeKeyInterceptor == nil else {
            print("Interceptor already running")
            return
        }

        volumeKeyInterceptor = VolumeKeyInterceptor(
            onVolumeUp: { [weak self] in
                Task { @MainActor in
                    self?.volumeController.increaseVolume()
                    self?.updateCurrentDevice()
                }
            },
            onVolumeDown: { [weak self] in
                Task { @MainActor in
                    self?.volumeController.decreaseVolume()
                    self?.updateCurrentDevice()
                }
            },
            onMute: { [weak self] in
                Task { @MainActor in
                    self?.volumeController.toggleMute()
                    self?.updateCurrentDevice()
                }
            }
        )

        if volumeKeyInterceptor?.start() == true {
            isInterceptorActive = true
            updateCurrentDevice()
            print("Volume key interception started")
        } else {
            volumeKeyInterceptor = nil
            isInterceptorActive = false
            print("Failed to start volume key interception")
        }
    }

    func stopInterception() {
        volumeKeyInterceptor?.stop()
        volumeKeyInterceptor = nil
        isInterceptorActive = false
        print("Volume key interception stopped")
    }

    func toggleInterception() {
        if isInterceptorActive {
            stopInterception()
        } else {
            startInterception()
        }
    }

    // MARK: - Device Updates

    private func updateCurrentDevice() {
        audioManager.refreshCurrentDevice()
        currentDevice = audioManager.currentDevice
    }

    // MARK: - Manual Volume Control (for UI)

    func setVolume(_ volume: Float) {
        guard let device = currentDevice else { return }
        _ = audioManager.setVolume(deviceID: device.id, volume: volume)
        updateCurrentDevice()
    }

    func setMute(_ muted: Bool) {
        guard let device = currentDevice else { return }
        _ = audioManager.setMuteState(deviceID: device.id, muted: muted)
        updateCurrentDevice()
    }
}
