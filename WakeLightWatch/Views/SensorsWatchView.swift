import SwiftUI

struct SensorsWatchView: View {
    @EnvironmentObject var watchState: WatchState

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Temperature card
                SensorCard(
                    icon: "thermometer.medium",
                    title: "Temperature",
                    value: temperatureString,
                    description: temperatureDescription,
                    color: temperatureColor
                )

                // Humidity card
                SensorCard(
                    icon: "humidity.fill",
                    title: "Humidity",
                    value: "\(watchState.sensorData.humidity)%",
                    description: watchState.sensorData.humidityDescription,
                    color: humidityColor
                )

                // Light level card
                SensorCard(
                    icon: "sun.max",
                    title: "Light",
                    value: "\(watchState.sensorData.lightLevel) lux",
                    description: watchState.sensorData.lightDescription,
                    color: lightColor
                )

                // Sound level card
                SensorCard(
                    icon: "speaker.wave.2",
                    title: "Sound",
                    value: "\(watchState.sensorData.soundLevel) dB",
                    description: watchState.sensorData.soundDescription,
                    color: soundColor
                )
            }
            .padding(.horizontal)
        }
        .navigationTitle("Sensors")
        .task {
            await watchState.refreshSensors()
        }
        .onReceive(timer) { _ in
            Task {
                await watchState.refreshSensors()
            }
        }
    }

    private var temperatureString: String {
        if watchState.useFahrenheit {
            return watchState.sensorData.temperatureFahrenheitString
        }
        return watchState.sensorData.temperatureString
    }

    private var temperatureDescription: String {
        let temp = watchState.sensorData.temperature
        if temp < 16 { return "Too cold" }
        if temp > 22 { return "Too warm" }
        return "Optimal"
    }

    private var temperatureColor: Color {
        let celsius = watchState.sensorData.temperature
        if celsius < 18 {
            return .blue
        } else if celsius > 26 {
            return .red
        }
        return .green
    }

    private var humidityColor: Color {
        let humidity = watchState.sensorData.humidity
        if humidity < 30 {
            return .orange
        } else if humidity > 60 {
            return .blue
        }
        return .green
    }

    private var lightColor: Color {
        let lux = watchState.sensorData.lightLevel
        if lux < 10 {
            return .indigo
        } else if lux < 100 {
            return .yellow
        }
        return .orange
    }

    private var soundColor: Color {
        let db = watchState.sensorData.soundLevel
        if db < 35 {
            return .green
        } else if db < 50 {
            return .yellow
        }
        return .red
    }
}

struct SensorCard: View {
    let icon: String
    let title: String
    let value: String
    var description: String? = nil
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)

            if let description = description {
                Text(description)
                    .font(.caption2)
                    .foregroundColor(color.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

#Preview {
    SensorsWatchView()
        .environmentObject(WatchState())
}
