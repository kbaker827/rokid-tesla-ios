import Foundation
import Combine

final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    private enum Key {
        static let accessToken      = "tesla_access_token"
        static let refreshToken     = "tesla_refresh_token"
        static let selectedVehicleId = "selected_vehicle_id"
        static let pollingInterval  = "polling_interval"
        static let glassesFormat    = "glasses_format"
        static let alertLowBattery  = "alert_low_battery"
        static let lowBatteryPct    = "low_battery_pct"
        static let alertChargeComplete = "alert_charge_complete"
        static let alertUnlocked    = "alert_unlocked"
        static let useMetric        = "use_metric"
        static let apiRegion        = "api_region"
    }

    // MARK: - Published

    @Published var accessToken: String {
        didSet { UserDefaults.standard.set(accessToken, forKey: Key.accessToken) }
    }
    @Published var refreshToken: String {
        didSet { UserDefaults.standard.set(refreshToken, forKey: Key.refreshToken) }
    }
    @Published var selectedVehicleId: Int64? {
        didSet { UserDefaults.standard.set(selectedVehicleId.map { Int($0) }, forKey: Key.selectedVehicleId) }
    }
    @Published var pollingInterval: Double {   // seconds
        didSet { UserDefaults.standard.set(pollingInterval, forKey: Key.pollingInterval) }
    }
    @Published var glassesFormat: GlassesFormat {
        didSet { UserDefaults.standard.set(glassesFormat.rawValue, forKey: Key.glassesFormat) }
    }
    @Published var alertLowBattery: Bool {
        didSet { UserDefaults.standard.set(alertLowBattery, forKey: Key.alertLowBattery) }
    }
    @Published var lowBatteryPct: Int {
        didSet { UserDefaults.standard.set(lowBatteryPct, forKey: Key.lowBatteryPct) }
    }
    @Published var alertChargeComplete: Bool {
        didSet { UserDefaults.standard.set(alertChargeComplete, forKey: Key.alertChargeComplete) }
    }
    @Published var alertUnlocked: Bool {
        didSet { UserDefaults.standard.set(alertUnlocked, forKey: Key.alertUnlocked) }
    }
    @Published var useMetric: Bool {
        didSet { UserDefaults.standard.set(useMetric, forKey: Key.useMetric) }
    }
    @Published var apiRegion: TeslaRegion {
        didSet { UserDefaults.standard.set(apiRegion.rawValue, forKey: Key.apiRegion) }
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard
        accessToken   = ud.string(forKey: Key.accessToken)  ?? ""
        refreshToken  = ud.string(forKey: Key.refreshToken) ?? ""
        pollingInterval = ud.object(forKey: Key.pollingInterval) as? Double ?? 30
        useMetric     = ud.object(forKey: Key.useMetric) as? Bool ?? false
        alertLowBattery   = ud.object(forKey: Key.alertLowBattery) as? Bool ?? true
        lowBatteryPct     = ud.object(forKey: Key.lowBatteryPct) as? Int ?? 20
        alertChargeComplete = ud.object(forKey: Key.alertChargeComplete) as? Bool ?? true
        alertUnlocked   = ud.object(forKey: Key.alertUnlocked) as? Bool ?? false

        if let raw = ud.string(forKey: Key.glassesFormat),
           let fmt = GlassesFormat(rawValue: raw) {
            glassesFormat = fmt
        } else {
            glassesFormat = .compact
        }

        if let raw = ud.string(forKey: Key.apiRegion),
           let region = TeslaRegion(rawValue: raw) {
            apiRegion = region
        } else {
            apiRegion = .northAmerica
        }

        if let raw = ud.object(forKey: Key.selectedVehicleId) as? Int {
            selectedVehicleId = Int64(raw)
        } else {
            selectedVehicleId = nil
        }
    }

    var hasToken: Bool { !accessToken.isEmpty }
}

// MARK: - Region

enum TeslaRegion: String, CaseIterable, Identifiable {
    case northAmerica = "na"
    case europe       = "eu"
    case china        = "cn"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .northAmerica: return "North America"
        case .europe:       return "Europe / Middle East / Africa"
        case .china:        return "China"
        }
    }

    var baseURL: String {
        switch self {
        case .northAmerica: return "https://fleet-api.prd.na.vn.cloud.tesla.com"
        case .europe:       return "https://fleet-api.prd.eu.vn.cloud.tesla.com"
        case .china:        return "https://fleet-api.prd.cn.vn.cloud.tesla.com"
        }
    }
}
