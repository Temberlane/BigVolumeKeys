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
    @State private var sliderValue: Double = 0.5
    @State private var isDraggingSlider = false

    var body: some View {
        VStack(spacing: 20) {
            // Dynamic volume icon
            Image(systemName: volumeIcon)
                .font(.system(size: 60))
                .foregroundColor(.blue)

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

                    // Volume slider
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
                                value: $sliderValue,
                                in: 0...1,
                                onEditingChanged: { editing in
                                    isDraggingSlider = editing
                                    if !editing {
                                        // User finished dragging, update the device
                                        let newVolume = Float(sliderValue)
                                        print("Slider drag ended - Setting volume to: \(newVolume) (\(Int(newVolume * 100))%)")
                                        appState.setVolume(newVolume)
                                    } else {
                                        print("Slider drag started - Current value: \(sliderValue) (\(Int(sliderValue * 100))%)")
                                    }
                                }
                            )
                            .tint(device.isMuted ? .red : .blue)
                            .onChange(of: sliderValue) { oldValue, newValue in
                                if isDraggingSlider {
                                    print("Slider value changing: \(newValue) (\(Int(newValue * 100))%)")
                                }
                            }

                            // Max volume button
                            Button {
                                sliderValue = 1.0
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
                    .onAppear {
                        // Initialize slider value from device
                        sliderValue = Double(device.volume)
                    }
                    .onChange(of: device.volume) { oldValue, newValue in
                        // Update slider when device volume changes (from keyboard, etc.)
                        if !isDraggingSlider {
                            sliderValue = Double(newValue)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Text("No audio device detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Volume control toggle
            VStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { appState.isInterceptorActive },
                    set: { _ in appState.toggleInterception() }
                )) {
                    Text("Volume Key Control")
                        .font(.headline)
                }
                .toggleStyle(.switch)
                .disabled(!appState.hasPermissions)

                Text(appState.isInterceptorActive ? "Active" : "Inactive")
                    .font(.caption2)
                    .foregroundColor(appState.isInterceptorActive ? .green : .secondary)
            }
            .padding(.horizontal)

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
        // Show slider value while dragging, otherwise show device volume
        if isDraggingSlider {
            return Int(sliderValue * 100)
        } else if let device = appState.currentDevice {
            return device.volumePercentage
        } else {
            return 0
        }
    }

    private var volumeIcon: String {
        guard let device = appState.currentDevice else {
            return "speaker.slash"
        }

        if device.isMuted {
            return "speaker.slash.fill"
        }

        if device.volume == 0 {
            return "speaker.fill"
        } else if device.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if device.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
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
