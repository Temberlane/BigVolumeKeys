//
//  UserSettings.swift
//  BigVolumeKeys
//
//  Manages persistent user settings using UserDefaults
//

import Foundation

class UserSettings {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard

    // Keys for UserDefaults
    private enum Keys {
        static let lastVolume = "lastVolume"
    }

    // MARK: - Volume

    var lastVolume: Float {
        get {
            let value = defaults.float(forKey: Keys.lastVolume)
            // If no value was saved yet, return 0.5 as default
            return value == 0 && !defaults.bool(forKey: "\(Keys.lastVolume)_hasBeenSet") ? 0.5 : value
        }
        set {
            defaults.set(newValue, forKey: Keys.lastVolume)
            defaults.set(true, forKey: "\(Keys.lastVolume)_hasBeenSet")
            print("💾 Saved volume: \(newValue) (\(Int(newValue * 100))%)")
        }
    }

}
