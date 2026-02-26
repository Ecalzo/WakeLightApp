import SwiftUI

struct LightControlView: View {
    @EnvironmentObject var appState: AppState
    @State private var localBrightness: Double = 15
    @State private var isDragging = false
    @State private var dragStartBrightness: Double = 15
    @State private var isRefreshing = false

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient based on light state
                    backgroundGradient
                        .ignoresSafeArea()

                    // Main content
                    VStack(spacing: 24) {
                        Spacer()

                        // Light visualization with VoiceOver accessibility
                        lightVisualization
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Light brightness")
                            .accessibilityValue(appState.lightState.isOn ? "\(Int(localBrightness)) out of 25" : "Off")
                            .accessibilityHint("Swipe up or down to adjust brightness")
                            .accessibilityAdjustableAction { direction in
                                switch direction {
                                case .increment:
                                    let newBrightness = min(25, Int(localBrightness) + 1)
                                    localBrightness = Double(newBrightness)
                                    feedbackGenerator.impactOccurred(intensity: 0.4)
                                    Task {
                                        await appState.turnOnLight(brightness: newBrightness, showFeedback: false)
                                    }
                                case .decrement:
                                    let newBrightness = max(1, Int(localBrightness) - 1)
                                    localBrightness = Double(newBrightness)
                                    feedbackGenerator.impactOccurred(intensity: 0.4)
                                    Task {
                                        await appState.turnOnLight(brightness: newBrightness, showFeedback: false)
                                    }
                                @unknown default:
                                    break
                                }
                            }

                        // Status text
                        statusText

                        // Brightness slider (visible when light is on)
                        if appState.lightState.isOn {
                            brightnessSlider
                        }

                        Spacer()

                        // Control buttons
                        controlButtons

                        Spacer()
                            .frame(height: 40)
                    }
                    .padding()

                }
                .contentShape(Rectangle())
                .gesture(brightnessGesture)
            }
            .navigationTitle("Light")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                isRefreshing = true
                                await appState.refreshLight()
                                localBrightness = Double(appState.lightState.brightness)
                                isRefreshing = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                localBrightness = Double(appState.lightState.brightness)
            }
            .onChange(of: appState.lightState.brightness) { _, newValue in
                if !isDragging {
                    localBrightness = Double(newValue)
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let isOn = appState.lightState.isOn
        let brightness = localBrightness / 25.0

        return LinearGradient(
            colors: isOn ? [
                AppColors.primary.opacity(0.1 + brightness * 0.3),
                AppColors.primaryContainer.opacity(0.05 + brightness * 0.15),
                Color(.systemBackground)
            ] : [
                Color(.systemBackground),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.3), value: isOn)
        .animation(.easeInOut(duration: 0.1), value: brightness)
    }

    // MARK: - Light Visualization

    private var lightVisualization: some View {
        let isOn = appState.lightState.isOn
        let brightness = localBrightness / 25.0

        return ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: isOn ? [
                            AppColors.primary.opacity(0.4 * brightness),
                            AppColors.lightGlow.opacity(0.2 * brightness),
                            Color.clear
                        ] : [Color.clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)

            // Main light circle - tappable to toggle
            Circle()
                .fill(
                    RadialGradient(
                        colors: isOn ? [
                            Color.white,
                            AppColors.primary.opacity(0.8)
                        ] : [
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .shadow(color: isOn ? AppColors.primary.opacity(0.5 * brightness) : .clear, radius: 30)
                .onTapGesture {
                    feedbackGenerator.impactOccurred()
                    Task {
                        if isOn {
                            await appState.turnOffLight()
                        } else {
                            let brightness = Int(localBrightness) > 0 ? Int(localBrightness) : 15
                            localBrightness = Double(brightness)
                            await appState.turnOnLight(brightness: brightness)
                        }
                    }
                }

            // Brightness level text
            if isOn {
                Text("\(Int(localBrightness))")
                    .font(.scaledLargeDisplay(size: 48))
                    .foregroundColor(.white.opacity(0.9))
                    .minimumScaleFactor(0.5)
                    .allowsHitTesting(false)
            } else {
                Image(systemName: "power")
                    .font(.scaledSystem(size: 48))
                    .foregroundColor(.gray)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 8) {
            Text(appState.lightState.isOn ? "Light On" : "Light Off")
                .font(.title2)
                .fontWeight(.semibold)

            if appState.lightState.isOn {
                Text("Brightness: \(Int(localBrightness)) / 25")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text("Swipe up/down anywhere to adjust brightness")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 40) {
            // Off button
            Button {
                feedbackGenerator.impactOccurred()
                Task {
                    await appState.turnOffLight()
                }
            } label: {
                VStack {
                    Image(systemName: "power")
                        .font(.title)
                    Text("Off")
                        .font(.caption)
                }
                .frame(width: 100, height: 100)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            }
            .foregroundColor(.primary)

            // Max brightness button
            Button {
                feedbackGenerator.impactOccurred()
                localBrightness = 25
                Task {
                    await appState.turnOnLight(brightness: 25)
                }
            } label: {
                VStack {
                    Image(systemName: "sun.max.fill")
                        .font(.title)
                    Text("Max")
                        .font(.caption)
                }
                .frame(width: 100, height: 100)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            }
            .foregroundColor(.primary)
        }
    }

    // MARK: - Brightness Slider

    private var brightnessSlider: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityHidden(true)

                Slider(
                    value: $localBrightness,
                    in: 1...25,
                    step: 1
                ) { editing in
                    if !editing {
                        // Apply change when slider interaction ends
                        feedbackGenerator.impactOccurred()
                        Task {
                            await appState.turnOnLight(brightness: Int(localBrightness), showFeedback: false)
                        }
                    }
                }
                .tint(AppColors.primary)
                .accessibilityLabel("Brightness slider")
                .accessibilityValue("\(Int(localBrightness)) out of 25")

                Image(systemName: "sun.max")
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)

            Text("Or swipe up/down anywhere")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Gesture

    private var brightnessGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    feedbackGenerator.prepare()
                    // Store initial brightness when drag starts
                    dragStartBrightness = localBrightness
                }

                // Map total drag distance to brightness change
                // 400pt drag = full range (1-25)
                let dragDistance = -value.translation.height
                let brightnessChange = (dragDistance / 400.0) * 24.0
                let newBrightness = max(1, min(25, dragStartBrightness + brightnessChange))

                // Haptic feedback at each integer level
                let roundedNew = round(newBrightness)
                let roundedOld = round(localBrightness)
                if roundedNew != roundedOld {
                    feedbackGenerator.impactOccurred(intensity: 0.4)
                }

                localBrightness = newBrightness
            }
            .onEnded { _ in
                isDragging = false

                // Round to nearest integer
                let finalBrightness = Int(round(localBrightness))
                localBrightness = Double(finalBrightness)

                // Apply the change
                feedbackGenerator.impactOccurred()
                Task {
                    await appState.turnOnLight(brightness: finalBrightness)
                }
            }
    }
}

#Preview {
    LightControlView()
        .environmentObject(AppState.shared)
}
