import SwiftUI
import Combine

struct ClockLabel: View {
    @Environment(TimeZoneStore.self) private var store
    @State private var now = Date()
    @State private var formatter = DateFormatter()

    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        Group {
            if store.collapsed {
                Image(systemName: "globe")
            } else {
                Text("\(formattedTime) \(suffix)")
                    .monospacedDigit()
                    .font(.system(.body, design: .rounded))
            }
        }
        .accessibilityLabel("Current time: \(formattedTime) \(suffix)")
        .onChange(of: store.primaryID) { configureFormatter() }
        .onChange(of: store.collapsed) { startOrStopTimer() }
        .onAppear { configureFormatter(); startOrStopTimer() }
        .onDisappear { timerCancellable?.cancel(); timerCancellable = nil }
    }

    private func configureFormatter() {
        formatter.timeZone = TimeZone(identifier: store.primaryID) ?? .gmt
        formatter.timeStyle = .short
    }

    private func startOrStopTimer() {
        if store.collapsed {
            timerCancellable?.cancel()
            timerCancellable = nil
        } else {
            now = Date()
            if timerCancellable == nil {
                timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in now = Date() }
            }
        }
    }

    private var formattedTime: String {
        formatter.string(from: now)
    }

    private var suffix: String {
        if store.primaryID == TimeZoneStore.utcID { return "UTC" }
        switch store.labelStyle {
        case "utcOffset":
            return utcOffset
        case "cityName":
            return cityName
        case "abbreviation":
            return abbreviation
        default:
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
        store.displayName(for: store.primaryID)
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
