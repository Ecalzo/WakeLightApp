import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct SensorEntry: TimelineEntry {
    let date: Date
    let temperature: Double
    let humidity: Int
    let useFahrenheit: Bool
    let isConnected: Bool
}

// MARK: - Timeline Provider

struct SensorProvider: AppIntentTimelineProvider {
    typealias Entry = SensorEntry
    typealias Intent = SensorConfigurationIntent

    func placeholder(in context: Context) -> SensorEntry {
        SensorEntry(date: Date(), temperature: 20.5, humidity: 45, useFahrenheit: false, isConnected: true)
    }

    func snapshot(for configuration: SensorConfigurationIntent, in context: Context) async -> SensorEntry {
        await fetchEntry()
    }

    func timeline(for configuration: SensorConfigurationIntent, in context: Context) async -> Timeline<SensorEntry> {
        let entry = await fetchEntry()
        // Refresh every 10 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchEntry() async -> SensorEntry {
        let defaults = UserDefaults(suiteName: "group.com.wakelight") ?? UserDefaults.standard
        let useFahrenheit = defaults.bool(forKey: "wakelightUseFahrenheit")

        guard let ip = defaults.string(forKey: "wakelightDeviceIP") else {
            return SensorEntry(date: Date(), temperature: 0, humidity: 0, useFahrenheit: useFahrenheit, isConnected: false)
        }

        await WakeLightAPI.shared.configure(with: ip)

        do {
            let sensors = try await WakeLightAPI.shared.getSensorData()
            return SensorEntry(
                date: Date(),
                temperature: sensors.temperature,
                humidity: sensors.humidity,
                useFahrenheit: useFahrenheit,
                isConnected: true
            )
        } catch {
            return SensorEntry(date: Date(), temperature: 0, humidity: 0, useFahrenheit: useFahrenheit, isConnected: false)
        }
    }
}

// MARK: - Configuration Intent

struct SensorConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Bedroom Environment"
    static var description = IntentDescription("Shows temperature and humidity from your wake light")
}

// MARK: - Widget View

struct SensorWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: SensorEntry

    private var temperatureString: String {
        if entry.useFahrenheit {
            let fahrenheit = (entry.temperature * 9.0 / 5.0) + 32.0
            return String(format: "%.0f°F", fahrenheit)
        } else {
            return String(format: "%.0f°C", entry.temperature)
        }
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.title2)
                    .foregroundColor(AppColors.secondary)
                Spacer()

                if !entry.isConnected {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(temperatureString)
                        .font(.title)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 4) {
                    Image(systemName: "humidity")
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                    Text("\(entry.humidity)%")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    // MARK: - Lock Screen Circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 1) {
                Image(systemName: "thermometer.medium")
                    .font(.caption2)

                Text(temperatureString)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Lock Screen Rectangular

    private var rectangularView: some View {
        HStack {
            Image(systemName: "thermometer.medium")
                .font(.title3)
                .foregroundColor(AppColors.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(temperatureString)
                    .font(.headline)

                Text("Humidity: \(entry.humidity)%")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Widget Definition

struct SensorWidget: Widget {
    let kind: String = "SensorWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SensorConfigurationIntent.self,
            provider: SensorProvider()
        ) { entry in
            SensorWidgetView(entry: entry)
        }
        .configurationDisplayName("Bedroom Environment")
        .description("Shows temperature and humidity from your wake light")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    SensorWidget()
} timeline: {
    SensorEntry(date: .now, temperature: 20.5, humidity: 45, useFahrenheit: false, isConnected: true)
    SensorEntry(date: .now, temperature: 20.5, humidity: 45, useFahrenheit: true, isConnected: true)
}
