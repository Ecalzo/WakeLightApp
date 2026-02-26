import AppIntents
import Foundation

// MARK: - Toggle Light Intent

struct ToggleLightIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Wake Light"
    static var description = IntentDescription("Turns the wake light on or off")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        let newState = try await api.toggleLight()
        let message = newState ? "Wake light turned on" : "Wake light turned off"

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Turn On Light Intent

struct TurnOnLightIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn On Wake Light"
    static var description = IntentDescription("Turns the wake light on")

    @Parameter(title: "Brightness", default: 15)
    var brightness: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Turn on wake light at \(\.$brightness) brightness")
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        let clampedBrightness = max(1, min(25, brightness))
        try await api.turnOnLight(brightness: clampedBrightness)

        return .result(dialog: "Wake light turned on at brightness \(clampedBrightness)")
    }
}

// MARK: - Turn Off Light Intent

struct TurnOffLightIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn Off Wake Light"
    static var description = IntentDescription("Turns the wake light off")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        try await api.turnOffLight()

        return .result(dialog: "Wake light turned off")
    }
}

// MARK: - Set Brightness Intent

struct SetBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Wake Light Brightness"
    static var description = IntentDescription("Sets the wake light to a specific brightness level")

    @Parameter(title: "Brightness", default: 15)
    var brightness: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set wake light brightness to \(\.$brightness)")
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        let clampedBrightness = max(1, min(25, brightness))
        try await api.setLight(on: true, brightness: clampedBrightness)

        return .result(dialog: "Wake light set to brightness \(clampedBrightness)")
    }
}

// MARK: - Get Light Status Intent

struct GetLightStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Wake Light Status"
    static var description = IntentDescription("Gets the current status of the wake light")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        let state = try await api.getLightState()

        let status: String
        if state.isOn {
            status = "Wake light is on at brightness \(state.brightness)"
        } else {
            status = "Wake light is off"
        }

        return .result(dialog: IntentDialog(stringLiteral: status))
    }
}

// MARK: - Get Sensors Intent

struct GetSensorsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Bedroom Environment"
    static var description = IntentDescription("Gets the current temperature, humidity, light, and sound levels from the wake light")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        let sensors = try await api.getSensorData()

        let message = "Temperature is \(sensors.temperatureString), humidity is \(sensors.humidity)%, light level is \(sensors.lightLevel) lux, and sound level is \(sensors.soundLevel) decibels"

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Get Temperature Intent

struct GetTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Bedroom Temperature"
    static var description = IntentDescription("Gets the current bedroom temperature from the wake light")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        let sensors = try await api.getSensorData()

        return .result(dialog: "The bedroom temperature is \(sensors.temperatureString)")
    }
}

// MARK: - Get Next Alarm Intent

struct GetNextAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Next Alarm"
    static var description = IntentDescription("Gets the next scheduled alarm from the wake light")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = WakeLightAPI.shared
        await configureAPIIfNeeded()

        let alarms = try await api.getAlarms()
        let enabledAlarms = alarms.filter { $0.isEnabled }

        if enabledAlarms.isEmpty {
            return .result(dialog: "No alarms are currently enabled")
        }

        // Find next alarm (simple: just get the earliest enabled one)
        if let nextAlarm = enabledAlarms.min(by: { a1, a2 in
            (a1.hour * 60 + a1.minute) < (a2.hour * 60 + a2.minute)
        }) {
            return .result(dialog: "Your next alarm is set for \(nextAlarm.time12Hour)")
        }

        return .result(dialog: "No alarms are currently enabled")
    }
}

// MARK: - Helper

private func configureAPIIfNeeded() async {
    // Load device from UserDefaults (App Groups)
    let defaults = UserDefaults(suiteName: AppState.appGroupID) ?? UserDefaults.standard
    if let ip = defaults.string(forKey: "wakelightDeviceIP") {
        await WakeLightAPI.shared.configure(with: ip)
    }
}

// MARK: - App Shortcuts Provider

struct WakeLightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleLightIntent(),
            phrases: [
                "Toggle wake light with \(.applicationName)",
                "Toggle \(.applicationName) light",
                "Toggle light using \(.applicationName)"
            ],
            shortTitle: "Toggle Light",
            systemImageName: "lightbulb"
        )

        AppShortcut(
            intent: TurnOnLightIntent(),
            phrases: [
                "Turn on wake light with \(.applicationName)",
                "Turn on \(.applicationName) light",
                "Turn on light using \(.applicationName)"
            ],
            shortTitle: "Light On",
            systemImageName: "sun.max"
        )

        AppShortcut(
            intent: TurnOffLightIntent(),
            phrases: [
                "Turn off wake light with \(.applicationName)",
                "Turn off \(.applicationName) light",
                "Turn off light using \(.applicationName)"
            ],
            shortTitle: "Light Off",
            systemImageName: "moon"
        )

        AppShortcut(
            intent: GetTemperatureIntent(),
            phrases: [
                "Get bedroom temperature with \(.applicationName)",
                "Check temperature with \(.applicationName)",
                "Check \(.applicationName) temperature"
            ],
            shortTitle: "Temperature",
            systemImageName: "thermometer"
        )

        AppShortcut(
            intent: GetNextAlarmIntent(),
            phrases: [
                "Get next alarm with \(.applicationName)",
                "When is my next \(.applicationName) alarm",
                "Check alarm with \(.applicationName)"
            ],
            shortTitle: "Next Alarm",
            systemImageName: "alarm"
        )
    }
}
