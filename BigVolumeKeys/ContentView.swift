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
        VStack(spacing: 12) {
            // Permissions warning (only shown when not granted)
            if !permissionsManager.hasAccessibilityPermission || !permissionsManager.hasInputMonitoringPermission {
                permissionsWarning
            }

            // Current device info
            if let device = appState.currentDevice {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(device.name)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if device.isMultiOutput {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if device.isMultiOutput || !appState.manuallyAddedDevices.isEmpty {
                        MultiOutputVolumeView(device: device)
                            .environmentObject(appState)
                    } else {
                        singleDeviceVolumeSlider(device: device)
                    }
                }
                .onAppear {
                    let savedVolume = appState.getSavedVolume()
                    appState.setVolume(savedVolume)
                    print("📱 Initialized device from saved volume: \(savedVolume) (\(Int(savedVolume * 100))%)")
                }
            } else {
                HStack {
                    Image(systemName: "speaker.slash")
                        .foregroundStyle(.secondary)
                    Text("No audio device detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Divider()
                .opacity(0.5)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(minWidth: 300, maxWidth: 320)
        .onAppear {
            permissionsManager.ensurePollingActive()
            appState.checkPermissions()
        }
    }

    private var permissionsWarning: some View {
        VStack(spacing: 8) {
            Text("Accessibility access is required to intercept volume keys.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                permissionsManager.openSystemPreferences()
            } label: {
                Text("Open Settings")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.bottom, 4)
    }

    private var currentVolumePercentage: Int {
        return Int(appState.sliderValue * 100)
    }

    @ViewBuilder
    private func singleDeviceVolumeSlider(device: AudioDevice) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    appState.setMute(!device.isMuted)
                    print("Mute toggled: \(!device.isMuted)")
                } label: {
                    Image(systemName: device.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .foregroundStyle(device.isMuted ? .primary : .secondary)
                }
                .buttonStyle(.plain)

                Slider(
                    value: $appState.sliderValue,
                    in: 0...1,
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            let newVolume = Float(appState.sliderValue)
                            print("Slider drag ended - Setting volume to: \(newVolume) (\(Int(newVolume * 100))%)")
                            appState.setVolume(newVolume)
                        } else {
                            print("Slider drag started - Current value: \(appState.sliderValue) (\(Int(appState.sliderValue * 100))%)")
                        }
                    }
                )
                .onChange(of: appState.sliderValue) { _, newValue in
                    if isDraggingSlider {
                        appState.setVolume(Float(newValue))
                    }
                }

                Button {
                    appState.setVolume(1.0)
                    if device.isMuted {
                        appState.setMute(false)
                    }
                    print("Max volume button pressed - Volume set to: 1.0 (100%)")
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if device.isMuted {
                Text("Muted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

}

#Preview {
    ContentView()
        .environment(PermissionsManager.shared)
        .environmentObject(AppState())
}
