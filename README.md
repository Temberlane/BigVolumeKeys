# BigVolumeKeys

A macOS menu bar app that replaces the default volume key behavior with enhanced volume control, built as a lightweight wrapper around CoreAudio.

## What it does

BigVolumeKeys intercepts the system volume up/down/mute keys and routes them through CoreAudio directly, giving you finer-grained control over your output devices. It's especially useful for **multi-output (aggregate) audio devices**, where macOS's built-in volume keys often don't work at all.

Key features:

- **Logarithmic key ramping** -- tap for small increments, hold for accelerating volume changes
- **Multi-output device support** -- control all sub-devices of an aggregate device simultaneously, with a master slider that preserves relative balance between outputs
- **Per-device sliders** -- adjust individual sub-device volumes independently
- **Manual device addition** -- add output devices that aren't auto-detected as sub-devices

## How it works

The app sits in your menu bar and uses a CoreGraphics event tap to intercept volume key events before macOS handles them. It then translates those key presses into CoreAudio API calls (`AudioObjectSetPropertyData` with `kAudioDevicePropertyVolumeScalar`) to set volume directly on the output device or its sub-devices.

For aggregate/multi-output devices, it queries `kAudioAggregateDevicePropertyFullSubDeviceList` to discover sub-devices and controls each one individually -- something macOS doesn't do natively with the volume keys.

## Permissions

The app requires two macOS permissions to function:

- **Accessibility** -- to create an event tap that intercepts volume key presses
- **Input Monitoring** -- required by macOS for event tap creation

The app will prompt you to grant these on first launch, and auto-starts interception once both are granted.

## Tech

- Swift / SwiftUI
- CoreAudio for device enumeration and volume/mute control
- CoreGraphics event taps for key interception
