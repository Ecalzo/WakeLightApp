import SwiftUI

@main
struct WakeLightApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        PhoneConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
