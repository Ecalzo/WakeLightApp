import SwiftUI

struct AlarmsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAlarm: Alarm?
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.alarms.isEmpty {
                    emptyState
                } else {
                    alarmList
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                isRefreshing = true
                                await appState.refreshAlarms()
                                isRefreshing = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(item: $selectedAlarm) { alarm in
                AlarmEditView(alarm: alarm)
            }
            .refreshable {
                await appState.refreshAlarms()
            }
            .task {
                if appState.alarms.isEmpty {
                    await appState.refreshAlarms()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary)

            Text("No Alarms")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Configure alarms on your Somneo device")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Button("Refresh") {
                Task {
                    await appState.refreshAlarms()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Alarm List

    private var alarmList: some View {
        List {
            ForEach(appState.alarms.sorted { $0.position < $1.position }) { alarm in
                AlarmRow(alarm: alarm) {
                    Task {
                        await appState.setAlarmEnabled(position: alarm.position, enabled: !alarm.isEnabled)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAlarm = alarm
                }
                .contextMenu {
                    Button {
                        selectedAlarm = alarm
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        Task {
                            await appState.setAlarmEnabled(position: alarm.position, enabled: !alarm.isEnabled)
                        }
                    } label: {
                        Label(
                            alarm.isEnabled ? "Disable" : "Enable",
                            systemImage: alarm.isEnabled ? "bell.slash" : "bell"
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Alarm Row

struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.time12Hour)
                    .font(.scaledLargeDisplay(size: 32, weight: .light))
                    .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                    .minimumScaleFactor(0.5)

                Text(alarm.daysDescription)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .accessibilityLabel("Alarm \(alarm.isEnabled ? "enabled" : "disabled")")
        }
        .padding(.vertical, 8)
        .opacity(alarm.isEnabled ? 1.0 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Alarm at \(alarm.time12Hour), \(alarm.daysDescription)")
        .accessibilityValue(alarm.isEnabled ? "Enabled" : "Disabled")
    }
}

#Preview {
    AlarmsView()
        .environmentObject(AppState.shared)
}
