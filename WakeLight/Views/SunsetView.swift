import SwiftUI

struct SunsetView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRefreshing = false

    @State private var selectedDuration: Int = 20
    @State private var selectedColorScheme: SunsetColorScheme? = nil
    @State private var selectedSound: SunsetSound = .off
    @State private var selectedVolume: Int = 12

    private let durations = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Sunset visualization
                    sunsetVisualization

                    // Status
                    if appState.sunsetState.isOn {
                        statusBadge
                    }

                    // Start/Stop button - positioned at top for easy access
                    controlButton

                    // Duration picker
                    durationPicker

                    // Color scheme picker
                    colorSchemePicker

                    // Sound picker
                    soundPicker

                    // Volume slider (only when sound enabled)
                    if selectedSound != .off {
                        volumeSlider
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Sunset")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                isRefreshing = true
                                await appState.refreshSunset()
                                isRefreshing = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                await appState.refreshSunset()
                // Initialize selection from current state
                selectedDuration = appState.sunsetState.duration
                // Only set color scheme if device has one configured
                if let ctype = appState.sunsetState.ctype {
                    selectedColorScheme = SunsetColorScheme(rawValue: ctype)
                }
                selectedSound = appState.sunsetState.sound
                selectedVolume = appState.sunsetState.volume
            }
        }
    }

    // MARK: - Subviews

    private var sunsetVisualization: some View {
        ZStack {
            // Background gradient
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            appState.sunsetState.isOn ? AppColors.primary : .gray.opacity(0.3),
                            appState.sunsetState.isOn ? .purple.opacity(0.6) : .gray.opacity(0.1),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .opacity(appState.sunsetState.isOn ? 1.0 : 0.5)

            // Moon icon
            Image(systemName: appState.sunsetState.isOn ? "moon.fill" : "moon")
                .font(.system(size: 60))
                .foregroundStyle(
                    appState.sunsetState.isOn
                        ? LinearGradient(colors: [AppColors.primary, AppColors.lightGlow], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                )
        }
        .animation(.easeInOut(duration: 0.5), value: appState.sunsetState.isOn)
    }

    private var statusBadge: some View {
        HStack {
            Image(systemName: "sparkles")
            Text("Sunset Active")
            Text("-")
            Text("\(appState.sunsetState.duration) min")
        }
        .font(.subheadline)
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppColors.primaryContainer.opacity(0.5))
        .cornerRadius(20)
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Duration", systemImage: "clock")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(durations, id: \.self) { duration in
                        Button {
                            selectedDuration = duration
                        } label: {
                            Text("\(duration) min")
                                .font(.subheadline)
                                .fontWeight(selectedDuration == duration ? .semibold : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    selectedDuration == duration
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    selectedDuration == duration ? .white : .primary
                                )
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colorSchemePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Color Scheme", systemImage: "paintpalette")
                .font(.headline)

            VStack(spacing: 8) {
                // "None" option - uses device default
                Button {
                    selectedColorScheme = nil
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "minus")
                                    .foregroundColor(.gray)
                            )
                        Text("Default")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedColorScheme == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }

                ForEach(SunsetColorScheme.allCases) { scheme in
                    Button {
                        selectedColorScheme = scheme
                    } label: {
                        HStack {
                            Circle()
                                .fill(scheme.previewColor)
                                .frame(width: 44, height: 44)
                            Text(scheme.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedColorScheme == scheme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var soundPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ambient Sound", systemImage: "speaker.wave.2")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(SunsetSound.allCases) { sound in
                    Button {
                        selectedSound = sound
                    } label: {
                        HStack {
                            Image(systemName: sound == .off ? "speaker.slash" : "speaker.wave.2")
                                .font(.system(size: 16))
                                .frame(width: 44, height: 44)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(22)
                            Text(sound.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSound == sound {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var volumeSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Volume", systemImage: "speaker.wave.1")
                    .font(.headline)
                Spacer()
                Text("\(selectedVolume)")
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(selectedVolume) },
                    set: { selectedVolume = Int($0) }
                ),
                in: 1...25,
                step: 1
            )
            .tint(AppColors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlButton: some View {
        Button {
            Task {
                if appState.sunsetState.isOn {
                    await appState.stopSunset()
                } else {
                    await appState.startSunset(
                        duration: selectedDuration,
                        colorScheme: selectedColorScheme,  // nil means use device default
                        sound: selectedSound,
                        volume: selectedVolume
                    )
                }
            }
        } label: {
            HStack {
                Image(systemName: appState.sunsetState.isOn ? "stop.fill" : "play.fill")
                Text(appState.sunsetState.isOn ? "Stop Sunset" : "Start Sunset")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(appState.sunsetState.isOn ? AppColors.error : AppColors.primary)
            .foregroundColor(appState.sunsetState.isOn ? AppColors.onError : AppColors.onPrimary)
            .cornerRadius(14)
        }
    }
}

#Preview {
    SunsetView()
        .environmentObject(AppState.shared)
}
