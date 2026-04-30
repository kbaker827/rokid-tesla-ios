import SwiftUI

struct GlassesPreviewView: View {
    @EnvironmentObject private var vm: TeslaViewModel
    @EnvironmentObject private var settings: SettingsStore

    private var previewLines: [String] {
        guard let data = vm.vehicleData,
              let vehicle = vm.selectedVehicle else {
            return ["No vehicle data — refresh or wake vehicle"]
        }
        let c  = data.chargeState
        let cl = data.climateState
        let d  = data.driveState
        let vs = data.vehicleState

        switch settings.glassesFormat {
        case .compact:
            var parts = ["\(c.batteryLevel)%  \(c.rangeFormatted)"]
            if c.chargingState == "Charging" { parts.append("⚡ \(c.chargeRateFormatted)") }
            else { parts.append(c.chargingState) }
            if d.isDriving { parts.append(d.speedFormatted) }
            else if cl.isClimateOn, let t = cl.insideTempF { parts.append("🌡 \(t)") }
            return [parts.joined(separator: "  |  ")]

        case .detailed:
            var lines = [vehicle.displayName]
            lines.append("🔋 \(c.batteryLevel)%  \(c.rangeFormatted)  \(c.chargingState)")
            if c.chargingState == "Charging" {
                lines.append("⚡ \(c.chargeRateFormatted)  \(c.etaFormatted)")
            }
            if d.isDriving { lines.append("🚗 \(d.speedFormatted)  Gear: \(d.gearLabel)") }
            if let inside = cl.insideTempF, let outside = cl.outsideTempF {
                lines.append("\(cl.isClimateOn ? "🌡 On" : "🌡 Off")  In:\(inside)  Out:\(outside)")
            }
            lines.append("\(vs.locked ? "🔒 Locked" : "🔓 Unlocked")  \(vs.odometerFormatted)")
            return lines

        case .minimal:
            let chg = c.chargingState == "Charging" ? " ⚡" : ""
            return ["\(c.batteryLevel)%  \(c.rangeFormatted)\(chg)"]
        }
    }

    private var rawJSON: String {
        guard let data = vm.vehicleData, let vehicle = vm.selectedVehicle else { return "{}" }
        let dict: [String: Any] = [
            "type":    "vehicle",
            "vehicle": vehicle.displayName,
            "text":    previewLines.joined(separator: "\n")
        ]
        guard let jData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let str   = String(data: jData, encoding: .utf8) else { return "{}" }
        return str
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Format picker
                    Picker("Format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Glasses mockup
                    GlassesMockup(lines: previewLines)
                        .padding(.horizontal)

                    // Connection pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.glassesClientCount > 0 ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text("TCP :8092  —  \(vm.glassesClientCount) client(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Raw JSON
                    GroupBox("Raw JSON (sent to glasses)") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(rawJSON)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Glasses Preview")
        }
    }
}

// MARK: - Reusable mockup

struct GlassesMockup: View {
    let lines: [String]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.black)
            RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .lineLimit(2)
                }
                if lines.isEmpty {
                    Text("No data")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .aspectRatio(16/4, contentMode: .fit)
    }
}

#Preview {
    GlassesPreviewView()
        .environmentObject(TeslaViewModel())
        .environmentObject(SettingsStore.shared)
}
