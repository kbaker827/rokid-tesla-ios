import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: TeslaViewModel
    @EnvironmentObject private var settings: SettingsStore

    @State private var showToken      = false
    @State private var showRefresh    = false
    @State private var tokenInput     = ""
    @State private var refreshInput   = ""

    var body: some View {
        NavigationStack {
            Form {
                // Authentication
                Section("Tesla Authentication") {
                    // Access token
                    LabeledContent("Access Token") {
                        if showToken {
                            TextField("ey…", text: $settings.accessToken)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            Text(settings.accessToken.isEmpty ? "Not set" : "••••••••")
                                .foregroundStyle(settings.accessToken.isEmpty ? .red : .secondary)
                        }
                    }
                    .onTapGesture { showToken.toggle() }

                    // Refresh token
                    LabeledContent("Refresh Token") {
                        if showRefresh {
                            TextField("Optional", text: $settings.refreshToken)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            Text(settings.refreshToken.isEmpty ? "Not set" : "••••••••")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onTapGesture { showRefresh.toggle() }

                    if !settings.refreshToken.isEmpty {
                        Button("Refresh Access Token") {
                            Task { await vm.refreshToken() }
                        }
                    }

                    Button("Apply & Reload") {
                        vm.tokenDidChange()
                    }
                    .disabled(!settings.hasToken)

                    Picker("API Region", selection: $settings.apiRegion) {
                        ForEach(TeslaRegion.allCases) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                }

                // Polling
                Section {
                    HStack {
                        Text("Poll interval")
                        Spacer()
                        Text("\(Int(settings.pollingInterval)) s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.pollingInterval, in: 10...120, step: 5) {
                        Text("Poll interval")
                    } minimumValueLabel: {
                        Text("10s").font(.caption)
                    } maximumValueLabel: {
                        Text("120s").font(.caption)
                    }
                    .onChange(of: settings.pollingInterval) { _, _ in vm.restartPolling() }
                } header: {
                    Text("Polling")
                } footer: {
                    Text("Lower values keep data fresher but may drain your vehicle's 12V battery if it stays awake too long.")
                }

                // Glasses display
                Section("Glasses Display") {
                    Picker("Format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    LabeledContent("TCP port", value: "8092")
                        .foregroundStyle(.secondary)
                }

                // Alerts
                Section("Alerts") {
                    Toggle("Charge complete", isOn: $settings.alertChargeComplete)

                    Toggle("Low battery", isOn: $settings.alertLowBattery)
                    if settings.alertLowBattery {
                        HStack {
                            Text("Threshold")
                            Spacer()
                            Text("\(settings.lowBatteryPct)%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.lowBatteryPct) },
                            set: { settings.lowBatteryPct = Int($0) }
                        ), in: 10...50, step: 5)
                    }

                    Toggle("Left unlocked", isOn: $settings.alertUnlocked)
                }

                // How to get a token
                Section("Getting a Token") {
                    Link("Tesla Fleet API Docs",
                         destination: URL(string: "https://developer.tesla.com/docs/fleet-api")!)
                    Link("Auth.tesla.com token guide",
                         destination: URL(string: "https://tesla-info.com/tesla-token.php")!)
                    Text("Generate a long-lived token from auth.tesla.com or use the Fleet API OAuth flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // About
                Section("About") {
                    LabeledContent("App",     value: "Rokid Tesla HUD")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("iOS",     value: "17.0+")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TeslaViewModel())
        .environmentObject(SettingsStore.shared)
}
