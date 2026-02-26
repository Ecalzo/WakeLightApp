import SwiftUI
import WatchKit

struct SunsetWatchView: View {
    @EnvironmentObject var watchState: WatchState
    @State private var selectedDuration: Int = 20
    @State private var selectedColorScheme: SunsetColorScheme? = nil
    @State private var selectedSound: SunsetSound = .off
    @State private var selectedVolume: Int = 12

    private let durations = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Moon visualization
                sunsetVisualization

                // Status
                if watchState.sunsetState.isOn {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("\(watchState.sunsetState.duration) min")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                }

                // Control button
                Button {
                    WKInterfaceDevice.current().play(.click)
                    Task {
                        if watchState.sunsetState.isOn {
                            await watchState.stopSunset()
                        } else {
                            await watchState.startSunset(
                                duration: selectedDuration,
                                colorScheme: selectedColorScheme,
                                sound: selectedSound,
                                volume: selectedVolume
                            )
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: watchState.sunsetState.isOn ? "stop.fill" : "play.fill")
                        Text(watchState.sunsetState.isOn ? "Stop" : "Start")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(watchState.sunsetState.isOn ? AppColors.error : AppColors.primary)
                .disabled(watchState.isLoading)

                // Settings (only when not active)
                if !watchState.sunsetState.isOn {
                    durationSection
                    colorSchemeSection
                    soundSection

                    if selectedSound != .off {
                        volumeSection
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Sunset")
        .task {
            await watchState.refreshSunset()
            if watchState.sunsetState.isOn {
                selectedDuration = watchState.sunsetState.duration
            }
        }
    }

    // MARK: - Visualization

    private var sunsetVisualization: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            watchState.sunsetState.isOn ? AppColors.primary : .gray.opacity(0.3),
                            watchState.sunsetState.isOn ? .purple.opacity(0.6) : .gray.opacity(0.1),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .opacity(watchState.sunsetState.isOn ? 1.0 : 0.5)

            Image(systemName: watchState.sunsetState.isOn ? "moon.fill" : "moon")
                .font(.system(size: 32))
                .foregroundStyle(
                    watchState.sunsetState.isOn
                        ? LinearGradient(colors: [AppColors.primary, AppColors.lightGlow], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                )
        }
        .animation(.easeInOut(duration: 0.5), value: watchState.sunsetState.isOn)
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Duration")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(selectedDuration) min")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
            }

            // Preset grid (2 rows)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(durations, id: \.self) { duration in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        selectedDuration = duration
                    } label: {
                        Text("\(duration)")
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedDuration == duration ? AppColors.primary : .gray)
                }
            }
        }
    }

    // MARK: - Color Scheme

    private var colorSchemeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Color Scheme")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Default option
            Button {
                WKInterfaceDevice.current().play(.click)
                selectedColorScheme = nil
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "minus")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        )
                    Text("Default")
                        .font(.caption2)
                    Spacer()
                    if selectedColorScheme == nil {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .buttonStyle(.plain)

            ForEach(SunsetColorScheme.allCases) { scheme in
                Button {
                    WKInterfaceDevice.current().play(.click)
                    selectedColorScheme = scheme
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(scheme.previewColor)
                            .frame(width: 16, height: 16)
                        Text(scheme.name)
                            .font(.caption2)
                        Spacer()
                        if selectedColorScheme == scheme {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ambient Sound")
                .font(.caption2)
                .foregroundColor(.secondary)

            ForEach(SunsetSound.allCases) { sound in
                Button {
                    WKInterfaceDevice.current().play(.click)
                    selectedSound = sound
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sound == .off ? "speaker.slash" : "speaker.wave.2")
                            .font(.caption2)
                            .frame(width: 16)
                        Text(sound.rawValue)
                            .font(.caption2)
                        Spacer()
                        if selectedSound == sound {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Volume")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(selectedVolume)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(AppColors.primary)
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
    }
}

#Preview {
    SunsetWatchView()
        .environmentObject(WatchState())
}
