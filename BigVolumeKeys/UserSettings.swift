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
        static let isInterceptorEnabled = "isInterceptorEnabled"
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

    // MARK: - Interceptor State

    var isInterceptorEnabled: Bool {
        get {
            // Default to true if not set yet
            defaults.object(forKey: Keys.isInterceptorEnabled) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: Keys.isInterceptorEnabled)
            print("💾 Saved interceptor state: \(newValue)")
        }
    }
}
