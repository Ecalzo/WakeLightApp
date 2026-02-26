import Foundation
import SwiftUI

/// Shared application state with persistence via App Groups
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // App Group identifier for sharing with widgets
    static let appGroupID = "group.com.wakelight"

    private let defaults: UserDefaults

    // MARK: - Published State

    @Published var device: WakeLightDevice?
    @Published var lightState: LightState = .off
    @Published var sensorData: SensorData = .empty
    @Published var alarms: [Alarm] = []
    @Published var sunsetState: SunsetState = .off
    @Published var discoveryState: DiscoveryState = .idle
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var isRefreshing = false

    // Toast state
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var toastIcon = "checkmark.circle.fill"

    // Settings
    @Published var useFahrenheit = false

    // MARK: - Initialization

    init() {
        // Use App Group UserDefaults for widget sharing, fall back to standard if not available
        if let groupDefaults = UserDefaults(suiteName: Self.appGroupID) {
            self.defaults = groupDefaults
        } else {
            self.defaults = UserDefaults.standard
        }

        loadPersistedState()
    }

    // MARK: - Persistence Keys

    private enum Keys {
        static let deviceIP = "wakelightDeviceIP"
        static let deviceName = "wakelightDeviceName"
        static let deviceModel = "wakelightDeviceModel"
        static let lightOn = "wakelightLightOn"
        static let lightBrightness = "wakelightLightBrightness"
        static let useFahrenheit = "wakelightUseFahrenheit"
    }

    // MARK: - Load/Save State

    private func loadPersistedState() {
        // Load device
        if let ip = defaults.string(forKey: Keys.deviceIP) {
            let name = defaults.string(forKey: Keys.deviceName) ?? "Wake-Up Light"
            let model = defaults.string(forKey: Keys.deviceModel) ?? "HF367x"
            device = WakeLightDevice(ipAddress: ip, name: name, modelNumber: model)
        }

        // Load settings
        useFahrenheit = defaults.bool(forKey: Keys.useFahrenheit)

        // Load cached light state
        let lightOn = defaults.bool(forKey: Keys.lightOn)
        let brightness = defaults.integer(forKey: Keys.lightBrightness)
        if brightness > 0 {
            lightState = LightState(onoff: lightOn, ltlvl: brightness, tempy: false, ngtlt: false)
        }
    }

    func saveDevice(_ device: WakeLightDevice) {
        self.device = device
        defaults.set(device.ipAddress, forKey: Keys.deviceIP)
        defaults.set(device.name, forKey: Keys.deviceName)
        defaults.set(device.modelNumber, forKey: Keys.deviceModel)
        sendConfigToWatch()
    }

    func clearDevice() {
        device = nil
        isConnected = false
        defaults.removeObject(forKey: Keys.deviceIP)
        defaults.removeObject(forKey: Keys.deviceName)
        defaults.removeObject(forKey: Keys.deviceModel)
    }

    func saveLightState(_ state: LightState) {
        lightState = state
        defaults.set(state.isOn, forKey: Keys.lightOn)
        defaults.set(state.brightness, forKey: Keys.lightBrightness)
    }

    func saveSettings() {
        defaults.set(useFahrenheit, forKey: Keys.useFahrenheit)
        sendConfigToWatch()
    }

    // MARK: - Toast

    func showSuccessToast(_ message: String, icon: String = "checkmark.circle.fill") {
        toastMessage = message
        toastIcon = icon
        showToast = true

        // Auto-dismiss after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                showToast = false
            }
        }
    }

    private func sendConfigToWatch() {
        guard let ip = device?.ipAddress else { return }
        PhoneConnectivityManager.shared.sendDeviceConfig(ip: ip, useFahrenheit: useFahrenheit)
    }

    // MARK: - Device Discovery

    func discoverDevice() async {
        discoveryState = .discovering
        lastError = nil

        if let device = await DeviceDiscovery.shared.discoverDevice() {
            discoveryState = .found(device)
            saveDevice(device)
            await configureAPI()
            await refreshAll()
        } else {
            discoveryState = .notFound
            lastError = "No wake-up light found on the network"
        }
    }

    func setManualIP(_ ip: String) async {
        discoveryState = .discovering

        if let device = await DeviceDiscovery.shared.verifyDevice(ip: ip) {
            discoveryState = .found(device)
            saveDevice(device)
            await configureAPI()
            await refreshAll()
        } else {
            discoveryState = .error("Could not connect to device at \(ip)")
            lastError = "Could not connect to device at \(ip)"
        }
    }

    // MARK: - API Configuration

    func configureAPI() async {
        guard let device = device else { return }
        await WakeLightAPI.shared.configure(with: device)
        isConnected = await WakeLightAPI.shared.testConnection()
        sendConfigToWatch()
    }

    // MARK: - Data Refresh

    func refreshAll() async {
        guard device != nil else { return }
        isRefreshing = true
        lastError = nil

        do {
            async let light = WakeLightAPI.shared.getLightState()
            async let sensors = WakeLightAPI.shared.getSensorData()
            async let alarmList = WakeLightAPI.shared.getAlarms()

            let (lightResult, sensorResult, alarmResult) = try await (light, sensors, alarmList)

            saveLightState(lightResult)
            sensorData = sensorResult
            alarms = alarmResult
            isConnected = true
        } catch {
            lastError = error.localizedDescription
            isConnected = false
        }

        isRefreshing = false
    }

    func refreshLight() async {
        do {
            let state = try await WakeLightAPI.shared.getLightState()
            saveLightState(state)
            isConnected = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshSensors() async {
        do {
            sensorData = try await WakeLightAPI.shared.getSensorData()
            isConnected = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshAlarms() async {
        do {
            alarms = try await WakeLightAPI.shared.getAlarms()
            isConnected = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Light Control

    func toggleLight() async {
        do {
            let newState = try await WakeLightAPI.shared.toggleLight()
            lightState = LightState(onoff: newState, ltlvl: lightState.brightness, tempy: lightState.isWarmWhite, ngtlt: lightState.isNightLightOn)
            saveLightState(lightState)
            isConnected = true
            showSuccessToast(newState ? "Light On" : "Light Off", icon: newState ? "sun.max.fill" : "moon.fill")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setLightBrightness(_ brightness: Int) async {
        do {
            try await WakeLightAPI.shared.setLight(brightness: brightness)
            lightState = LightState(onoff: true, ltlvl: brightness, tempy: lightState.isWarmWhite, ngtlt: lightState.isNightLightOn)
            saveLightState(lightState)
            isConnected = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func turnOnLight(brightness: Int = 15, showFeedback: Bool = true) async {
        do {
            try await WakeLightAPI.shared.turnOnLight(brightness: brightness)
            lightState = LightState(onoff: true, ltlvl: brightness, tempy: lightState.isWarmWhite, ngtlt: lightState.isNightLightOn)
            saveLightState(lightState)
            isConnected = true
            if showFeedback {
                showSuccessToast("Brightness: \(brightness)", icon: "sun.max.fill")
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func turnOffLight() async {
        do {
            try await WakeLightAPI.shared.turnOffLight()
            lightState = LightState(onoff: false, ltlvl: lightState.brightness, tempy: lightState.isWarmWhite, ngtlt: lightState.isNightLightOn)
            saveLightState(lightState)
            isConnected = true
            showSuccessToast("Light Off", icon: "moon.fill")
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Alarm Control

    func setAlarmEnabled(position: Int, enabled: Bool) async {
        // Find the alarm to get its current time/days data
        guard let alarm = alarms.first(where: { $0.position == position }) else {
            lastError = "Alarm not found"
            return
        }

        // Optimistic update - update local state immediately for responsive UI
        if let index = alarms.firstIndex(where: { $0.position == position }) {
            alarms[index] = alarms[index].withEnabled(enabled)
        }

        do {
            try await WakeLightAPI.shared.setAlarmEnabled(
                position: position,
                enabled: enabled,
                hour: alarm.hour,
                minute: alarm.minute,
                days: alarm.dayMask
            )
            isConnected = true
            // No refresh needed - we already updated locally
        } catch {
            // Revert on failure
            if let index = alarms.firstIndex(where: { $0.position == position }) {
                alarms[index] = alarms[index].withEnabled(!enabled)
            }
            lastError = error.localizedDescription
        }
    }

    func configureAlarm(position: Int, hour: Int, minute: Int, days: Int, enabled: Bool) async {
        do {
            try await WakeLightAPI.shared.configureAlarm(position: position, hour: hour, minute: minute, days: days, enabled: enabled)
            await refreshAlarms()
            showSuccessToast("Alarm Saved", icon: "alarm.fill")
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Sunset Control

    func refreshSunset() async {
        do {
            sunsetState = try await WakeLightAPI.shared.getSunsetState()
            isConnected = true
        } catch {
            // Sunset endpoint might not exist on all devices
        }
    }

    func startSunset(duration: Int = 20, colorScheme: SunsetColorScheme? = nil, sound: SunsetSound = .off, volume: Int = 12) async {
        do {
            try await WakeLightAPI.shared.startSunset(
                duration: duration,
                colorType: colorScheme?.rawValue,  // Only sends ctype if explicitly set
                soundChannel: sound.channel,
                volume: sound != .off ? volume : nil
            )
            sunsetState = SunsetState(
                onoff: true,
                curve: nil,
                durat: duration,
                ctype: colorScheme?.rawValue,
                sndtp: sound != .off ? 1 : 0,
                snddv: sound != .off ? "wus" : nil,
                sndch: sound.channel,
                sndlv: sound != .off ? volume : nil,
                sndss: nil
            )
            isConnected = true
            showSuccessToast("Sunset Started", icon: "moon.stars.fill")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopSunset() async {
        do {
            try await WakeLightAPI.shared.stopSunset()
            sunsetState = .off
            isConnected = true
            showSuccessToast("Sunset Stopped", icon: "moon")
        } catch {
            lastError = error.localizedDescription
        }
    }
}
