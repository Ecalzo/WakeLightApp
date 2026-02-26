# WakeLight

An iOS app for controlling Philips Somneo Wake-Up Light devices on your local network.

## Features

- **Light Control** - Turn the wake-up light on/off and adjust brightness (1-25)
- **Alarm Management** - View and toggle your wake-up alarms
- **Sensor Monitoring** - View real-time temperature, humidity, light level, and sound readings
- **Sunset Mode** - Start relaxing sunset simulations with optional sounds
- **Widgets** - Home screen and lock screen widgets for quick access
- **Siri Shortcuts** - Voice control for common actions

## Requirements

- iOS 17.0+
- Philips Somneo Wake-Up Light (HF367x series) on the same local network
- Xcode 15+ for building

## Building

Build for a physical iOS device (simulator not supported due to local network requirements):

```bash
xcodebuild -scheme WakeLight -destination 'platform=iOS,id=YOUR_DEVICE_ID' build -allowProvisioningUpdates
```

## Setup

1. Ensure your Somneo device is connected to your local WiFi network
2. Launch WakeLight and tap "Re-discover Device" to find your device automatically
3. Alternatively, enter the device's IP address manually in Settings

## Widgets

WakeLight includes three widget types:
- **Light Control** - Shows light status, tap to open app
- **Next Alarm** - Displays your next scheduled alarm
- **Sensors** - Shows current temperature and humidity

## Siri Shortcuts

Available voice commands:
- "Toggle wake light"
- "Turn on/off wake light"
- "Get bedroom temperature"
- "Get next alarm"

## Privacy

WakeLight communicates directly with your Somneo device on your local network. No data is sent to external servers.

## License

MIT
