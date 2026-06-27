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

    @State private var timerCancellable: AnyCancellable?

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
        .onAppear {
            now = Date()
            timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { now = $0 }
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }

    // MARK: - Quick Convert

    private var convertSourceIDs: [String] {
        var ids = [TimeZone.current.identifier]
        for id in store.selectedIDs where id != TimeZone.current.identifier {
            ids.append(id)
        }
        return ids
    }

    private var quickConvertSection: some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Type time (e.g. 14:30)", text: $convertInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            if !convertInput.isEmpty {
                Button { convertInput = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            Picker("", selection: Binding(
                get: { store.convertSourceID ?? TimeZone.current.identifier },
                set: { store.convertSourceID = $0 }
            )) {
                ForEach(convertSourceIDs, id: \.self) { id in
                    Text(id == TimeZone.current.identifier ? "Local" : store.displayName(for: id)).tag(id)
                }
            }
            .labelsHidden()
            .frame(width: 100)
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    // MARK: - Clock List

    private var clockList: some View {
        ForEach(Array(store.selectedIDs.enumerated()), id: \.element) { index, id in
            fullRow(index: index, id: id)
        }
    }

    @ViewBuilder
    private func fullRow(index: Int, id: String) -> some View {
        let displayID = isConvertSource(id) ? TimeZone.current.identifier : id
        let dayLabel = relativeDayLabel(for: displayID)
        HStack {
            if editing {
                VStack(spacing: 2) {
                    Button {
                        withAnimation { store.moveUp(index) }
                        sortLabel = "Custom"
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .frame(width: 22, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HoverButtonStyle())
                    .disabled(index == 0)
                    .opacity(index == 0 ? 0.3 : 1)

                    Button {
                        withAnimation { store.moveDown(index) }
                        sortLabel = "Custom"
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .frame(width: 22, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HoverButtonStyle())
                    .disabled(index == store.selectedIDs.count - 1)
                    .opacity(index == store.selectedIDs.count - 1 ? 0.3 : 1)
                }
            }

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
                        Image(systemName: dayNightEmoji(for: id))
                            .font(.caption2)
                        if isConvertSource(id) {
                            Text("Local")
                                .font(.headline)
                                .foregroundStyle(.green)
                        } else {
                            Text(store.displayName(for: id))
                                .font(.headline)
                        }
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
                if store.showOffset || dayLabel != nil {
                    HStack(spacing: 4) {
                        if store.showOffset {
                            Text(offsetLabel(for: displayID))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let day = dayLabel {
                            Text(day)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let parsed = parseTime(convertInput) {
                    if isConvertSource(id) {
                        Text(convertedTime(parsed, to: TimeZone.current.identifier))
                            .font(.system(.title2, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    } else {
                        Text(convertedTime(parsed, to: id))
                            .font(.system(.title2, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text(timeString(for: id))
                        .font(.system(.title2, design: .rounded))
                        .monospacedDigit()
                }
                if store.showOffset {
                    let relativeToID = parseTime(convertInput) != nil ? (store.convertSourceID ?? TimeZone.current.identifier) : nil
                    Text(timeDiff(for: displayID, relativeTo: relativeToID))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
        .background(
            dayLabel != nil
                ? Color.primary.opacity(0.04)
                : Color.clear
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            let text = parseTime(convertInput) != nil
                ? convertedTime(parseTime(convertInput)!, to: isConvertSource(id) ? TimeZone.current.identifier : id)
                : timeString(for: id)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.displayName(for: id)), \(timeString(for: id)), \(offsetLabel(for: id)), \(dayNightEmoji(for: id) == "sun.max.fill" ? "daytime" : "nighttime")")
    }

    // MARK: - Edit Mode

    private var editModeControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu bar label controls
            HStack {
                Label("Label name", systemImage: "character.cursor.ibeam")
                Spacer()
                Picker("", selection: Bindable(store).nameStyle) {
                    Text("None").tag("none")
                    Text("City").tag("city")
                    Text("Abbr").tag("abbreviation")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }
            .padding(.horizontal)

            Divider().padding(.vertical, 8)

            HStack {
                Label("UTC offset in label", systemImage: "menubar.arrow.up.rectangle")
                Spacer()
                Toggle("", isOn: Bindable(store).showLabelOffset)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            .padding(.horizontal)

            Divider().padding(.vertical, 8)

            HStack {
                Label("UTC offset in list", systemImage: "list.bullet")
                Spacer()
                Toggle("", isOn: Bindable(store).showOffset)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
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
                                Text(highlighted(zone.city, query: search))
                                    .lineLimit(1)
                                if !zone.aliases.isEmpty {
                                    Text(highlightedAliases(zone.aliases.prefix(2).map { $0 }, query: search))
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

    private func highlighted(_ text: String, query: String) -> AttributedString {
        var result = AttributedString(text)
        guard !query.isEmpty,
              let range = text.localizedStandardRange(of: query) else { return result }
        let attrRange = AttributedString.Index(range.lowerBound, within: result)!
            ..< AttributedString.Index(range.upperBound, within: result)!
        result[attrRange].foregroundColor = .accentColor
        result[attrRange].font = .body.bold()
        return result
    }

    private func highlightedAliases(_ aliases: [String], query: String) -> AttributedString {
        var result = AttributedString("(")
        for (i, alias) in aliases.enumerated() {
            if i > 0 { result += AttributedString(", ") }
            result += highlighted(alias, query: query)
        }
        result += AttributedString(")")
        return result
    }

    private func isConvertSource(_ id: String) -> Bool {
        guard parseTime(convertInput) != nil else { return false }
        let source = store.convertSourceID ?? TimeZone.current.identifier
        return id == source
    }

    private func timeString(for id: String) -> String {
        FormatterCache.shared.timeFormatter(for: id).string(from: now)
    }


    private func offsetLabel(for id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "" }
        let offset = TimeZoneStore.offsetString(for: tz, at: now)
        if let abbr = tz.abbreviation(for: now), !abbr.hasPrefix("GMT") {
            return "\(abbr) \(offset)"
        }
        return offset
    }

    private func timeDiff(for id: String, relativeTo refID: String? = nil) -> String {
        guard let tz = TimeZone(identifier: id) else { return "" }
        let ref = refID.flatMap { TimeZone(identifier: $0) } ?? TimeZone.current
        let diff = (tz.secondsFromGMT(for: now) - ref.secondsFromGMT(for: now)) / 60
        if diff == 0 { return "" }
        let sign = diff > 0 ? "+" : ""
        let h = diff / 60
        let m = abs(diff) % 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h):\(String(format: "%02d", m))h"
    }

    private func dayNightEmoji(for id: String) -> String {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: id) ?? .gmt
        let hour = cal.component(.hour, from: now)
        return (hour >= 6 && hour < 18) ? "sun.max.fill" : "moon.fill"
    }

    private func relativeDayLabel(for id: String) -> String? {
        let localCal = Calendar.current
        let localDay = localCal.startOfDay(for: now)
        var zoneCal = Calendar.current
        zoneCal.timeZone = TimeZone(identifier: id) ?? .gmt
        let zoneDay = zoneCal.startOfDay(for: now)
        let diff = localCal.dateComponents([.day], from: localDay, to: zoneDay).day ?? 0
        if diff == 0 { return nil }
        return diff > 0 ? "Tomorrow" : "Yesterday"
    }

    // MARK: - Quick Convert

    private func parseTime(_ input: String) -> (Int, Int)? {
        let s = input.trimmingCharacters(in: .whitespaces).lowercased()
        if s.isEmpty { return nil }

        var h: Int, m: Int
        let isPM = s.hasSuffix("pm")
        let isAM = s.hasSuffix("am")
        let stripped = s.replacingOccurrences(of: "pm", with: "")
                        .replacingOccurrences(of: "am", with: "")
                        .trimmingCharacters(in: .whitespaces)

        if stripped.contains(":") {
            let parts = stripped.split(separator: ":")
            guard parts.count == 2, let hr = Int(parts[0]), let mn = Int(parts[1]) else { return nil }
            h = hr; m = mn
        } else if let num = Int(stripped) {
            if num >= 0 && num <= 23 && !isPM && !isAM && stripped.count <= 2 {
                h = num; m = 0
            } else if stripped.count == 3 || stripped.count == 4 {
                h = num / 100; m = num % 100
            } else { return nil }
        } else { return nil }

        if isPM && h < 12 { h += 12 }
        if isAM && h == 12 { h = 0 }

        guard h >= 0 && h < 24 && m >= 0 && m < 60 else { return nil }
        return (h, m)
    }

    private func convertedTime(_ time: (Int, Int), to id: String) -> String {
        let sourceID = store.convertSourceID ?? TimeZone.current.identifier
        guard let sourceTZ = TimeZone(identifier: sourceID),
              let targetTZ = TimeZone(identifier: id) else { return "" }
        let diff = targetTZ.secondsFromGMT(for: now) - sourceTZ.secondsFromGMT(for: now)
        let originalMinutes = time.0 * 60 + time.1
        let totalMinutes = originalMinutes + diff / 60
        let wrapped = ((totalMinutes % 1440) + 1440) % 1440
        let h = wrapped / 60
        let m = wrapped % 60

        var cal = Calendar.current
        cal.timeZone = .gmt
        let date = cal.date(from: DateComponents(hour: h, minute: m)) ?? Date()
        let result = FormatterCache.shared.timeFormatter(for: "GMT").string(from: date)

        if totalMinutes >= 1440 { return result + " +1d" }
        if totalMinutes < 0 { return result + " −1d" }
        return result
    }

    // MARK: - Sorting

    private enum SortKey { case name, offset }

    private func sortBy(_ key: SortKey, ascending: Bool) {
        withAnimation {
            store.selectedIDs.sort { a, b in
                let result: Bool
                switch key {
                case .name:
                    result = store.displayName(for: a) < store.displayName(for: b)
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

private final class FormatterCache {
    static let shared = FormatterCache()

    private var timeCache: [String: DateFormatter] = [:]
    private var lastDay: Int = -1

    func timeFormatter(for id: String) -> DateFormatter {
        let today = Calendar.current.component(.day, from: Date())
        if today != lastDay { lastDay = today; timeCache.removeAll() }
        if let f = timeCache[id] { return f }
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: id) ?? .gmt
        f.timeStyle = .short
        timeCache[id] = f
        return f
    }
}

private struct HoverButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(hovering || configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear)
            )
            .onHover { hovering = $0 }
    }
}
