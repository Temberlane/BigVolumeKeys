//
//  AudioDevice.swift
//  BigVolumeKeys
//
//  Model representing an audio device
//

import Foundation
import CoreAudio

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    var volume: Float  // 0.0 to 1.0
    var isMuted: Bool
    var isMultiOutput: Bool
    var subDevices: [SubDevice] = []

    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id
    }

    var volumePercentage: Int {
        Int(volume * 100)
    }
}
