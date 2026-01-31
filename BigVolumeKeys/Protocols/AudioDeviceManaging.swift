//
//  AudioDeviceManaging.swift
//  BigVolumeKeys
//
//  Protocol for audio device management to enable testing
//

import Foundation
import CoreAudio

protocol AudioDeviceManaging: AnyObject {
    var currentDevice: AudioDevice? { get }

    func refreshCurrentDevice()
    func getAllOutputDevices() -> [AudioDevice]
    func getVolume(deviceID: AudioDeviceID) -> Float?
    func setVolume(deviceID: AudioDeviceID, volume: Float) -> Bool
    func getMuteState(deviceID: AudioDeviceID) -> Bool?
    func setMuteState(deviceID: AudioDeviceID, muted: Bool) -> Bool
    func getSubDevices(deviceID: AudioDeviceID) -> [AudioDeviceID]?
}

extension AudioDeviceManager: AudioDeviceManaging {}
