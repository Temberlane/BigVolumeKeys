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
            masterSlider

            Divider()
                .opacity(0.5)

            subDeviceSliders

            addDeviceButton
        }
        .onAppear {
            appState.initializeSubDeviceSliders()
        }
    }

    private var masterSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Master")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(appState.sliderValue * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    appState.setMute(!device.isMuted)
                } label: {
                    Image(systemName: device.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .foregroundStyle(device.isMuted ? .primary : .secondary)
                }
                .buttonStyle(.plain)

                Slider(
                    value: $appState.sliderValue,
                    in: 0...1,
                    onEditingChanged: { editing in
                        if editing {
                            isDraggingMaster = true
                            appState.onMasterDragStart()
                        } else {
                            isDraggingMaster = false
                            appState.onMasterDragEnd()
                        }
                    }
                )
                .onChange(of: appState.sliderValue) { _, newValue in
                    if isDraggingMaster {
                        appState.applyMasterDelta(newValue)
                    }
                }

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

    private var subDeviceSliders: some View {
        VStack(alignment: .leading, spacing: 8) {
            let allSubDevices = appState.getAllSubDevices()

            if allSubDevices.isEmpty {
                Text("No sub-devices detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingAddDevice, arrowEdge: .bottom) {
            AddDeviceSheet(isPresented: $showingAddDevice)
                .environmentObject(appState)
        }
    }
}
