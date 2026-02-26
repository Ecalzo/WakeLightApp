import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingDisconnectAlert = false
    @State private var manualIP = ""
    @State private var isDiscovering = false

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
            Form {
                // Device Section
                Section("Device") {
                    if let device = appState.device {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(device.name)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        HStack {
                            Text("IP Address")
                            Spacer()
                            Text(device.ipAddress)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        HStack {
                            Text("Model")
                            Spacer()
                            Text(device.modelNumber)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        HStack {
                            Text("Status")
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(appState.isConnected ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(appState.isConnected ? "Connected" : "Disconnected")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    Button {
                        Task {
                            isDiscovering = true
                            await appState.discoverDevice()
                            isDiscovering = false
                        }
                    } label: {
                        HStack {
                            if isDiscovering {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isDiscovering ? "Scanning..." : "Re-discover Device")
                        }
                    }
                    .disabled(isDiscovering)

                    if appState.device != nil {
                        Button("Disconnect", role: .destructive) {
                            showingDisconnectAlert = true
                        }
                    }
                }

                // Manual IP Section
                Section("Manual Connection") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("IP Address", text: $manualIP)
                                .keyboardType(.decimalPad)
                                .autocorrectionDisabled()

                            Button("Connect") {
                                Task {
                                    await appState.setManualIP(manualIP)
                                    manualIP = ""
                                }
                            }
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

                // Display Settings
                Section("Display") {
                    Toggle("Use Fahrenheit", isOn: $appState.useFahrenheit)
                        .onChange(of: appState.useFahrenheit) { _, _ in
                            appState.saveSettings()
                        }
                }

                // Shortcuts Section
                Section("Siri Shortcuts") {
                    NavigationLink {
                        ShortcutsInfoView()
                    } label: {
                        Label("Set Up Shortcuts", systemImage: "mic.fill")
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Link(destination: URL(string: "https://www.philips.com/somneo")!) {
                        HStack {
                            Text("Philips Somneo")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }

                // Error display
                if let error = appState.lastError {
                    Section {
                        let parsed = ErrorHelper.parseError(error)
                        ErrorBanner(
                            title: parsed.title,
                            description: parsed.description,
                            retryAction: parsed.isRetryable ? {
                                Task {
                                    isDiscovering = true
                                    await appState.discoverDevice()
                                    isDiscovering = false
                                }
                            } : nil
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Disconnect Device?", isPresented: $showingDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    appState.clearDevice()
                }
            } message: {
                Text("You'll need to reconnect to your wake-up light.")
            }
        }
    }
}

// MARK: - Shortcuts Info View

struct ShortcutsInfoView: View {
    var body: some View {
        List {
            Section {
                Text("WakeLight supports Siri Shortcuts. You can use voice commands or add them to automations.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Section("Available Commands") {
                ShortcutRow(
                    title: "Toggle Wake Light",
                    phrase: "\"Hey Siri, toggle wake light\"",
                    icon: "lightbulb"
                )

                ShortcutRow(
                    title: "Turn On Wake Light",
                    phrase: "\"Hey Siri, turn on wake light\"",
                    icon: "sun.max"
                )

                ShortcutRow(
                    title: "Turn Off Wake Light",
                    phrase: "\"Hey Siri, turn off wake light\"",
                    icon: "moon"
                )

                ShortcutRow(
                    title: "Set Brightness",
                    phrase: "\"Hey Siri, set wake light to 50%\"",
                    icon: "slider.horizontal.3"
                )

                ShortcutRow(
                    title: "Get Bedroom Temperature",
                    phrase: "\"Hey Siri, what's my bedroom temperature\"",
                    icon: "thermometer"
                )
            }

            Section("Setup") {
                Text("1. Open the Shortcuts app")
                Text("2. Tap + to create a new shortcut")
                Text("3. Search for \"WakeLight\"")
                Text("4. Add the desired action")
                Text("5. Optionally add a Siri phrase")
            }
            .font(.subheadline)
        }
        .navigationTitle("Siri Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShortcutRow: View {
    let title: String
    let phrase: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                Text(phrase)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
