import SwiftUI

struct ContentView: View {
    @StateObject private var vm = TeslaViewModel()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "car.fill") }

            GlassesPreviewView()
                .tabItem { Label("Glasses", systemImage: "eyeglasses") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(vm)
        .environmentObject(SettingsStore.shared)
    }
}

#Preview {
    ContentView()
}
