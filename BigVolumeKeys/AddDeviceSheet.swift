//
//  AddDeviceSheet.swift
//  BigVolumeKeys
//
//  Sheet for manually adding audio devices to control
//

import SwiftUI
import CoreAudio

struct AddDeviceSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Device")
                .font(.headline)

            let availableDevices = appState.getAvailableDevicesForManualAdd()

            if availableDevices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No additional devices available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(availableDevices) { device in
                            Button {
                                addDevice(device)
                            } label: {
                                HStack {
                                    Image(systemName: "speaker.wave.2")
                                        .foregroundColor(.blue)
                                    Text(device.name)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 300)
    }

    private func addDevice(_ device: AudioDevice) {
        let subDevice = SubDevice(
            id: device.id,
            name: device.name,
            volume: device.volume,
            isMuted: device.isMuted,
            isManuallyAdded: true
        )
        appState.addManualDevice(subDevice)
        isPresented = false
    }
}
