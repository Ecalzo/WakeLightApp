import SwiftUI

struct ContentView: View {
    @EnvironmentObject var watchState: WatchState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SunsetWatchView()
                    } label: {
                        Label("Sunset", systemImage: "moon.fill")
                    }
                    .listItemTint(AppColors.primary)

                    NavigationLink {
                        LightWatchView()
                    } label: {
                        Label("Light", systemImage: "lightbulb.fill")
                    }
                    .listItemTint(AppColors.lightGlow)

                    NavigationLink {
                        SensorsWatchView()
                    } label: {
                        Label("Sensors", systemImage: "thermometer.medium")
                    }
                    .listItemTint(AppColors.secondary)
                }

                if !watchState.isConnected, let error = watchState.lastError {
                    Section {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("WakeLight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Circle()
                        .fill(watchState.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .task {
            await watchState.refreshAll()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchState())
}
