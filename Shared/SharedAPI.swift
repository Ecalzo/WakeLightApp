import Foundation

/// SSL bypass delegate for self-signed certificates
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

/// Lightweight API client for widgets and intents
actor WakeLightAPI {
    static let shared = WakeLightAPI()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private var baseURL: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config, delegate: InsecureURLSessionDelegate(), delegateQueue: nil)
    }

    func configure(with ipAddress: String) {
        self.baseURL = "https://\(ipAddress)/di/v1/products/1"
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

    func getLightState() async throws -> LightState {
        let url = try makeURL("/wulgt")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(LightState.self, from: data)
    }

    func setLight(on: Bool? = nil, brightness: Int? = nil) async throws {
        let url = try makeURL("/wulgt")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let on = on { payload["onoff"] = on }
        if let brightness = brightness { payload["ltlvl"] = brightness }
        payload["tempy"] = false
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WakeLightError.requestFailed
        }
    }

    func toggleLight() async throws -> Bool {
        let current = try await getLightState()
        let newState = !current.isOn
        try await setLight(on: newState)
        return newState
    }

    func turnOnLight(brightness: Int = 15) async throws {
        try await setLight(on: true, brightness: max(1, min(25, brightness)))
    }

    func turnOffLight() async throws {
        try await setLight(on: false)
    }

    func getSensorData() async throws -> SensorData {
        let url = try makeURL("/wusrd")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(SensorData.self, from: data)
    }

    func getAlarms() async throws -> [Alarm] {
        async let schedules = getAlarmSchedules()
        async let states = getAlarmStates()

        let (alarmSchedules, alarmStates) = try await (schedules, states)

        return alarmSchedules.map { schedule in
            let state = alarmStates.first { $0.position == schedule.position }
            return Alarm(schedule: schedule, state: state)
        }
    }

    private func getAlarmSchedules() async throws -> [AlarmSchedule] {
        let url = try makeURL("/wualm/aalms")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode([AlarmSchedule].self, from: data)
    }

    private func getAlarmStates() async throws -> [AlarmState] {
        let url = try makeURL("/wualm/aenvs")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode([AlarmState].self, from: data)
    }

    // MARK: - Sunset

    func getSunsetState() async throws -> SimpleSunsetState {
        let url = try makeURL("/wudsk")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(SimpleSunsetState.self, from: data)
    }

    func startSunset(duration: Int = 20, colorType: Int? = nil, soundChannel: String? = nil, volume: Int? = nil) async throws {
        let url = try makeURL("/wudsk")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "onoff": true,
            "durat": duration
        ]
        if let colorType = colorType { payload["ctype"] = colorType }
        if let channel = soundChannel {
            payload["snddv"] = "dus"
            payload["sndch"] = channel
        } else {
            payload["snddv"] = "off"
        }
        if let volume = volume { payload["sndlv"] = volume }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WakeLightError.requestFailed
        }
    }

    func stopSunset() async throws {
        let url = try makeURL("/wudsk")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["onoff": false]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WakeLightError.requestFailed
        }
    }
}

enum WakeLightError: LocalizedError {
    case notConfigured
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Device not configured"
        case .invalidURL: return "Invalid URL"
        case .requestFailed: return "Request failed"
        }
    }
}
