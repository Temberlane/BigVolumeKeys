//
//  MultiOutputVolumeView.swift
//  BigVolumeKeys
//
//  Main container view for multi-output audio device volume control
//  Shows master slider and individual sub-device sliders
//

import SwiftUI
import CoreAudio

struct MultiOutputVolumeView: View {
    let device: AudioDevice
    @EnvironmentObject var appState: AppState
    @State private var isDraggingMaster = false
    @State private var showingAddDevice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Master volume slider
            masterSlider

            Divider()

            // Sub-device sliders
            subDeviceSliders

            // Add device button
            addDeviceButton
        }
        .onAppear {
            appState.initializeSubDeviceSliders()
        }
    }

    private var masterSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.orange)
                Text("Master (\(device.name))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text("\(Int(appState.sliderValue * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(device.isMuted ? .red : .primary)
            }

            HStack(spacing: 8) {
                // Mute button
                Button {
                    appState.setMute(!device.isMuted)
                } label: {
                    Image(systemName: device.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .foregroundColor(device.isMuted ? .red : .secondary)
                }
                .buttonStyle(.plain)

                // Master slider with relative control
                Slider(
                    value: $appState.sliderValue,
                    in: 0...1,
                    onEditingChanged: { editing in
                        if editing {
                            // Drag started - capture initial state
                            isDraggingMaster = true
                            appState.onMasterDragStart()
                        } else {
                            // Drag ended - finalize
                            isDraggingMaster = false
                            appState.onMasterDragEnd()
                        }
                    }
                )
                .tint(device.isMuted ? .red : .orange)
                .onChange(of: appState.sliderValue) { _, newValue in
                    if isDraggingMaster {
                        // Apply relative delta while dragging
                        appState.applyMasterDelta(newValue)
                    }
                }

                // Max volume button
                Button {
                    appState.onMasterDragStart()
                    appState.applyMasterDelta(1.0)
                    appState.sliderValue = 1.0
                    appState.onMasterDragEnd()
                    if device.isMuted {
                        appState.setMute(false)
                    }
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

    private var subDeviceSliders: some View {
        VStack(alignment: .leading, spacing: 8) {
            let allSubDevices = appState.getAllSubDevices()

            if allSubDevices.isEmpty {
                Text("No sub-devices detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(allSubDevices) { subDevice in
                    SubDeviceSlider(
                        subDevice: subDevice,
                        volume: Binding(
                            get: {
                                appState.subDeviceSliderValues[subDevice.id] ?? Double(subDevice.volume)
                            },
                            set: { newValue in
                                appState.subDeviceSliderValues[subDevice.id] = newValue
                            }
                        ),
                        onVolumeChange: { volume in
                            appState.setSubDeviceVolume(subDevice.id, volume: volume)
                        },
                        onRemove: subDevice.isManuallyAdded ? {
                            appState.removeManualDevice(subDevice.id)
                        } : nil
                    )
                }
            }
        }
    }

    private var addDeviceButton: some View {
        Button {
            showingAddDevice = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                Text("Add Device")
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingAddDevice, arrowEdge: .bottom) {
            AddDeviceSheet(isPresented: $showingAddDevice)
                .environmentObject(appState)
        }
    }
}
