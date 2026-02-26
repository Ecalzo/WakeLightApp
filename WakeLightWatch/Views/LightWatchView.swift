import SwiftUI
import WatchKit

struct LightWatchView: View {
    @EnvironmentObject var watchState: WatchState
    @State private var localBrightness: Double = 15
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            // Light visualization
            lightVisualization

            Spacer(minLength: 0)

            // Toggle button
            Button {
                WKInterfaceDevice.current().play(.click)
                Task {
                    await watchState.toggleLight()
                }
            } label: {
                HStack {
                    Image(systemName: watchState.lightState.isOn ? "lightbulb.fill" : "lightbulb")
                    Text(watchState.lightState.isOn ? "Turn Off" : "Turn On")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(watchState.lightState.isOn ? AppColors.lightGlow : .gray)
            .disabled(watchState.isLoading)
        }
        .padding(.horizontal)
        .navigationTitle("Light")
        .focusable()
        .digitalCrownRotation(
            $localBrightness,
            from: 1,
            through: 25,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: localBrightness) { oldValue, newValue in
            if watchState.lightState.isOn && !isDragging && oldValue != newValue {
                Task {
                    await watchState.setLightBrightness(Int(newValue))
                }
            }
        }
        .task {
            await watchState.refreshLight()
            localBrightness = Double(watchState.lightState.ltlvl)
        }
        .onChange(of: watchState.lightState.ltlvl) { _, newValue in
            if !isDragging {
                localBrightness = Double(newValue)
            }
        }
    }

    private var lightVisualization: some View {
        let isOn = watchState.lightState.isOn
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
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 110, height: 110)

            // Main light circle
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
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .shadow(color: isOn ? AppColors.primary.opacity(0.5 * brightness) : .clear, radius: 12)

            // Brightness number
            if isOn {
                Text("\(Int(localBrightness))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            } else {
                Image(systemName: "power")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

#Preview {
    LightWatchView()
        .environmentObject(WatchState())
}
