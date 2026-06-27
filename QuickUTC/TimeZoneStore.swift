import SwiftUI
import Combine

@Observable
final class TimeZoneStore {
    static let utcID = "Etc/GMT"

    var selectedIDs: [String] {
        didSet { save() }
    }

    var primaryID: String {
        didSet { UserDefaults.standard.set(primaryID, forKey: "primaryTimeZone") }
    }

    // "utcOffset" or "cityName"
    var labelStyle: String {
        didSet { UserDefaults.standard.set(labelStyle, forKey: "labelStyle") }
    }

    var collapsed: Bool {
        didSet { UserDefaults.standard.set(collapsed, forKey: "collapsed") }
    }

    var showOffset: Bool {
        didSet { UserDefaults.standard.set(showOffset, forKey: "showOffset") }
    }

    var customLabels: [String: String] {
        didSet {
            if let data = try? JSONEncoder().encode(customLabels) {
                UserDefaults.standard.set(data, forKey: "customLabels")
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "selectedTimeZones"),
           let ids = try? JSONDecoder().decode([String].self, from: data), !ids.isEmpty {
            self.selectedIDs = ids
        } else {
            self.selectedIDs = [Self.utcID]
        }
        self.primaryID = UserDefaults.standard.string(forKey: "primaryTimeZone") ?? Self.utcID
        self.labelStyle = UserDefaults.standard.string(forKey: "labelStyle") ?? "both"
        self.collapsed = UserDefaults.standard.bool(forKey: "collapsed")
        self.showOffset = UserDefaults.standard.object(forKey: "showOffset") as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: "customLabels"),
           let labels = try? JSONDecoder().decode([String: String].self, from: data) {
            self.customLabels = labels
        } else {
            self.customLabels = [:]
        }
    }

    func add(_ id: String) {
        guard !selectedIDs.contains(id) else { return }
        selectedIDs.append(id)
        if selectedIDs.count == 1 { primaryID = id }
    }

    func remove(_ id: String) {
        selectedIDs.removeAll { $0 == id }
        if primaryID == id { primaryID = selectedIDs.first ?? Self.utcID }
    }

    func moveUp(_ index: Int) {
        guard index > 0 else { return }
        selectedIDs.swapAt(index, index - 1)
    }

    func moveDown(_ index: Int) {
        guard index < selectedIDs.count - 1 else { return }
        selectedIDs.swapAt(index, index + 1)
    }

    func makePrimary(_ id: String) {
        primaryID = id
    }

    func contains(_ id: String) -> Bool {
        selectedIDs.contains(id)
    }

    func displayName(for id: String) -> String {
        if let custom = customLabels[id], !custom.isEmpty { return custom }
        if id == Self.utcID { return "GMT" }
        let raw = id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
        return Self.cityNameOverrides[id] ?? raw
    }

    private func save() {
        if let data = try? JSONEncoder().encode(selectedIDs) {
            UserDefaults.standard.set(data, forKey: "selectedTimeZones")
        }
    }

    // MARK: - City Search

    // MARK: - Static Data

    static func allZones(for date: Date = Date()) -> [TimeZoneResult] {
        TimeZone.knownTimeZoneIdentifiers.compactMap { id in
            guard let tz = TimeZone(identifier: id) else { return nil }
            let rawCity = id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
            let city = cityNameOverrides[id] ?? rawCity
            return TimeZoneResult(
                id: id,
                city: city,
                offset: offsetString(for: tz, at: date),
                aliases: cityAliases[id] ?? []
            )
        }
        .sorted {
            let s1 = TimeZone(identifier: $0.id)?.secondsFromGMT(for: date) ?? 0
            let s2 = TimeZone(identifier: $1.id)?.secondsFromGMT(for: date) ?? 0
            return s1 == s2 ? $0.city < $1.city : s1 < s2
        }
    }

    static let cityNameOverrides: [String: String] = [
        "Asia/Calcutta": "Kolkata",
        "Asia/Katmandu": "Kathmandu",
        "Asia/Saigon": "Ho Chi Minh",
        "Pacific/Ponape": "Pohnpei",
    ]

    func search(_ query: String) -> [TimeZoneResult] {
        let zones = Self.allZones()
        if query.isEmpty { return zones }
        let q = query.lowercased()
        return zones.filter {
            $0.id.lowercased().contains(q) ||
            $0.city.lowercased().contains(q) ||
            $0.aliases.contains { $0.lowercased().contains(q) }
        }
    }

    static func offsetString(for tz: TimeZone, at date: Date = Date()) -> String {
        let seconds = tz.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let abs = abs(seconds)
        return String(format: "UTC%@%02d:%02d", sign, abs / 3600, (abs % 3600) / 60)
    }

    // Common city aliases → timezone identifiers
    static let cityAliases: [String: [String]] = [
        "Asia/Kolkata": ["Mumbai", "Delhi", "Bangalore", "Bengaluru", "Chennai", "Hyderabad", "India", "IST", "Kolkata"],
        "Asia/Calcutta": ["Mumbai", "Delhi", "Bangalore", "Bengaluru", "Chennai", "Hyderabad", "India", "IST", "Kolkata"],
        "America/New_York": ["NYC", "Manhattan", "Brooklyn", "EST", "EDT"],
        "America/Los_Angeles": ["LA", "San Francisco", "SF", "Hollywood", "PST", "PDT"],
        "America/Chicago": ["Dallas", "Houston", "CST", "CDT"],
        "America/Denver": ["MST", "MDT"],
        "Europe/London": ["UK", "Britain", "GMT", "BST"],
        "Europe/Paris": ["France", "CET", "CEST"],
        "Europe/Berlin": ["Germany", "Munich", "Frankfurt"],
        "Europe/Moscow": ["Russia", "MSK"],
        "Asia/Tokyo": ["Japan", "JST"],
        "Asia/Shanghai": ["Beijing", "China", "CST"],
        "Asia/Hong_Kong": ["HK", "HKT"],
        "Asia/Singapore": ["SGT"],
        "Asia/Dubai": ["UAE", "Abu Dhabi", "GST"],
        "Australia/Sydney": ["AEST", "AEDT"],
        "Australia/Melbourne": ["AEST"],
        "Pacific/Auckland": ["New Zealand", "NZ", "NZST"],
        "America/Toronto": ["Canada Eastern"],
        "America/Vancouver": ["Canada Pacific"],
        "Asia/Seoul": ["Korea", "KST"],
        "Asia/Bangkok": ["Thailand", "ICT"],
        "Asia/Jakarta": ["Indonesia", "WIB"],
        "Africa/Cairo": ["Egypt", "EET"],
        "Africa/Lagos": ["Nigeria", "WAT"],
        "America/Sao_Paulo": ["Brazil", "BRT"],
        "America/Argentina/Buenos_Aires": ["Argentina", "ART"],
    ]
}

struct TimeZoneResult: Identifiable {
    let id: String
    let city: String
    let offset: String
    let aliases: [String]
}
