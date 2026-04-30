import Foundation

// MARK: - Vehicle list

struct TeslaVehicle: Identifiable, Codable, Equatable {
    let id: Int64
    let vehicleId: Int64
    let vin: String
    let displayName: String
    let state: String   // "online" | "asleep" | "offline"

    var isOnline: Bool { state == "online" }

    var stateLabel: String {
        switch state {
        case "online":  return "Online"
        case "asleep":  return "Asleep"
        case "offline": return "Offline"
        default:        return state.capitalized
        }
    }

    var stateIcon: String {
        switch state {
        case "online":  return "checkmark.circle.fill"
        case "asleep":  return "moon.fill"
        default:        return "xmark.circle.fill"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case vin
        case displayName = "display_name"
        case state
    }
}

struct TeslaVehicleListResponse: Codable {
    let response: [TeslaVehicle]
    let count: Int
}

struct TeslaVehicleResponse: Codable {
    let response: TeslaVehicle
}

// MARK: - Vehicle data

struct TeslaVehicleData: Codable {
    let chargeState:   ChargeState
    let climateState:  ClimateState
    let driveState:    DriveState
    let vehicleState:  VehicleState

    enum CodingKeys: String, CodingKey {
        case chargeState  = "charge_state"
        case climateState = "climate_state"
        case driveState   = "drive_state"
        case vehicleState = "vehicle_state"
    }
}

struct TeslaVehicleDataResponse: Codable {
    let response: TeslaVehicleData
}

// MARK: - Charge state

struct ChargeState: Codable {
    let batteryLevel:        Int
    let batteryRange:        Double     // miles
    let chargingState:       String     // Disconnected | Charging | Complete | Stopped | NoPower
    let chargeRate:          Double     // mph
    let minutesToFullCharge: Int
    let chargeEnergyAdded:   Double     // kWh
    let chargerPower:        Int        // kW
    let chargePortOpen:      Bool

    var chargingIcon: String {
        switch chargingState {
        case "Charging":      return "bolt.fill"
        case "Complete":      return "battery.100"
        case "Disconnected":  return "cable.connector.slash"
        case "Stopped":       return "pause.fill"
        default:              return "questionmark.circle"
        }
    }

    var batteryIcon: String {
        switch batteryLevel {
        case 0..<20:   return "battery.25"
        case 20..<50:  return "battery.50"
        case 50..<80:  return "battery.75"
        default:       return "battery.100"
        }
    }

    var rangeFormatted: String { String(format: "%.0f mi", batteryRange) }

    var chargeRateFormatted: String {
        chargingState == "Charging" ? String(format: "%.0f mi/hr  \(chargerPower) kW", chargeRate) : ""
    }

    var etaFormatted: String {
        guard chargingState == "Charging", minutesToFullCharge > 0 else { return "" }
        let h = minutesToFullCharge / 60
        let m = minutesToFullCharge % 60
        return h > 0 ? "\(h)h \(m)m to full" : "\(m)m to full"
    }

    enum CodingKeys: String, CodingKey {
        case batteryLevel        = "battery_level"
        case batteryRange        = "battery_range"
        case chargingState       = "charging_state"
        case chargeRate          = "charge_rate"
        case minutesToFullCharge = "minutes_to_full_charge"
        case chargeEnergyAdded   = "charge_energy_added"
        case chargerPower        = "charger_power"
        case chargePortOpen      = "charge_port_door_open"
    }
}

// MARK: - Climate state

struct ClimateState: Codable {
    let insideTemp:         Double?
    let outsideTemp:        Double?
    let isClimateOn:        Bool
    let driverTempSetting:  Double

    var insideTempF: String? {
        guard let t = insideTemp else { return nil }
        return String(format: "%.0f°F", t * 9/5 + 32)
    }
    var outsideTempF: String? {
        guard let t = outsideTemp else { return nil }
        return String(format: "%.0f°F", t * 9/5 + 32)
    }

    enum CodingKeys: String, CodingKey {
        case insideTemp        = "inside_temp"
        case outsideTemp       = "outside_temp"
        case isClimateOn       = "is_climate_on"
        case driverTempSetting = "driver_temp_setting"
    }
}

// MARK: - Drive state

struct DriveState: Codable {
    let speed:      Int?      // mph, nil when parked
    let power:      Int?      // kW
    let shiftState: String?   // "P" "R" "N" "D" nil
    let latitude:   Double?
    let longitude:  Double?

    var isDriving: Bool { shiftState == "D" || shiftState == "R" || shiftState == "N" }
    var speedFormatted: String { speed.map { "\($0) mph" } ?? "Parked" }
    var gearLabel: String { shiftState ?? "P" }

    enum CodingKeys: String, CodingKey {
        case speed
        case power
        case shiftState = "shift_state"
        case latitude
        case longitude
    }
}

// MARK: - Vehicle state

struct VehicleState: Codable {
    let odometer:    Double
    let locked:      Bool
    let frontTrunk:  Int    // 0 = closed, 255 = open
    let rearTrunk:   Int
    let sentryMode:  Bool

    var odometerFormatted: String { String(format: "%.0f mi", odometer) }
    var lockIcon: String { locked ? "lock.fill" : "lock.open.fill" }

    enum CodingKeys: String, CodingKey {
        case odometer   = "odometer"
        case locked
        case frontTrunk = "ft"
        case rearTrunk  = "rt"
        case sentryMode = "sentry_mode"
    }
}

// MARK: - Display format

enum GlassesFormat: String, CaseIterable, Identifiable {
    case compact, detailed, minimal
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// MARK: - Alert type

enum TeslaAlert: String {
    case chargeComplete     = "Charge Complete"
    case lowBattery         = "Low Battery"
    case leftUnlocked       = "Left Unlocked"
    case climateOn          = "Climate Active"
}
