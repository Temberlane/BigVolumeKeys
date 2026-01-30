//
//  ContentView.swift
//  BigVolumeKeys
//
//  Created by Thomas Li on 2026-01-30.
//

import SwiftUI

struct ContentView: View {
    @Environment(PermissionsManager.self) var permissionsManager: PermissionsManager
    @EnvironmentObject var appState: AppState
    @State private var isDraggingSlider = false

    var body: some View {
        VStack(spacing: 20) {
            // Current device info
            if let device = appState.currentDevice {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Device:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if device.isMultiOutput {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    // Conditionally render multi-output or single-device slider
                    if device.isMultiOutput || !appState.manuallyAddedDevices.isEmpty {
                        MultiOutputVolumeView(device: device)
                            .environmentObject(appState)
                    } else {
                        // Single device volume slider
                        singleDeviceVolumeSlider(device: device)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    // Set the device volume to match the saved slider value on first appearance
                    let savedVolume = appState.getSavedVolume()
                    appState.setVolume(savedVolume)
                    print("📱 Initialized device from saved volume: \(savedVolume) (\(Int(savedVolume * 100))%)")
                }
            } else {
                Text("No audio device detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Permissions section
            VStack(alignment: .leading, spacing: 10) {
                PermissionRow(
                    title: "Accessibility",
                    granted: permissionsManager.hasAccessibilityPermission
                )

                PermissionRow(
                    title: "Input Monitoring",
                    granted: permissionsManager.hasInputMonitoringPermission
                )
            }
            .padding(.horizontal)

            if !permissionsManager.hasAccessibilityPermission || !permissionsManager.hasInputMonitoringPermission {
                Button("Request Permissions") {
                    permissionsManager.requestPermissions()
                }
                .buttonStyle(.borderedProminent)

                Button("Open System Preferences") {
                    permissionsManager.openSystemPreferences()
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(40)
        .frame(minWidth: 350)
        .onAppear {
            permissionsManager.ensurePollingActive()
            appState.checkPermissions()
        }
    }

    private var currentVolumePercentage: Int {
        return Int(appState.sliderValue * 100)
    }

    @ViewBuilder
    private func singleDeviceVolumeSlider(device: AudioDevice) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("Volume:")
                    .font(.caption)
                Spacer()
                Text("\(currentVolumePercentage)%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(device.isMuted ? .red : .primary)
            }

            HStack(spacing: 8) {
                // Mute button
                Button {
                    appState.setMute(!device.isMuted)
                    print("Mute toggled: \(!device.isMuted)")
                } label: {
                    Image(systemName: device.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .foregroundColor(device.isMuted ? .red : .secondary)
                }
                .buttonStyle(.plain)

                // Interactive volume slider
                Slider(
                    value: $appState.sliderValue,
                    in: 0...1,
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            // User finished dragging, update the device
                            let newVolume = Float(appState.sliderValue)
                            print("Slider drag ended - Setting volume to: \(newVolume) (\(Int(newVolume * 100))%)")
                            appState.setVolume(newVolume)
                        } else {
                            print("Slider drag started - Current value: \(appState.sliderValue) (\(Int(appState.sliderValue * 100))%)")
                        }
                    }
                )
                .tint(device.isMuted ? .red : .blue)
                .onChange(of: appState.sliderValue) { _, newValue in
                    if isDraggingSlider {
                        appState.setVolume(Float(newValue))
                    }
                }

                // Max volume button
                Button {
                    appState.setVolume(1.0)
                    if device.isMuted {
                        appState.setMute(false)
                    }
                    print("Max volume button pressed - Volume set to: 1.0 (100%)")
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if device.isMuted {
                Text("Muted")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

}

struct PermissionRow: View {
    let title: String
    let granted: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
        }
    }
}

#Preview {
    ContentView()
        .environment(PermissionsManager.shared)
        .environmentObject(AppState())
}
