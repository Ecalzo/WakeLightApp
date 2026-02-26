import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct LightToggleEntry: TimelineEntry {
    let date: Date
    let isOn: Bool
    let brightness: Int
    let isConnected: Bool
}

// MARK: - Timeline Provider

struct LightToggleProvider: AppIntentTimelineProvider {
    typealias Entry = LightToggleEntry
    typealias Intent = ConfigurationAppIntent

    func placeholder(in context: Context) -> LightToggleEntry {
        LightToggleEntry(date: Date(), isOn: false, brightness: 15, isConnected: true)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> LightToggleEntry {
        await fetchEntry()
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<LightToggleEntry> {
        let entry = await fetchEntry()
        // Refresh every 5 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchEntry() async -> LightToggleEntry {
        let defaults = UserDefaults(suiteName: "group.com.wakelight") ?? UserDefaults.standard

        guard let ip = defaults.string(forKey: "wakelightDeviceIP") else {
            return LightToggleEntry(date: Date(), isOn: false, brightness: 15, isConnected: false)
        }

        await WakeLightAPI.shared.configure(with: ip)

        do {
            let state = try await WakeLightAPI.shared.getLightState()
            return LightToggleEntry(date: Date(), isOn: state.isOn, brightness: state.brightness, isConnected: true)
        } catch {
            // Use cached state
            let isOn = defaults.bool(forKey: "wakelightLightOn")
            let brightness = defaults.integer(forKey: "wakelightLightBrightness")
            return LightToggleEntry(date: Date(), isOn: isOn, brightness: brightness > 0 ? brightness : 15, isConnected: false)
        }
    }
}

// MARK: - Configuration Intent

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Light Control"
    static var description = IntentDescription("Control your wake light")
}

// MARK: - Widget View

struct LightToggleWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: LightToggleEntry

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
        VStack(spacing: 8) {
            HStack {
                Image(systemName: entry.isOn ? "sun.max.fill" : "sun.max")
                    .font(.title2)
                    .foregroundColor(entry.isOn ? AppColors.primary : AppColors.textSecondary)
                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.isOn ? "On" : "Off")
                    .font(.title)
                    .fontWeight(.semibold)

                if entry.isOn {
                    Text("Brightness: \(entry.brightness)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("Offline")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            if entry.isOn {
                LinearGradient(
                    colors: [AppColors.primary.opacity(0.3), AppColors.primaryContainer.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(.systemBackground)
            }
        }
    }

    // MARK: - Lock Screen Circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: entry.isOn ? "sun.max.fill" : "sun.max")
                    .font(.title3)
                    .foregroundColor(entry.isOn ? AppColors.primary : AppColors.textSecondary)

                if entry.isOn {
                    Text("\(entry.brightness)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Lock Screen Rectangular

    private var rectangularView: some View {
        HStack {
            Image(systemName: entry.isOn ? "sun.max.fill" : "sun.max")
                .font(.title2)
                .foregroundColor(entry.isOn ? AppColors.primary : AppColors.textSecondary)

            VStack(alignment: .leading) {
                Text("Wake Light")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(entry.isOn ? "On (\(entry.brightness))" : "Off")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Widget Definition

struct LightToggleWidget: Widget {
    let kind: String = "LightToggleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: LightToggleProvider()
        ) { entry in
            LightToggleWidgetView(entry: entry)
        }
        .configurationDisplayName("Light Control")
        .description("View and control your wake light")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    LightToggleWidget()
} timeline: {
    LightToggleEntry(date: .now, isOn: true, brightness: 15, isConnected: true)
    LightToggleEntry(date: .now, isOn: false, brightness: 15, isConnected: true)
}

#Preview("Circular", as: .accessoryCircular) {
    LightToggleWidget()
} timeline: {
    LightToggleEntry(date: .now, isOn: true, brightness: 20, isConnected: true)
}
