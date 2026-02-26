import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let alarmTime: String?
    let alarmDays: String?
    let isEnabled: Bool
    let isConnected: Bool
}

// MARK: - Timeline Provider

struct NextAlarmProvider: AppIntentTimelineProvider {
    typealias Entry = NextAlarmEntry
    typealias Intent = AlarmConfigurationIntent

    func placeholder(in context: Context) -> NextAlarmEntry {
        NextAlarmEntry(date: Date(), alarmTime: "7:00 AM", alarmDays: "Weekdays", isEnabled: true, isConnected: true)
    }

    func snapshot(for configuration: AlarmConfigurationIntent, in context: Context) async -> NextAlarmEntry {
        await fetchEntry()
    }

    func timeline(for configuration: AlarmConfigurationIntent, in context: Context) async -> Timeline<NextAlarmEntry> {
        let entry = await fetchEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchEntry() async -> NextAlarmEntry {
        let defaults = UserDefaults(suiteName: "group.com.wakelight") ?? UserDefaults.standard

        guard let ip = defaults.string(forKey: "wakelightDeviceIP") else {
            return NextAlarmEntry(date: Date(), alarmTime: nil, alarmDays: nil, isEnabled: false, isConnected: false)
        }

        await WakeLightAPI.shared.configure(with: ip)

        do {
            let alarms = try await WakeLightAPI.shared.getAlarms()
            let enabledAlarms = alarms.filter { $0.isEnabled }

            if let nextAlarm = enabledAlarms.min(by: { a1, a2 in
                (a1.hour * 60 + a1.minute) < (a2.hour * 60 + a2.minute)
            }) {
                return NextAlarmEntry(
                    date: Date(),
                    alarmTime: nextAlarm.time12Hour,
                    alarmDays: nextAlarm.daysDescription,
                    isEnabled: true,
                    isConnected: true
                )
            } else {
                return NextAlarmEntry(date: Date(), alarmTime: nil, alarmDays: nil, isEnabled: false, isConnected: true)
            }
        } catch {
            return NextAlarmEntry(date: Date(), alarmTime: nil, alarmDays: nil, isEnabled: false, isConnected: false)
        }
    }
}

// MARK: - Configuration Intent

struct AlarmConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Next Alarm"
    static var description = IntentDescription("Shows your next wake light alarm")
}

// MARK: - Widget View

struct NextAlarmWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: NextAlarmEntry

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
                Image(systemName: "alarm.fill")
                    .font(.title2)
                    .foregroundColor(entry.isEnabled ? AppColors.primary : AppColors.textSecondary)
                Spacer()
            }

            Spacer()

            if let time = entry.alarmTime {
                VStack(alignment: .leading, spacing: 4) {
                    Text(time)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let days = entry.alarmDays {
                        Text(days)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            } else {
                Text("No alarm set")
                    .font(.headline)
                    .foregroundColor(AppColors.textSecondary)
            }

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
            Color(.systemBackground)
        }
    }

    // MARK: - Lock Screen Circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: "alarm.fill")
                    .font(.caption)

                if let time = entry.alarmTime {
                    // Extract just the time part
                    let parts = time.split(separator: " ")
                    if let timePart = parts.first {
                        Text(String(timePart))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                } else {
                    Text("--:--")
                        .font(.caption2)
                }
            }
        }
    }

    // MARK: - Lock Screen Rectangular

    private var rectangularView: some View {
        HStack {
            Image(systemName: "alarm.fill")
                .font(.title2)
                .foregroundColor(entry.isEnabled ? AppColors.primary : AppColors.textSecondary)

            VStack(alignment: .leading) {
                Text("Next Alarm")
                    .font(.caption)
                    .fontWeight(.semibold)

                if let time = entry.alarmTime {
                    Text(time)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text("Not set")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Widget Definition

struct NextAlarmWidget: Widget {
    let kind: String = "NextAlarmWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: AlarmConfigurationIntent.self,
            provider: NextAlarmProvider()
        ) { entry in
            NextAlarmWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Alarm")
        .description("Shows your next scheduled wake light alarm")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    NextAlarmWidget()
} timeline: {
    NextAlarmEntry(date: .now, alarmTime: "7:00 AM", alarmDays: "Weekdays", isEnabled: true, isConnected: true)
    NextAlarmEntry(date: .now, alarmTime: nil, alarmDays: nil, isEnabled: false, isConnected: true)
}
