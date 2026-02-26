import SwiftUI
import WatchConnectivity

@main
struct WakeLightWatchApp: App {
    @StateObject private var watchState = WatchState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchState)
        }
    }
}

/// Watch-specific app state
@MainActor
class WatchState: ObservableObject {
    private let defaults = UserDefaults.standard
    private let api = WakeLightAPI.shared
    private var connectivityManager: WatchConnectivityManager?

    @Published var isConnected = false
    @Published var deviceIP: String?
    @Published var lightState: LightState = LightState(onoff: false, ltlvl: 1, tempy: false, ngtlt: false)
    @Published var sunsetState: SimpleSunsetState = .off
    @Published var sensorData: SensorData = SensorData(mstmp: 0, msrhu: 0, mslux: 0, mssnd: 0)
    @Published var isLoading = false
    @Published var lastError: String?

    // Settings from iOS app
    @Published var useFahrenheit = false

    private enum Keys {
        static let deviceIP = "watchDeviceIP"
        static let useFahrenheit = "watchUseFahrenheit"
    }

    init() {
        loadSettings()
        connectivityManager = WatchConnectivityManager { [weak self] context in
            Task { @MainActor in
                self?.handleReceivedContext(context)
            }
        }
        connectivityManager?.activate()
    }

    private func loadSettings() {
        deviceIP = defaults.string(forKey: Keys.deviceIP)
        useFahrenheit = defaults.bool(forKey: Keys.useFahrenheit)
    }

    private func handleReceivedContext(_ context: [String: Any]) {
        if let ip = context["deviceIP"] as? String {
            deviceIP = ip
            defaults.set(ip, forKey: Keys.deviceIP)
        }
        if let fahrenheit = context["useFahrenheit"] as? Bool {
            useFahrenheit = fahrenheit
            defaults.set(fahrenheit, forKey: Keys.useFahrenheit)
        }

        // Auto-connect when we receive new config
        Task {
            await configure()
        }
    }

    func configure() async {
        if deviceIP == nil {
            // No cached IP — ask the iPhone for it
            await requestConfigFromPhone()
        }

        guard let ip = deviceIP else {
            lastError = "No device IP. Open iOS app to sync."
            isConnected = false
            return
        }

        await api.configure(with: ip)

        // Test the connection with an actual API call
        do {
            lightState = try await api.getLightState()
            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = "Cannot reach \(ip)"
        }
    }

    /// Proactively request device config from the paired iPhone.
    private func requestConfigFromPhone() async {
        guard WCSession.default.isReachable else { return }

        await withCheckedContinuation { continuation in
            WCSession.default.sendMessage(["request": "deviceConfig"], replyHandler: { response in
                Task { @MainActor in
                    self.handleReceivedContext(response)
                    continuation.resume()
                }
            }, errorHandler: { _ in
                continuation.resume()
            })
        }
    }

    // MARK: - Light Control

    func refreshLight() async {
        do {
            lightState = try await api.getLightState()
            isConnected = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isConnected = false
        }
    }

    func toggleLight() async {
        isLoading = true
        do {
            let newState = try await api.toggleLight()
            lightState = LightState(onoff: newState, ltlvl: lightState.ltlvl, tempy: lightState.tempy, ngtlt: lightState.ngtlt)
            isConnected = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    func setLightBrightness(_ brightness: Int) async {
        do {
            try await api.setLight(on: true, brightness: brightness)
            lightState = LightState(onoff: true, ltlvl: brightness, tempy: lightState.tempy, ngtlt: lightState.ngtlt)
            isConnected = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Sunset Control

    func refreshSunset() async {
        do {
            sunsetState = try await api.getSunsetState()
            isConnected = true
            lastError = nil
        } catch {
            // Sunset endpoint might not exist on all devices
        }
    }

    func startSunset(duration: Int, colorScheme: SunsetColorScheme? = nil,
                     sound: SunsetSound = .off, volume: Int = 12) async {
        isLoading = true
        do {
            try await api.startSunset(
                duration: duration,
                colorType: colorScheme?.rawValue,
                soundChannel: sound.channel,
                volume: sound != .off ? volume : nil
            )
            sunsetState = SimpleSunsetState(onoff: true, durat: duration)
            isConnected = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    func stopSunset() async {
        isLoading = true
        do {
            try await api.stopSunset()
            sunsetState = .off
            isConnected = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sensors

    func refreshSensors() async {
        do {
            sensorData = try await api.getSensorData()
            isConnected = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Refresh All

    func refreshAll() async {
        isLoading = true
        await configure()

        if isConnected {
            async let sunset: () = refreshSunset()
            async let sensors: () = refreshSensors()
            _ = await (sunset, sensors)
        }
        isLoading = false
    }
}

/// Receives device configuration from the paired iPhone
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    private let onContextReceived: ([String: Any]) -> Void

    init(onContextReceived: @escaping ([String: Any]) -> Void) {
        self.onContextReceived = onContextReceived
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Check if there's already a context from the phone
        if !session.receivedApplicationContext.isEmpty {
            onContextReceived(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        onContextReceived(applicationContext)
    }
}
