import SwiftUI
import Combine

struct MenuView: View {
    @Environment(TimeZoneStore.self) private var store
    @State private var search = ""
    @State private var now = Date()
    @State private var showingSearch = false
    @State private var editing = false
    @State private var sortLabel = "Custom"
    @State private var convertInput = ""
    @State private var renamingID: String?
    @State private var renameText = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("QuickUTC")
                    .font(.headline)
                Spacer()
                Button { withAnimation { editing.toggle() } } label: {
                    Image(systemName: editing ? "checkmark.circle" : "pencil.circle")
                }
                .buttonStyle(.plain)

                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Quit QuickUTC")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Quick convert
            if !editing {
                quickConvertSection
            }

            // Clock list
            clockList

            if editing {
                Divider().padding(.vertical, 8)
                editModeControls
            }
        }
        .padding(.vertical, 12)
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Quick Convert

    private var quickConvertSection: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Type time (e.g. 14:30)", text: $convertInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            if let parsed = parseTime(convertInput) {
                ForEach(store.selectedIDs, id: \.self) { id in
                    HStack {
                        Text(displayName(for: id))
                            .font(.caption)
                        Spacer()
                        Text(convertedTime(parsed, to: id))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 24)
                }
                Divider().padding(.vertical, 4)
            }
        }
    }

    // MARK: - Clock List

    private var clockList: some View {
        ForEach(Array(store.selectedIDs.enumerated()), id: \.element) { index, id in
            fullRow(index: index, id: id)
        }
    }

    private func compactRow(id: String) -> some View {
        HStack {
            Image(systemName: dayNightEmoji(for: id))
                .font(.caption)
                .foregroundStyle(dayNightEmoji(for: id) == "sun.max.fill" ? .yellow : .indigo)
            Text(displayName(for: id))
                .font(.subheadline)
            Spacer()
            Text(timeDiff(for: id))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(timeString(for: id))
                .font(.system(.subheadline, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 3)
    }

    private func fullRow(index: Int, id: String) -> some View {
        HStack {
            if editing {
                Button {
                    withAnimation {
                        let i = store.selectedIDs.firstIndex(of: id)!
                        if i > 0 { store.selectedIDs.swapAt(i, i - 1) }
                    }
                    sortLabel = "Custom"
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .opacity(index == 0 ? 0.3 : 1)

                Button {
                    withAnimation {
                        let i = store.selectedIDs.firstIndex(of: id)!
                        if i < store.selectedIDs.count - 1 { store.selectedIDs.swapAt(i, i + 1) }
                    }
                    sortLabel = "Custom"
                } label: {
                    Image(systemName: "minus")
                        .font(.caption)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == store.selectedIDs.count - 1)
                .opacity(index == store.selectedIDs.count - 1 ? 0.3 : 1)
            }

            Image(systemName: dayNightEmoji(for: id))
                .font(.caption)
                .foregroundStyle(dayNightEmoji(for: id) == "sun.max.fill" ? .yellow : .indigo)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if renamingID == id {
                        TextField("Label", text: $renameText, onCommit: {
                            store.customLabels[id] = renameText.isEmpty ? nil : renameText
                            renamingID = nil
                        })
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)
                        .frame(width: 120)
                    } else {
                        Text(displayName(for: id))
                            .font(.headline)
                        if editing {
                            Button {
                                renameText = store.customLabels[id] ?? ""
                                renamingID = id
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Text(offsetLabel(for: id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timeDiff(for: id))
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(dateString(for: id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(timeString(for: id))
                .font(.system(.title2, design: .rounded))
                .monospacedDigit()

            if editing {
                if id == store.primaryID {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                } else {
                    Button { store.makePrimary(id) } label: {
                        Image(systemName: "star")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                if store.selectedIDs.count > 1 {
                    Button { store.remove(id) } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Edit Mode

    private var editModeControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label style picker
            HStack {
                Text("Menu bar label:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Bindable(store).labelStyle) {
                    Text("UTC+").tag("utcOffset")
                    Text("City").tag("cityName")
                    Text("Abbr").tag("abbreviation")
                    Text("All").tag("both")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal)

            Divider().padding(.vertical, 8)

            // Toggles
            HStack {
                Toggle("24h", isOn: Bindable(store).use24h)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .font(.caption)
            .padding(.horizontal)

            Divider().padding(.vertical, 8)

            Button { store.collapsed.toggle() } label: {
                Label(store.collapsed ? "Show Clock" : "Hide Clock", systemImage: store.collapsed ? "eye" : "eye.slash")
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Divider().padding(.vertical, 8)

            HStack {
                Menu {
                    Button { sortBy(.name, ascending: true) } label: { Label("Name ↑", systemImage: "textformat") }
                    Button { sortBy(.name, ascending: false) } label: { Label("Name ↓", systemImage: "textformat") }
                    Divider()
                    Button { sortBy(.offset, ascending: true) } label: { Label("UTC Offset ↑", systemImage: "clock") }
                    Button { sortBy(.offset, ascending: false) } label: { Label("UTC Offset ↓", systemImage: "clock") }
                } label: {
                    Label("Sort Timezones", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)

                Spacer()

                Text(sortLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Divider().padding(.vertical, 8)

            if showingSearch {
                searchSection
            } else {
                Button { showingSearch = true } label: {
                    Label("Add Timezone", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Normal Mode

    private var normalModeControls: some View {
        EmptyView()
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Search city or timezone...", text: $search)
                    .textFieldStyle(.roundedBorder)
                Button("Done") {
                    showingSearch = false
                    search = ""
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(store.search(search)) { zone in
                        Button {
                            store.add(zone.id)
                            search = ""
                            showingSearch = false
                        } label: {
                            HStack {
                                Text(zone.offset)
                                    .monospacedDigit()
                                    .frame(width: 90, alignment: .leading)
                                Text(zone.city)
                                    .lineLimit(1)
                                if !zone.aliases.isEmpty {
                                    Text("(\(zone.aliases.prefix(2).joined(separator: ", ")))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.contains(zone.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func displayName(for id: String) -> String {
        if let custom = store.customLabels[id], !custom.isEmpty { return custom }
        if id == "Etc/GMT" { return "GMT" }
        let raw = id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
        return TimeZoneStore.cityNameOverrides[id] ?? raw
    }

    private func timeString(for id: String) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: id) ?? .gmt
        f.dateFormat = store.use24h ? "HH:mm" : "h:mm a"
        return f.string(from: now)
    }

    private func dateString(for id: String) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: id) ?? .gmt
        f.dateFormat = "EEE, MMM d"
        return f.string(from: now)
    }

    private func offsetLabel(for id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "" }
        let seconds = tz.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "-"
        let abs = abs(seconds)
        let offset = String(format: "UTC%@%d:%02d", sign, abs / 3600, (abs % 3600) / 60)
        if let abbr = tz.abbreviation(for: now), !abbr.hasPrefix("GMT") {
            return "\(abbr) \(offset)"
        }
        return offset
    }

    private func timeDiff(for id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "" }
        let diff = (tz.secondsFromGMT() - TimeZone.current.secondsFromGMT()) / 60
        if diff == 0 { return "" }
        let sign = diff > 0 ? "+" : ""
        let h = diff / 60
        let m = abs(diff) % 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h):\(String(format: "%02d", m))h"
    }

    private func dayNightEmoji(for id: String) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: id) ?? .gmt
        f.dateFormat = "HH"
        let hour = Int(f.string(from: now)) ?? 12
        return (hour >= 6 && hour < 18) ? "sun.max.fill" : "moon.fill"
    }

    // MARK: - Quick Convert

    private func parseTime(_ input: String) -> (Int, Int)? {
        let parts = input.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 0 && h < 24 && m >= 0 && m < 60 else { return nil }
        return (h, m)
    }

    private func convertedTime(_ time: (Int, Int), to id: String) -> String {
        guard let primaryTZ = TimeZone(identifier: store.primaryID),
              let targetTZ = TimeZone(identifier: id) else { return "" }
        let diff = targetTZ.secondsFromGMT() - primaryTZ.secondsFromGMT()
        var totalMinutes = time.0 * 60 + time.1 + diff / 60
        totalMinutes = ((totalMinutes % 1440) + 1440) % 1440
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if store.use24h {
            return String(format: "%02d:%02d", h, m)
        } else {
            let period = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            return String(format: "%d:%02d %@", h12, m, period)
        }
    }

    // MARK: - Sorting

    private enum SortKey { case name, offset }

    private func sortBy(_ key: SortKey, ascending: Bool) {
        withAnimation {
            store.selectedIDs.sort { a, b in
                let result: Bool
                switch key {
                case .name:
                    result = displayName(for: a) < displayName(for: b)
                case .offset:
                    let sa = TimeZone(identifier: a)?.secondsFromGMT() ?? 0
                    let sb = TimeZone(identifier: b)?.secondsFromGMT() ?? 0
                    result = sa < sb
                }
                return ascending ? result : !result
            }
        }
        let dir = ascending ? "↑" : "↓"
        sortLabel = "\(key == .name ? "Name" : "UTC Offset") \(dir)"
    }
}
