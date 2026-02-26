import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if appState.device == nil {
                SetupView()
            } else {
                ZStack {
                    TabView(selection: $selectedTab) {
                        LightControlView()
                            .tabItem {
                                Label("Light", systemImage: "light.max")
                            }
                            .tag(0)

                        AlarmsView()
                            .tabItem {
                                Label("Alarms", systemImage: "alarm")
                            }
                            .tag(1)

                        SunsetView()
                            .tabItem {
                                Label("Sunset", systemImage: "moon.fill")
                            }
                            .tag(2)

                        SensorsView()
                            .tabItem {
                                Label("Sensors", systemImage: "thermometer.medium")
                            }
                            .tag(3)

                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                            .tag(4)
                    }
                    .task {
                        await appState.configureAPI()
                        await appState.refreshAll()
                    }

                    // Toast overlay
                    if appState.showToast {
                        VStack {
                            ToastView(message: appState.toastMessage, icon: appState.toastIcon)
                                .padding(.top, 60)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            Spacer()
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.showToast)
                        .zIndex(100)
                    }
                }
            }
        }
    }
}

// MARK: - Setup View (First Run)

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var manualIP = ""
    @State private var isScanning = false
    @State private var hasAttemptedDiscovery = false
    @State private var scanStatusText = "Auto-Discover"

    private var isValidIP: Bool {
        isValidIPAddress(manualIP)
    }

    private func isValidIPAddress(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }

        for part in parts {
            guard let number = Int(part), number >= 0, number <= 255 else {
                return false
            }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo/Icon
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppColors.accent.gradient)

                Text("Somneo Control")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Connect to your Philips Somneo Wake-Up Light")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                // Discovery Section
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await performDiscovery()
                        }
                    } label: {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "wifi")
                            }
                            Text(scanStatusText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isScanning)

                    // Manual Entry
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or enter IP manually:")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)

                        HStack {
                            TextField("192.168.1.100", text: $manualIP)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                                .autocorrectionDisabled()

                            Button("Connect") {
                                Task {
                                    await appState.setManualIP(manualIP)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(manualIP.isEmpty || !isValidIP)
                        }

                        // IP validation error
                        if !manualIP.isEmpty && !isValidIP {
                            Text("Enter a valid IP address (e.g., 192.168.1.100)")
                                .font(.caption)
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Error message
                if let error = appState.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                // Status
                if case .found(let device) = appState.discoveryState {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Found: \(device.name) at \(device.ipAddress)")
                            .font(.caption)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .task {
                // Request network access permission on first launch
                // This triggers the permission dialog immediately rather than
                // waiting for the user to tap Auto-Discover
                await DeviceDiscovery.shared.requestNetworkAccess()
            }
        }
    }

    private func performDiscovery() async {
        isScanning = true

        // Show "Requesting network access..." on first attempt
        if !hasAttemptedDiscovery {
            scanStatusText = "Requesting network access..."
        } else {
            scanStatusText = "Scanning..."
        }

        await appState.discoverDevice()

        // If discovery failed and this was the first attempt, retry automatically
        // This handles the case where network permission was just granted
        if case .notFound = appState.discoveryState, !hasAttemptedDiscovery {
            hasAttemptedDiscovery = true
            scanStatusText = "Scanning..."

            // Brief delay to allow permission to take effect
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            await appState.discoverDevice()
        }

        hasAttemptedDiscovery = true
        isScanning = false
        scanStatusText = "Auto-Discover"
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
}
