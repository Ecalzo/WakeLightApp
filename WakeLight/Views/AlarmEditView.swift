import SwiftUI

struct AlarmEditView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let alarm: Alarm

    @State private var hour: Int
    @State private var minute: Int
    @State private var isEnabled: Bool
    @State private var selectedDays: Set<Int>
    @State private var isSaving = false

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    init(alarm: Alarm) {
        self.alarm = alarm
        _hour = State(initialValue: alarm.hour)
        _minute = State(initialValue: alarm.minute)
        _isEnabled = State(initialValue: alarm.isEnabled)
        _selectedDays = State(initialValue: Set(alarm.activeDays))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Time picker section
                Section {
                    HStack {
                        Spacer()
                        timePicker
                        Spacer()
                    }
                }

                // Enable toggle
                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }

                // Days section
                Section("Repeat") {
                    daysSelector
                }

                // Quick presets
                Section("Presets") {
                    Button("Daily") {
                        selectedDays = Set(1...7)
                    }

                    Button("Weekdays") {
                        selectedDays = Set(1...5)
                    }

                    Button("Weekends") {
                        selectedDays = Set([6, 7])
                    }

                    Button("Once (no repeat)") {
                        selectedDays = []
                    }
                }
                .foregroundColor(AppColors.accent)
            }
            .navigationTitle("Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAlarm()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
    }

    // MARK: - Time Picker

    private var timePicker: some View {
        HStack(spacing: 0) {
            // Hour picker
            Picker("Hour", selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()

            Text(":")
                .font(.largeTitle)
                .fontWeight(.light)

            // Minute picker
            Picker("Minute", selection: $minute) {
                ForEach(0..<60, id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
        }
    }

    // MARK: - Days Selector

    private var daysSelector: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                DayButton(
                    day: days[day - 1],
                    isSelected: selectedDays.contains(day)
                ) {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Save

    private func saveAlarm() {
        isSaving = true

        let dayMask = AlarmSchedule.dayMask(for: Array(selectedDays))

        Task {
            await appState.configureAlarm(
                position: alarm.position,
                hour: hour,
                minute: minute,
                days: dayMask,
                enabled: isEnabled
            )
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Day Button

struct DayButton: View {
    let day: String
    let isSelected: Bool
    let action: () -> Void

    private var fullDayName: String {
        switch day.lowercased() {
        case "mon": return "Monday"
        case "tue": return "Tuesday"
        case "wed": return "Wednesday"
        case "thu": return "Thursday"
        case "fri": return "Friday"
        case "sat": return "Saturday"
        case "sun": return "Sunday"
        default: return day
        }
    }

    var body: some View {
        Button(action: action) {
            Text(day.prefix(1))
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 44, height: 44) // Minimum 44pt touch target per HIG
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fullDayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let alarm = Alarm(
        schedule: AlarmSchedule(position: 1, almhr: 7, almmn: 30, daynm: 62, almvs: nil),
        state: AlarmState(position: 1, prfen: true, prfvs: nil, pwrsv: nil, pswhr: nil, pswmn: nil, ctype: nil, curve: nil, dtefm: nil, spts: nil)
    )
    return AlarmEditView(alarm: alarm)
        .environmentObject(AppState.shared)
}
