import Foundation

/// Custom URLSession delegate that bypasses SSL certificate verification
/// Required because Somneo uses a self-signed certificate
class InsecureURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

/// API client for communicating with wake-up light device
actor WakeLightAPI {
    static let shared = WakeLightAPI()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let timeout: TimeInterval = 10.0

    private var baseURL: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config, delegate: InsecureURLSessionDelegate(), delegateQueue: nil)
    }

    /// Configure the API with a device IP address
    func configure(with ipAddress: String) {
        self.baseURL = "https://\(ipAddress)/di/v1/products/1"
    }

    /// Configure with a WakeLightDevice
    func configure(with device: WakeLightDevice) {
        configure(with: device.ipAddress)
    }

    private func makeURL(_ endpoint: String) throws -> URL {
        guard let baseURL = baseURL else {
            throw WakeLightError.notConfigured
        }
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw WakeLightError.invalidURL
        }
        return url
    }

    // MARK: - Device Info

    /// Get device information
    func getDeviceInfo() async throws -> DeviceInfo {
        let url = try makeURL("/device")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(DeviceInfo.self, from: data)
    }

    // MARK: - Light Control

    /// Get current light state
    func getLightState() async throws -> LightState {
        let url = try makeURL("/wulgt")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(LightState.self, from: data)
    }

    /// Set light state
    /// Note: `tempy: false` is always sent to prevent the device from interpreting the command as a sunrise preview
    func setLight(on: Bool? = nil, brightness: Int? = nil, nightLight: Bool? = nil) async throws {
        let url = try makeURL("/wulgt")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = LightRequest(on: on, brightness: brightness, nightLight: nightLight)
        request.httpBody = try encoder.encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WakeLightError.requestFailed
        }
    }

    /// Toggle light on/off
    func toggleLight() async throws -> Bool {
        let current = try await getLightState()
        let newState = !current.isOn
        try await setLight(on: newState)
        return newState
    }

    /// Turn light on with specific brightness
    func turnOnLight(brightness: Int = 15) async throws {
        try await setLight(on: true, brightness: max(1, min(25, brightness)))
    }

    /// Turn light off
    func turnOffLight() async throws {
        try await setLight(on: false)
    }

    // MARK: - Sensors

    /// Get current sensor readings
    func getSensorData() async throws -> SensorData {
        let url = try makeURL("/wusrd")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(SensorData.self, from: data)
    }

    // MARK: - Alarms

    /// Get all alarm schedules
    func getAlarmSchedules() async throws -> [AlarmSchedule] {
        let url = try makeURL("/wualm/aalms")
        let (data, _) = try await session.data(from: url)

        // Try array format first (actual API response format)
        if let arrayResponse = try? decoder.decode(AlarmsArrayResponse.self, from: data) {
            let count = min(arrayResponse.almhr.count, min(arrayResponse.almmn.count, arrayResponse.daynm.count))
            return (0..<count).map { index in
                AlarmSchedule(
                    position: index + 1,
                    almhr: arrayResponse.almhr[index],
                    almmn: arrayResponse.almmn[index],
                    daynm: arrayResponse.daynm[index],
                    almvs: nil
                )
            }
        }

        // Try to decode as array of objects
        if let schedules = try? decoder.decode([AlarmSchedule].self, from: data) {
            return schedules
        }

        // Try wrapper format
        let response = try decoder.decode(AlarmsResponse.self, from: data)
        return response.aalms ?? []
    }

    /// Get all alarm states
    func getAlarmStates() async throws -> [AlarmState] {
        let url = try makeURL("/wualm/aenvs")
        let (data, _) = try await session.data(from: url)

        // Try array format first (actual API response format)
        if let arrayResponse = try? decoder.decode(AlarmStatesArrayResponse.self, from: data) {
            return arrayResponse.prfen.enumerated().map { index, enabled in
                AlarmState(
                    position: index + 1,
                    prfen: enabled,
                    prfvs: nil,
                    pwrsv: nil,
                    pswhr: nil,
                    pswmn: nil,
                    ctype: nil,
                    curve: nil,
                    dtefm: nil,
                    spts: nil
                )
            }
        }

        // Try to decode as array of objects
        if let states = try? decoder.decode([AlarmState].self, from: data) {
            return states
        }

        // Try wrapper format
        let response = try decoder.decode(AlarmStatesResponse.self, from: data)
        return response.aenvs ?? []
    }

    /// Get combined alarm information
    func getAlarms() async throws -> [Alarm] {
        async let schedules = getAlarmSchedules()
        async let states = getAlarmStates()

        let (alarmSchedules, alarmStates) = try await (schedules, states)

        // Combine schedules with states and filter out default/unused alarms
        let alarms = alarmSchedules.compactMap { schedule -> Alarm? in
            let state = alarmStates.first { $0.position == schedule.position }

            // Filter out default/unused alarms:
            // - hour=7, minute=30, days=254 are common defaults
            // - Only include if enabled OR has non-default time/days
            let isDefault = schedule.almhr == 7 && schedule.almmn == 30 && schedule.daynm == 254
            let isEnabled = state?.isEnabled ?? false

            if isDefault && !isEnabled {
                return nil
            }

            return Alarm(schedule: schedule, state: state)
        }

        return alarms
    }

    /// Enable or disable an alarm
    /// Uses the /wualm/prfwu endpoint which requires full alarm data
    func setAlarmEnabled(position: Int, enabled: Bool, hour: Int, minute: Int, days: Int) async throws {
        let url = try makeURL("/wualm/prfwu")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "prfnr": position,
            "prfen": enabled,
            "almhr": hour,
            "almmn": minute,
            "daynm": days
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WakeLightError.requestFailed
        }
    }

    /// Configure a wake-up alarm
    func configureAlarm(position: Int, hour: Int, minute: Int, days: Int, enabled: Bool) async throws {
        let url = try makeURL("/wualm/prfwu")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "prfnr": position,
            "prfen": enabled,
            "almhr": hour,
            "almmn": minute,
            "daynm": days
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WakeLightError.requestFailed
        }
    }

    // MARK: - Sunset/RelaxBreathe

    /// Get sunset/relax state
    func getSunsetState() async throws -> SunsetState {
        let url = try makeURL("/wudsk")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(SunsetState.self, from: data)
    }

    /// Set sunset state with optional sound configuration
    func setSunset(on: Bool? = nil, duration: Int? = nil, colorType: Int? = nil, soundChannel: String? = nil, volume: Int? = nil) async throws {
        let url = try makeURL("/wudsk")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let on = on { payload["onoff"] = on }
        if let duration = duration { payload["durat"] = duration }
        if let colorType = colorType { payload["ctype"] = colorType }

        // Sound configuration
        // Note: Sunset uses "dus" (dusk sounds), NOT "wus" (wake-up sounds)
        // See API_REFERENCE.md for details
        if let channel = soundChannel {
            payload["snddv"] = "dus"   // Dusk sounds device
            payload["sndch"] = channel
        } else {
            payload["snddv"] = "off"   // Explicitly disable sound
        }
        if let volume = volume { payload["sndlv"] = volume }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WakeLightError.requestFailed
        }
    }

    /// Start sunset with specific duration and optional sound
    func startSunset(duration: Int = 20, colorType: Int? = nil, soundChannel: String? = nil, volume: Int? = nil) async throws {
        try await setSunset(on: true, duration: duration, colorType: colorType, soundChannel: soundChannel, volume: volume)
    }

    /// Stop sunset
    func stopSunset() async throws {
        try await setSunset(on: false)
    }

    // MARK: - Connection Test

    /// Test connection to device
    func testConnection() async -> Bool {
        do {
            _ = try await getDeviceInfo()
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum WakeLightError: LocalizedError {
    case notConfigured
    case invalidURL
    case requestFailed
    case deviceNotFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Device not configured. Please run discovery or enter IP address."
        case .invalidURL:
            return "Invalid device URL."
        case .requestFailed:
            return "Request to device failed."
        case .deviceNotFound:
            return "Wake-up light not found on network."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
