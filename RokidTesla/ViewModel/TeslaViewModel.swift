import Foundation
import Combine

// MARK: - App state

enum AppState: Equatable {
    case noToken
    case idle
    case loadingVehicles
    case waking
    case polling
    case error(String)
}

@MainActor
final class TeslaViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var appState: AppState = .noToken
    @Published private(set) var vehicles: [TeslaVehicle] = []
    @Published private(set) var selectedVehicle: TeslaVehicle?
    @Published private(set) var vehicleData: TeslaVehicleData?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var recentAlerts: [String] = []
    @Published private(set) var glassesClientCount = 0
    @Published private(set) var commandInFlight = false

    // MARK: - Dependencies

    let settings = SettingsStore.shared
    private let api          = TeslaAPIClient()
    private let glassesServer = GlassesServer()

    // MARK: - Alert tracking

    private var prevCharging: String = ""
    private var prevLocked:   Bool   = true
    private var didAlertLowBattery = false

    // MARK: - Timers

    private var pollTimer: AnyCancellable?

    // MARK: - Init

    init() {
        glassesServer.start()
        if settings.hasToken {
            appState = .idle
            Task { await loadVehicles() }
        } else {
            appState = .noToken
        }
    }

    deinit { pollTimer?.cancel() }

    // MARK: - Token saved

    func tokenDidChange() {
        if settings.hasToken {
            appState = .idle
            Task { await loadVehicles() }
        } else {
            appState = .noToken
            stopPolling()
        }
    }

    // MARK: - Load vehicles

    func loadVehicles() async {
        appState = .loadingVehicles
        do {
            vehicles = try await api.listVehicles(token: settings.accessToken, region: settings.apiRegion)
            // Auto-select saved vehicle or first available
            if let savedId = settings.selectedVehicleId,
               let found = vehicles.first(where: { $0.id == savedId }) {
                selectedVehicle = found
            } else if let first = vehicles.first {
                selectedVehicle = first
                settings.selectedVehicleId = first.id
            }
            appState = .idle
            if selectedVehicle != nil { await refreshData() }
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    // MARK: - Select vehicle

    func select(vehicle: TeslaVehicle) {
        selectedVehicle = vehicle
        settings.selectedVehicleId = vehicle.id
        vehicleData = nil
        stopPolling()
        Task { await refreshData() }
    }

    // MARK: - Wake vehicle

    func wakeVehicle() async {
        guard let v = selectedVehicle else { return }
        appState = .waking
        glassesServer.broadcastStatus(text: "Waking \(v.displayName)…")
        do {
            let awake = try await api.wakeAndWait(vehicleId: v.id,
                                                  token: settings.accessToken,
                                                  region: settings.apiRegion)
            selectedVehicle = awake
            appState = .idle
            await refreshData()
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    // MARK: - Refresh data

    func refreshData() async {
        guard let v = selectedVehicle else { return }
        guard v.isOnline else {
            appState = .error("Vehicle is \(v.stateLabel). Wake it first.")
            return
        }
        appState = .polling
        do {
            let data = try await api.vehicleData(vehicleId: v.id,
                                                  token: settings.accessToken,
                                                  region: settings.apiRegion)
            vehicleData = data
            lastUpdated = Date()
            appState    = .idle
            glassesClientCount = glassesServer.clientCount
            glassesServer.broadcastVehicle(data, vehicle: v, format: settings.glassesFormat)
            checkAlerts(data: data)
            startPollingIfNeeded()
        } catch TeslaError.vehicleAsleep {
            appState = .error("Vehicle fell asleep.")
            stopPolling()
        } catch TeslaError.unauthorized {
            appState = .error("Token expired. Please update your access token.")
            stopPolling()
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    // MARK: - Polling

    private func startPollingIfNeeded() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.publish(every: settings.pollingInterval, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshData()
                }
            }
    }

    func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    func restartPolling() {
        stopPolling()
        if selectedVehicle?.isOnline == true { startPollingIfNeeded() }
    }

    // MARK: - Commands

    func toggleLock() async {
        guard let v = selectedVehicle, let data = vehicleData else { return }
        commandInFlight = true
        do {
            if data.vehicleState.locked {
                try await api.unlockDoors(vehicleId: v.id, token: settings.accessToken, region: settings.apiRegion)
                postAlert("🔓 \(v.displayName) unlocked")
            } else {
                try await api.lockDoors(vehicleId: v.id, token: settings.accessToken, region: settings.apiRegion)
                postAlert("🔒 \(v.displayName) locked")
            }
            await refreshData()
        } catch {
            appState = .error(error.localizedDescription)
        }
        commandInFlight = false
    }

    func toggleClimate() async {
        guard let v = selectedVehicle, let data = vehicleData else { return }
        commandInFlight = true
        do {
            if data.climateState.isClimateOn {
                try await api.stopClimate(vehicleId: v.id, token: settings.accessToken, region: settings.apiRegion)
                postAlert("❄️ Climate off")
            } else {
                try await api.startClimate(vehicleId: v.id, token: settings.accessToken, region: settings.apiRegion)
                postAlert("🌡 Climate on")
            }
            await refreshData()
        } catch {
            appState = .error(error.localizedDescription)
        }
        commandInFlight = false
    }

    func honkHorn() async {
        guard let v = selectedVehicle else { return }
        commandInFlight = true
        do {
            try await api.honkHorn(vehicleId: v.id, token: settings.accessToken, region: settings.apiRegion)
        } catch {
            appState = .error(error.localizedDescription)
        }
        commandInFlight = false
    }

    func flashLights() async {
        guard let v = selectedVehicle else { return }
        commandInFlight = true
        do {
            try await api.flashLights(vehicleId: v.id, token: settings.accessToken, region: settings.apiRegion)
        } catch {
            appState = .error(error.localizedDescription)
        }
        commandInFlight = false
    }

    func openChargePort() async {
        guard let v = selectedVehicle else { return }
        commandInFlight = true
        do {
            try await api.openChargePort(vehicleId: v.id, token: settings.accessToken, region: settings.apiRegion)
            postAlert("🔌 Charge port opened")
        } catch {
            appState = .error(error.localizedDescription)
        }
        commandInFlight = false
    }

    func refreshToken() async {
        guard !settings.refreshToken.isEmpty else { return }
        do {
            let tokens = try await api.refreshAccessToken(refreshToken: settings.refreshToken)
            settings.accessToken  = tokens.accessToken
            settings.refreshToken = tokens.refreshToken
            tokenDidChange()
        } catch {
            appState = .error("Token refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Alerts

    private func checkAlerts(data: TeslaVehicleData) {
        let c  = data.chargeState
        let vs = data.vehicleState

        // Charge complete
        if settings.alertChargeComplete,
           prevCharging == "Charging", c.chargingState == "Complete" {
            postAlert("✅ \(selectedVehicle?.displayName ?? "Tesla") fully charged!")
        }

        // Low battery (only alert once per session until it charges)
        if settings.alertLowBattery,
           c.batteryLevel <= settings.lowBatteryPct,
           c.chargingState == "Disconnected",
           !didAlertLowBattery {
            postAlert("🪫 Low battery: \(c.batteryLevel)%  \(c.rangeFormatted)")
            didAlertLowBattery = true
        }
        if c.batteryLevel > settings.lowBatteryPct { didAlertLowBattery = false }

        // Left unlocked (transition from locked → unlocked while stationary)
        if settings.alertUnlocked,
           prevLocked == true, !vs.locked,
           data.driveState.shiftState == nil {
            postAlert("🔓 \(selectedVehicle?.displayName ?? "Tesla") left unlocked")
        }

        prevCharging = c.chargingState
        prevLocked   = vs.locked
    }

    private func postAlert(_ text: String) {
        recentAlerts.insert(text, at: 0)
        if recentAlerts.count > 20 { recentAlerts.removeLast() }
        glassesServer.broadcastAlert(text: text)
    }
}
