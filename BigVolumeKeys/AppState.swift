//
//  AppState.swift
//  BigVolumeKeys
//
//  Coordinates all managers and exposes observable state to SwiftUI
//

import Foundation
import SwiftUI
import Combine
import CoreAudio

@MainActor
class AppState: ObservableObject {
    // Published state
    @Published var currentDevice: AudioDevice?
    @Published var isInterceptorActive = false
    @Published var hasPermissions = false
    @Published var sliderValue: Double

    // Multi-output sub-device state
    @Published var subDeviceSliderValues: [AudioDeviceID: Double] = [:]
    @Published var manuallyAddedDevices: [SubDevice] = []

    // Track which devices can have their volume set (cached on initialization)
    private var settableDevices: Set<AudioDeviceID> = []

    // For relative drag tracking
    private var masterDragStartValue: Double = 0
    private var subDeviceValuesAtDragStart: [AudioDeviceID: Double] = [:]

    // Managers
    let audioManager: AudioDeviceManager
    private let volumeController: VolumeController
    private var volumeKeyInterceptor: VolumeKeyInterceptor?
    private let permissionsManager: PermissionsManager
    private let userSettings = UserSettings.shared

    init() {
        // Initialize slider from saved volume
        self.sliderValue = Double(UserSettings.shared.lastVolume)

        self.audioManager = AudioDeviceManager()
        self.volumeController = VolumeController(audioManager: audioManager)
        self.permissionsManager = PermissionsManager.shared

        // Setup observers
        setupObservers()

        // Start observing permissions with a timer as backup
        startPermissionObserver()

        // Check initial permissions and restore saved state
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
            onVolumeUp: { [weak self] (step: Float) in
                Task { @MainActor in
                    guard let self = self else { return }
                    let newVolume = self.volumeController.increaseVolume(currentVolume: Float(self.sliderValue), step: step)
                    self.sliderValue = Double(newVolume)
                    self.updateCurrentDevice()
                    self.syncSubDeviceSliderValues()
                    self.showVolumeHUD()
                }
            },
            onVolumeDown: { [weak self] (step: Float) in
                Task { @MainActor in
                    guard let self = self else { return }
                    let newVolume = self.volumeController.decreaseVolume(currentVolume: Float(self.sliderValue), step: step)
                    self.sliderValue = Double(newVolume)
                    self.updateCurrentDevice()
                    self.syncSubDeviceSliderValues()
                    self.showVolumeHUD()
                }
            },
            onMute: { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.volumeController.toggleMute()
                    self.updateCurrentDevice()
                    self.syncSubDeviceSliderValues()
                    self.showVolumeHUD()
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

    // MARK: - Device Updates

    private func updateCurrentDevice() {
        audioManager.refreshCurrentDevice()
        currentDevice = audioManager.currentDevice
    }

    /// Sync sub-device slider values from actual CoreAudio state
    /// Call after volume key presses to keep individual sliders in sync
    private func syncSubDeviceSliderValues() {
        guard let device = currentDevice else { return }

        for subDevice in device.subDevices {
            let realVolume = audioManager.getVolume(deviceID: subDevice.id) ?? subDevice.volume
            subDeviceSliderValues[subDevice.id] = Double(realVolume)
        }

        for manualDevice in manuallyAddedDevices {
            let realVolume = audioManager.getVolume(deviceID: manualDevice.id) ?? manualDevice.volume
            subDeviceSliderValues[manualDevice.id] = Double(realVolume)
        }
    }

    // MARK: - Manual Volume Control (for UI)

    func setVolume(_ volume: Float) {
        guard let device = currentDevice else { return }
        _ = audioManager.setVolume(deviceID: device.id, volume: volume)
        sliderValue = Double(volume)
        userSettings.lastVolume = volume
        updateCurrentDevice()
    }

    func setMute(_ muted: Bool) {
        guard let device = currentDevice else { return }
        _ = audioManager.setMuteState(deviceID: device.id, muted: muted)
        updateCurrentDevice()
    }

    // MARK: - Volume HUD

    private func showVolumeHUD() {
        let deviceName = currentDevice?.name ?? "Unknown Device"
        let isMuted = currentDevice?.isMuted ?? false
        VolumeHUDPanel.shared.show(volume: sliderValue, deviceName: deviceName, isMuted: isMuted)
    }

    // MARK: - Settings

    func getSavedVolume() -> Float {
        return userSettings.lastVolume
    }

    // MARK: - Multi-Output Volume Control

    /// Call when user starts dragging the master slider to capture initial state
    func onMasterDragStart() {
        masterDragStartValue = sliderValue

        // Capture all sub-device volumes at drag start
        subDeviceValuesAtDragStart.removeAll()

        if let device = currentDevice {
            for subDevice in device.subDevices {
                let volume = subDeviceSliderValues[subDevice.id] ?? Double(subDevice.volume)
                subDeviceValuesAtDragStart[subDevice.id] = volume
            }

            // Also capture manually added devices
            for manualDevice in manuallyAddedDevices {
                let volume = subDeviceSliderValues[manualDevice.id] ?? Double(manualDevice.volume)
                subDeviceValuesAtDragStart[manualDevice.id] = volume
            }
        }

        print("📊 Master drag started at \(Int(masterDragStartValue * 100))%")
    }

    /// Apply relative delta to all sub-devices based on master slider change
    func applyMasterDelta(_ newMasterValue: Double) {
        let delta = newMasterValue - masterDragStartValue

        guard let device = currentDevice else { return }

        // Apply delta to all sub-devices
        for subDevice in device.subDevices {
            applyDeltaToSubDevice(subDevice.id, delta: delta)
        }

        // Also apply to manually added devices
        for manualDevice in manuallyAddedDevices {
            applyDeltaToSubDevice(manualDevice.id, delta: delta)
        }

        // Update the master slider value
        sliderValue = newMasterValue
    }

    private func applyDeltaToSubDevice(_ deviceID: AudioDeviceID, delta: Double) {
        guard let startVolume = subDeviceValuesAtDragStart[deviceID] else { return }
        guard settableDevices.contains(deviceID) else { return }  // Skip non-settable devices

        let newVolume = max(0.0, min(1.0, startVolume + delta))
        subDeviceSliderValues[deviceID] = newVolume
        _ = audioManager.setVolume(deviceID: deviceID, volume: Float(newVolume))
    }

    /// Call when user finishes dragging the master slider
    func onMasterDragEnd() {
        // Save the final volume
        userSettings.lastVolume = Float(sliderValue)
        updateCurrentDevice()
        print("📊 Master drag ended at \(Int(sliderValue * 100))%")
    }

    /// Set volume for an individual sub-device
    func setSubDeviceVolume(_ id: AudioDeviceID, volume: Float) {
        guard settableDevices.contains(id) else { return }  // Skip non-settable devices
        subDeviceSliderValues[id] = Double(volume)
        _ = audioManager.setVolume(deviceID: id, volume: volume)
        updateCurrentDevice()
    }

    /// Add a device manually (when auto-detection fails)
    func addManualDevice(_ device: SubDevice) {
        guard !manuallyAddedDevices.contains(where: { $0.id == device.id }) else { return }

        var newDevice = device
        newDevice.isManuallyAdded = true
        // Check if volume can be set for this device
        newDevice.canSetVolume = audioManager.canSetVolume(deviceID: device.id)
        manuallyAddedDevices.append(newDevice)

        // Initialize its slider value
        let volume = audioManager.getVolume(deviceID: device.id) ?? 0.5
        subDeviceSliderValues[device.id] = Double(volume)

        // Update settable devices cache
        if newDevice.canSetVolume {
            settableDevices.insert(device.id)
        }

        print("➕ Manually added device: \(device.name) (canSetVolume: \(newDevice.canSetVolume))")
    }

    /// Remove a manually added device
    func removeManualDevice(_ id: AudioDeviceID) {
        manuallyAddedDevices.removeAll { $0.id == id }
        subDeviceSliderValues.removeValue(forKey: id)
        subDeviceValuesAtDragStart.removeValue(forKey: id)
        settableDevices.remove(id)

        print("➖ Removed manual device: \(id)")
    }

    /// Initialize sub-device slider values from current device state
    func initializeSubDeviceSliders() {
        guard let device = currentDevice else { return }

        // Clear and rebuild the settable devices cache
        settableDevices.removeAll()

        for subDevice in device.subDevices {
            if subDeviceSliderValues[subDevice.id] == nil {
                subDeviceSliderValues[subDevice.id] = Double(subDevice.volume)
            }
            // Cache whether this device can have its volume set
            if subDevice.canSetVolume {
                settableDevices.insert(subDevice.id)
            }
        }

        // Also cache manually added devices
        for manualDevice in manuallyAddedDevices {
            if manualDevice.canSetVolume {
                settableDevices.insert(manualDevice.id)
            }
        }

        print("📊 Initialized \(settableDevices.count) settable devices out of \(device.subDevices.count + manuallyAddedDevices.count) total")
    }

    /// Get all sub-devices (both auto-detected and manually added)
    func getAllSubDevices() -> [SubDevice] {
        var devices: [SubDevice] = []

        if let device = currentDevice {
            devices.append(contentsOf: device.subDevices)
        }

        devices.append(contentsOf: manuallyAddedDevices)

        return devices
    }

    /// Get available devices that can be manually added (output devices not already in sub-devices)
    func getAvailableDevicesForManualAdd() -> [AudioDevice] {
        let allDevices = audioManager.getAllOutputDevices()
        let currentSubDeviceIDs = Set(getAllSubDevices().map { $0.id })

        // Filter out the current device and its sub-devices
        return allDevices.filter { device in
            device.id != currentDevice?.id && !currentSubDeviceIDs.contains(device.id)
        }
    }
}
