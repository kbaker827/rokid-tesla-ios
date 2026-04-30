import Foundation
import Network

// MARK: - Glasses TCP server (port 8092)

@MainActor
final class GlassesServer {

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private(set) var clientCount = 0

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        do {
            listener = try NWListener(using: .tcp, on: 8092)
        } catch {
            print("[GlassesServer] Failed to create listener: \(error)")
            return
        }
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[GlassesServer] Listening on :8092")
            case .failed(let err):
                print("[GlassesServer] Listener error: \(err)")
                Task { @MainActor [weak self] in self?.restart() }
            default:
                break
            }
        }
        listener?.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in self?.accept(conn) }
        }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        clientCount = 0
    }

    private func restart() {
        stop()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            self.start()
        }
    }

    // MARK: - Connections

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            switch state {
            case .ready:
                Task { @MainActor [weak self] in
                    self?.connections.append(conn)
                    self?.clientCount = self?.connections.count ?? 0
                }
            case .failed, .cancelled:
                Task { @MainActor [weak self] in
                    self?.connections.removeAll { $0 === conn }
                    self?.clientCount = self?.connections.count ?? 0
                }
            default: break
            }
        }
        conn.start(queue: .main)
    }

    // MARK: - Broadcast

    private func broadcast(_ text: String) {
        guard !connections.isEmpty else { return }
        let payload = (text + "\n").data(using: .utf8)!
        connections.forEach { $0.send(content: payload, completion: .contentProcessed { _ in }) }
    }

    // MARK: - Public API

    func broadcastVehicle(_ data: TeslaVehicleData, vehicle: TeslaVehicle, format: GlassesFormat) {
        let text = formatText(data: data, vehicle: vehicle, format: format)
        let dict: [String: Any] = ["type": "vehicle", "text": text, "vehicle": vehicle.displayName]
        if let json = try? JSONSerialization.data(withJSONObject: dict),
           let str  = String(data: json, encoding: .utf8) { broadcast(str) }
    }

    func broadcastAlert(text: String) {
        let dict: [String: Any] = ["type": "alert", "text": text]
        if let json = try? JSONSerialization.data(withJSONObject: dict),
           let str  = String(data: json, encoding: .utf8) { broadcast(str) }
    }

    func broadcastStatus(text: String) {
        let dict: [String: Any] = ["type": "status", "text": text]
        if let json = try? JSONSerialization.data(withJSONObject: dict),
           let str  = String(data: json, encoding: .utf8) { broadcast(str) }
    }

    // MARK: - Format helpers

    private func formatText(data: TeslaVehicleData, vehicle: TeslaVehicle, format: GlassesFormat) -> String {
        let c = data.chargeState
        let cl = data.climateState
        let d = data.driveState

        switch format {
        case .compact:
            var parts: [String] = ["\(c.batteryLevel)%  \(c.rangeFormatted)"]
            if c.chargingState == "Charging" {
                parts.append("⚡ \(c.chargeRateFormatted)")
            } else {
                parts.append(c.chargingState)
            }
            if d.isDriving { parts.append(d.speedFormatted) }
            else if cl.isClimateOn, let t = cl.insideTempF { parts.append("🌡 \(t)") }
            return parts.joined(separator: "  |  ")

        case .detailed:
            var lines: [String] = []
            lines.append("\(vehicle.displayName)")
            lines.append("🔋 \(c.batteryLevel)%  \(c.rangeFormatted)  \(c.chargingState)")
            if c.chargingState == "Charging" {
                lines.append("⚡ \(c.chargeRateFormatted)  \(c.etaFormatted)")
            }
            if d.isDriving {
                lines.append("🚗 \(d.speedFormatted)  Gear: \(d.gearLabel)")
            }
            if let inside = cl.insideTempF, let outside = cl.outsideTempF {
                let climateStr = cl.isClimateOn ? "🌡 HVAC On" : "🌡 Off"
                lines.append("\(climateStr)  In: \(inside)  Out: \(outside)")
            }
            lines.append("🔒 \(data.vehicleState.locked ? "Locked" : "Unlocked")  \(data.vehicleState.odometerFormatted)")
            return lines.joined(separator: "\n")

        case .minimal:
            return "\(c.batteryLevel)%  \(c.rangeFormatted)  \(c.chargingState == "Charging" ? "⚡" : "")"
        }
    }
}
