//
//  SubDeviceSlider.swift
//  BigVolumeKeys
//
//  Individual slider component for controlling a sub-device's volume
//

import SwiftUI
import CoreAudio

struct SubDeviceSlider: View {
    let subDevice: SubDevice
    @Binding var volume: Double
    let onVolumeChange: (Float) -> Void
    let onRemove: (() -> Void)?

    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(subDevice.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(subDevice.canSetVolume ? .primary : .secondary)

                if !subDevice.canSetVolume {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .help("Volume cannot be controlled for this device")
                }

                Spacer()

                Text("\(Int(volume * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                if subDevice.isManuallyAdded, let onRemove = onRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove device")
                }
            }

            Slider(
                value: $volume,
                in: 0...1,
                onEditingChanged: { editing in
                    isDragging = editing
                }
            )
            .onChange(of: volume) { _, newValue in
                if isDragging && subDevice.canSetVolume {
                    onVolumeChange(Float(newValue))
                }
            }
            .tint(subDevice.canSetVolume ? .blue : .gray)
            .disabled(!subDevice.canSetVolume)
        }
        .padding(.vertical, 4)
        .opacity(subDevice.canSetVolume ? 1.0 : 0.6)
    }
}
