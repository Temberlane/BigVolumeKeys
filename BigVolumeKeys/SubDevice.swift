//
//  SubDevice.swift
//  BigVolumeKeys
//
//  Model representing a sub-device within a multi-output audio device
//

import Foundation
import CoreAudio

struct SubDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    var volume: Float  // 0.0 to 1.0
    var isMuted: Bool
    var isManuallyAdded: Bool
    var canSetVolume: Bool  // Whether this device supports volume control

    init(id: AudioDeviceID, name: String, volume: Float = 0.5, isMuted: Bool = false, isManuallyAdded: Bool = false, canSetVolume: Bool = true) {
        self.id = id
        self.name = name
        self.volume = volume
        self.isMuted = isMuted
        self.isManuallyAdded = isManuallyAdded
        self.canSetVolume = canSetVolume
    }

    static func == (lhs: SubDevice, rhs: SubDevice) -> Bool {
        lhs.id == rhs.id
    }

    var volumePercentage: Int {
        Int(volume * 100)
    }
}
