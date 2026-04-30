import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var vm: TeslaViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Group {
                if settings.hasToken {
                    mainContent
                } else {
                    noTokenView
                }
            }
            .navigationTitle("Tesla HUD")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.appState == .polling || vm.appState == .waking || vm.appState == .loadingVehicles {
                        ProgressView().controlSize(.small)
                    } else {
                        Button { Task { await vm.refreshData() } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(vm.selectedVehicle?.isOnline != true)
                    }
                }
            }
        }
    }

    // MARK: - No token

    private var noTokenView: some View {
        ContentUnavailableView(
            "No Access Token",
            systemImage: "key.slash",
            description: Text("Enter your Tesla API access token in Settings.")
        )
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        List {
            // Vehicle picker
            if vm.vehicles.count > 1 {
                Section("Vehicle") {
                    Picker("Select vehicle", selection: Binding(
                        get: { vm.selectedVehicle },
                        set: { if let v = $0 { vm.select(vehicle: v) } }
                    )) {
                        ForEach(vm.vehicles) { v in
                            Text(v.displayName).tag(Optional(v))
                        }
                    }
                }
            }

            // Status banner
            if let v = vm.selectedVehicle {
                Section {
                    VehicleStatusRow(vehicle: v, appState: vm.appState) {
                        Task { await vm.wakeVehicle() }
                    }
                }
            }

            // Error
            if case .error(let msg) = vm.appState {
                Section {
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            // Vehicle data
            if let data = vm.vehicleData {
                batterySection(data.chargeState)
                climateSection(data.climateState)
                driveSection(data.driveState, vehicleState: data.vehicleState)
                commandSection(data)
            }

            // Glasses
            Section("Glasses  TCP :8092") {
                HStack {
                    Image(systemName: "eyeglasses")
                    Text("\(vm.glassesClientCount) client(s) connected")
                        .foregroundStyle(vm.glassesClientCount > 0 ? .green : .secondary)
                    Spacer()
                    if let date = vm.lastUpdated {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Recent alerts
            if !vm.recentAlerts.isEmpty {
                Section("Recent Alerts") {
                    ForEach(vm.recentAlerts.prefix(5), id: \.self) { a in
                        Text(a).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private func batterySection(_ c: ChargeState) -> some View {
        Section("Battery & Charging") {
            // Battery bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: c.batteryIcon)
                        .foregroundStyle(c.batteryLevel < 20 ? .red : .green)
                    Text("\(c.batteryLevel)%")
                        .font(.title2.bold())
                    Spacer()
                    Text(c.rangeFormatted)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(c.batteryLevel), total: 100)
                    .tint(c.batteryLevel < 20 ? .red : c.batteryLevel < 50 ? .orange : .green)
            }
            .padding(.vertical, 4)

            LabeledContent("Status") {
                HStack {
                    Image(systemName: c.chargingIcon)
                    Text(c.chargingState)
                }
            }

            if c.chargingState == "Charging" {
                LabeledContent("Charge rate",  value: c.chargeRateFormatted)
                LabeledContent("ETA",          value: c.etaFormatted)
                LabeledContent("Energy added", value: String(format: "%.1f kWh", c.chargeEnergyAdded))
            }
        }
    }

    private func climateSection(_ cl: ClimateState) -> some View {
        Section("Climate") {
            if let inside = cl.insideTempF {
                LabeledContent("Inside",  value: inside)
            }
            if let outside = cl.outsideTempF {
                LabeledContent("Outside", value: outside)
            }
            LabeledContent("HVAC") {
                Text(cl.isClimateOn ? "On" : "Off")
                    .foregroundStyle(cl.isClimateOn ? .blue : .secondary)
            }
        }
    }

    private func driveSection(_ d: DriveState, vehicleState vs: VehicleState) -> some View {
        Section("Status") {
            LabeledContent("Odometer", value: vs.odometerFormatted)
            LabeledContent("Doors") {
                HStack {
                    Image(systemName: vs.lockIcon)
                        .foregroundStyle(vs.locked ? .green : .orange)
                    Text(vs.locked ? "Locked" : "Unlocked")
                }
            }
            if d.isDriving {
                LabeledContent("Speed", value: d.speedFormatted)
                LabeledContent("Gear",  value: d.gearLabel)
            }
            if vs.sentryMode {
                LabeledContent("Sentry") {
                    Label("Active", systemImage: "eye.fill").foregroundStyle(.orange)
                }
            }
        }
    }

    private func commandSection(_ data: TeslaVehicleData) -> some View {
        Section("Commands") {
            CommandGrid(data: data)
        }
    }
}

// MARK: - Vehicle status row

struct VehicleStatusRow: View {
    let vehicle: TeslaVehicle
    let appState: AppState
    let wakeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: vehicle.stateIcon)
                .foregroundStyle(vehicle.isOnline ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading) {
                Text(vehicle.displayName).font(.headline)
                Text(vehicle.vin).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            if !vehicle.isOnline {
                Button("Wake", action: wakeAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(appState == .waking)
            } else {
                Text(vehicle.stateLabel)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Command grid

struct CommandGrid: View {
    @EnvironmentObject private var vm: TeslaViewModel
    let data: TeslaVehicleData

    private struct Cmd: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let tint: Color
        let action: () async -> Void
    }

    var body: some View {
        let cmds = makeCommands()
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
            ForEach(cmds) { cmd in
                Button {
                    Task { await cmd.action() }
                } label: {
                    Label(cmd.label, systemImage: cmd.icon)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(cmd.tint)
                .disabled(vm.commandInFlight)
            }
        }
        .padding(.vertical, 4)
    }

    private func makeCommands() -> [Cmd] {
        let locked = data.vehicleState.locked
        let climOn = data.climateState.isClimateOn
        return [
            Cmd(label: locked ? "Unlock" : "Lock",
                icon:  locked ? "lock.open.fill" : "lock.fill",
                tint:  locked ? .orange : .green) { await vm.toggleLock() },
            Cmd(label: climOn ? "Stop Climate" : "Start Climate",
                icon:  climOn ? "snowflake" : "thermometer.sun",
                tint:  climOn ? .blue : .red) { await vm.toggleClimate() },
            Cmd(label: "Honk",
                icon:  "speaker.wave.2.fill",
                tint:  .gray) { await vm.honkHorn() },
            Cmd(label: "Flash Lights",
                icon:  "flashlight.on.fill",
                tint:  .yellow) { await vm.flashLights() },
            Cmd(label: "Open Charge Port",
                icon:  "bolt.car.fill",
                tint:  .purple) { await vm.openChargePort() },
        ]
    }
}

#Preview {
    DashboardView()
        .environmentObject(TeslaViewModel())
        .environmentObject(SettingsStore.shared)
}
