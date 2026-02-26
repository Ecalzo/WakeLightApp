import Foundation
import WatchConnectivity

/// Sends device configuration to the paired Apple Watch
class PhoneConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Send the current device IP and settings to the watch
    func sendDeviceConfig(ip: String, useFahrenheit: Bool) {
        let context: [String: Any] = [
            "deviceIP": ip,
            "useFahrenheit": useFahrenheit
        ]

        guard WCSession.default.activationState == .activated else {
            // Session not yet activated — queue the context and retry after activation
            pendingContext = context
            return
        }

        try? WCSession.default.updateApplicationContext(context)
    }

    private var pendingContext: [String: Any]?

    /// Flush any pending context after session activation
    private func flushPendingContext() {
        guard let context = pendingContext else { return }
        pendingContext = nil
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            flushPendingContext()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Watch is requesting the current device config
        if message["request"] as? String == "deviceConfig" {
            Task { @MainActor in
                let appState = AppState.shared
                if let ip = appState.device?.ipAddress {
                    replyHandler([
                        "deviceIP": ip,
                        "useFahrenheit": appState.useFahrenheit
                    ])
                } else {
                    replyHandler(["error": "No device configured"])
                }
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
