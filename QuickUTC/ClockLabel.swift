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
        var parts: [String] = []
        switch store.nameStyle {
        case .city: parts.append(cityName)
        case .abbreviation: parts.append(abbreviation)
        case .none: break
        }
        if store.showLabelOffset { parts.append(utcOffset) }
        return parts.joined(separator: " ")
    }

    private var utcOffset: String {
        guard let tz = TimeZone(identifier: store.primaryID) else { return "UTC+00:00" }
        return TimeZoneStore.offsetString(for: tz, at: now)
    }

    private var cityName: String {
        store.displayName(for: store.primaryID)
    }

    private var abbreviation: String {
        guard let tz = TimeZone(identifier: store.primaryID) else { return cityName }
        let isDST = tz.isDaylightSavingTime(for: now)
        let abbrs = Self.abbreviationsForID[store.primaryID] ?? []
        let match = abbrs.first { isDST ? $0.contains("D") : !$0.contains("D") }
            ?? abbrs.first
        return match ?? cityName
    }

    private static let abbreviationsForID: [String: [String]] = {
        var map: [String: [String]] = [:]
        // From system dictionary
        for (abbr, id) in TimeZone.abbreviationDictionary where !abbr.hasPrefix("GMT") {
            map[id, default: []].append(abbr)
        }
        // From cityAliases — pick short uppercase strings (abbreviations)
        for (id, aliases) in TimeZoneStore.cityAliases {
            if map[id] != nil { continue }
            let abbrs = aliases.filter { $0.count <= 4 && $0 == $0.uppercased() }
            if !abbrs.isEmpty { map[id] = abbrs }
        }
        return map
    }()
}
