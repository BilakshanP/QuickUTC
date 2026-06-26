import SwiftUI
import Combine

struct ClockLabel: View {
    @Environment(TimeZoneStore.self) private var store
    @State private var now = Date()
    @State private var formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("\(formattedTime) \(suffix)")
            .monospacedDigit()
            .font(.system(.body, design: .rounded))
            .accessibilityLabel("Current time: \(formattedTime) \(suffix)")
            .onReceive(timer) { now = $0 }
            .onChange(of: store.primaryID) { configureFormatter() }
            .onAppear { configureFormatter() }
    }

    private func configureFormatter() {
        formatter.timeZone = TimeZone(identifier: store.primaryID) ?? .gmt
    }

    private var formattedTime: String {
        formatter.string(from: now)
    }

    private var suffix: String {
        if store.primaryID == "Etc/GMT" { return "UTC" }
        switch store.labelStyle {
        case "utcOffset":
            return utcOffset
        case "cityName":
            return cityName
        case "abbreviation":
            return abbreviation
        default: // "both"
            return "\(cityName) \(utcOffset)"
        }
    }

    private var utcOffset: String {
        guard let tz = TimeZone(identifier: store.primaryID) else { return "UTC+00:00" }
        let seconds = tz.secondsFromGMT(for: now)
        let sign = seconds >= 0 ? "+" : "-"
        let abs = abs(seconds)
        return String(format: "UTC%@%02d:%02d", sign, abs / 3600, (abs % 3600) / 60)
    }

    private var cityName: String {
        if store.primaryID == "Etc/GMT" { return "GMT" }
        return store.primaryID.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? store.primaryID
    }

    private var abbreviation: String {
        Self.abbreviationsByID[store.primaryID] ?? cityName
    }

    private static let abbreviationsByID: [String: String] = {
        var map: [String: String] = [:]
        for (abbr, id) in TimeZone.abbreviationDictionary {
            map[id] = abbr
        }
        return map
    }()
}
