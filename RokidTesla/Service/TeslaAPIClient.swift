import Foundation

// MARK: - Tesla API Client

actor TeslaAPIClient {

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 15
        cfg.timeoutIntervalForResource = 30
        session = URLSession(configuration: cfg)
    }

    // MARK: - Vehicles

    /// List all vehicles on the account.
    func listVehicles(token: String, region: TeslaRegion) async throws -> [TeslaVehicle] {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles")!
        let resp: TeslaVehicleListResponse = try await get(url: url, token: token)
        return resp.response
    }

    /// Wake a sleeping vehicle. Returns when the vehicle reports "online"
    /// or throws TeslaError.wakeTimeout after ~30 s of polling.
    func wakeUp(vehicleId: Int64, token: String, region: TeslaRegion) async throws -> TeslaVehicle {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/wake_up")!
        let resp: TeslaVehicleResponse = try await post(url: url, token: token, body: nil)
        return resp.response
    }

    /// Poll until online, up to maxAttempts × 3 s.
    func wakeAndWait(vehicleId: Int64, token: String, region: TeslaRegion,
                     maxAttempts: Int = 10) async throws -> TeslaVehicle {
        _ = try await wakeUp(vehicleId: vehicleId, token: token, region: region)
        for _ in 0..<maxAttempts {
            try await Task.sleep(for: .seconds(3))
            let vehicles = try await listVehicles(token: token, region: region)
            if let v = vehicles.first(where: { $0.id == vehicleId }), v.isOnline {
                return v
            }
        }
        throw TeslaError.wakeTimeout
    }

    /// Fetch full vehicle data (requires vehicle to be online).
    func vehicleData(vehicleId: Int64, token: String, region: TeslaRegion) async throws -> TeslaVehicleData {
        let endpoints = "charge_state,climate_state,drive_state,vehicle_state"
        var comps = URLComponents(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/vehicle_data")!
        comps.queryItems = [URLQueryItem(name: "endpoints", value: endpoints)]
        let resp: TeslaVehicleDataResponse = try await get(url: comps.url!, token: token)
        return resp.response
    }

    // MARK: - Commands

    func lockDoors(vehicleId: Int64, token: String, region: TeslaRegion) async throws {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/command/door_lock")!
        try await command(url: url, token: token)
    }

    func unlockDoors(vehicleId: Int64, token: String, region: TeslaRegion) async throws {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/command/door_unlock")!
        try await command(url: url, token: token)
    }

    func startClimate(vehicleId: Int64, token: String, region: TeslaRegion) async throws {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/command/auto_conditioning_start")!
        try await command(url: url, token: token)
    }

    func stopClimate(vehicleId: Int64, token: String, region: TeslaRegion) async throws {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/command/auto_conditioning_stop")!
        try await command(url: url, token: token)
    }

    func honkHorn(vehicleId: Int64, token: String, region: TeslaRegion) async throws {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/command/honk_horn")!
        try await command(url: url, token: token)
    }

    func flashLights(vehicleId: Int64, token: String, region: TeslaRegion) async throws {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/command/flash_lights")!
        try await command(url: url, token: token)
    }

    func openChargePort(vehicleId: Int64, token: String, region: TeslaRegion) async throws {
        let url = URL(string: "\(region.baseURL)/api/1/vehicles/\(vehicleId)/command/charge_port_door_open")!
        try await command(url: url, token: token)
    }

    // MARK: - Refresh token exchange

    func refreshAccessToken(refreshToken: String) async throws -> TokenResponse {
        let url = URL(string: "https://auth.tesla.com/oauth2/v3/token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type":    "refresh_token",
            "client_id":     "ownerapi",
            "refresh_token": refreshToken,
            "scope":         "openid email offline_access"
        ]
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        try checkHTTP(resp, data: data)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - Private helpers

    private func get<T: Decodable>(url: URL, token: String) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        try checkHTTP(resp, data: data)
        return try decoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(url: URL, token: String, body: [String: Any]?) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        try checkHTTP(resp, data: data)
        return try decoder().decode(T.self, from: data)
    }

    private func command(url: URL, token: String) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await session.data(for: req)
        try checkHTTP(resp, data: data)
    }

    private func checkHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TeslaError.invalidResponse
        }
        switch http.statusCode {
        case 200...299: return
        case 401:       throw TeslaError.unauthorized
        case 408:       throw TeslaError.vehicleAsleep
        case 429:       throw TeslaError.rateLimited
        default:
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw TeslaError.apiError(http.statusCode, msg)
        }
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }
}

// MARK: - Token response

struct TokenResponse: Codable {
    let accessToken:  String
    let refreshToken: String
    let expiresIn:    Int

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}

// MARK: - Errors

enum TeslaError: LocalizedError {
    case unauthorized
    case vehicleAsleep
    case wakeTimeout
    case rateLimited
    case invalidResponse
    case apiError(Int, String)
    case noVehicleSelected

    var errorDescription: String? {
        switch self {
        case .unauthorized:     return "Invalid or expired access token."
        case .vehicleAsleep:    return "Vehicle is asleep. Try waking it first."
        case .wakeTimeout:      return "Vehicle did not come online in time."
        case .rateLimited:      return "Rate limited by Tesla API. Try again later."
        case .invalidResponse:  return "Unexpected server response."
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        case .noVehicleSelected: return "No vehicle selected."
        }
    }
}
