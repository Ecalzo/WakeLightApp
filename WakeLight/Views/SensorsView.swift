import SwiftUI

struct SensorsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRefreshing = false

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isConnected {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Main sensor grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                SensorCard(
                                    icon: "thermometer.medium",
                                    title: "Temperature",
                                    value: appState.useFahrenheit
                                        ? appState.sensorData.temperatureFahrenheitString
                                        : appState.sensorData.temperatureString,
                                    description: temperatureDescription,
                                    color: temperatureColor
                                )

                                SensorCard(
                                    icon: "humidity",
                                    title: "Humidity",
                                    value: "\(appState.sensorData.humidity)%",
                                    description: appState.sensorData.humidityDescription,
                                    color: humidityColor
                                )

                                SensorCard(
                                    icon: "sun.max",
                                    title: "Light",
                                    value: "\(appState.sensorData.lightLevel) lux",
                                    description: appState.sensorData.lightDescription,
                                    color: lightColor
                                )

                                SensorCard(
                                    icon: "speaker.wave.2",
                                    title: "Sound",
                                    value: "\(appState.sensorData.soundLevel) dB",
                                    description: appState.sensorData.soundDescription,
                                    color: soundColor
                                )
                            }
                            .padding(.horizontal)

                            // Sleep Environment Score
                            sleepEnvironmentCard
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await appState.refreshSensors()
                    }
                }
            }
            .navigationTitle("Sensors")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                isRefreshing = true
                                await appState.refreshSensors()
                                isRefreshing = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onReceive(timer) { _ in
                Task {
                    await appState.refreshSensors()
                }
            }
            .task {
                await appState.refreshSensors()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "thermometer.medium.slash")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary)

            Text("No Sensor Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Unable to connect to your wake-up light. Check that it's powered on and connected to the same network.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    isRefreshing = true
                    await appState.refreshSensors()
                    isRefreshing = false
                }
            } label: {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    }
                    Text("Refresh")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
        }
    }

    // MARK: - Sleep Environment Card

    private var sleepEnvironmentCard: some View {
        let score = calculateSleepScore()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.indigo)
                Text("Sleep Environment")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 8) {
                Text("\(score)")
                    .font(.scaledLargeDisplay(size: 48))
                    .foregroundColor(scoreColor(score))
                    .minimumScaleFactor(0.5)

                Text("/ 100")
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, 8)

                Spacer()

                Text(scoreDescription(score))
                    .font(.subheadline)
                    .foregroundColor(scoreColor(score))
                    .padding(.bottom, 8)
            }

            // Score breakdown
            VStack(alignment: .leading, spacing: 4) {
                scoreRow("Temperature", optimal: isTemperatureOptimal)
                scoreRow("Humidity", optimal: isHumidityOptimal)
                scoreRow("Light", optimal: isLightOptimal)
                scoreRow("Sound", optimal: isSoundOptimal)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func scoreRow(_ label: String, optimal: Bool) -> some View {
        HStack {
            Image(systemName: optimal ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(optimal ? .green : .orange)
                .font(.caption)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Score Calculation

    private func calculateSleepScore() -> Int {
        var score = 0

        // Temperature (ideal: 16-20°C / 60-68°F)
        if isTemperatureOptimal { score += 25 }
        else if appState.sensorData.temperature >= 14 && appState.sensorData.temperature <= 22 { score += 15 }

        // Humidity (ideal: 30-50%)
        if isHumidityOptimal { score += 25 }
        else if appState.sensorData.humidity >= 25 && appState.sensorData.humidity <= 60 { score += 15 }

        // Light (ideal: < 5 lux)
        if isLightOptimal { score += 25 }
        else if appState.sensorData.lightLevel < 20 { score += 15 }

        // Sound (ideal: < 35 dB)
        if isSoundOptimal { score += 25 }
        else if appState.sensorData.soundLevel < 45 { score += 15 }

        return score
    }

    private var isTemperatureOptimal: Bool {
        appState.sensorData.temperature >= 16 && appState.sensorData.temperature <= 20
    }

    private var isHumidityOptimal: Bool {
        appState.sensorData.humidity >= 30 && appState.sensorData.humidity <= 50
    }

    private var isLightOptimal: Bool {
        appState.sensorData.lightLevel < 5
    }

    private var isSoundOptimal: Bool {
        appState.sensorData.soundLevel < 35
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    private func scoreDescription(_ score: Int) -> String {
        if score >= 80 { return "Excellent" }
        if score >= 60 { return "Good" }
        if score >= 40 { return "Fair" }
        return "Poor"
    }

    // MARK: - Color Helpers

    private var temperatureDescription: String {
        let temp = appState.sensorData.temperature
        if temp < 16 { return "Too cold" }
        if temp > 22 { return "Too warm" }
        return "Optimal"
    }

    private var temperatureColor: Color {
        let temp = appState.sensorData.temperature
        if temp < 16 { return .blue }
        if temp > 22 { return .red }
        return .green
    }

    private var humidityColor: Color {
        let humidity = appState.sensorData.humidity
        if humidity < 30 { return .orange }
        if humidity > 60 { return .blue }
        return .green
    }

    private var lightColor: Color {
        let lux = appState.sensorData.lightLevel
        if lux < 10 { return .indigo }
        if lux < 100 { return .yellow }
        return .orange
    }

    private var soundColor: Color {
        let db = appState.sensorData.soundLevel
        if db < 35 { return .green }
        if db < 50 { return .yellow }
        return .red
    }
}

// MARK: - Sensor Card

struct SensorCard: View {
    let icon: String
    let title: String
    let value: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)")
        .accessibilityValue("\(value), \(description)")
    }
}

#Preview {
    SensorsView()
        .environmentObject(AppState.shared)
}
