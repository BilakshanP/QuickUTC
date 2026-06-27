import SwiftUI
import Combine

struct MenuView: View {
    @Environment(TimeZoneStore.self) private var store
    @State private var search = ""
    @State private var now = Date()
    @State private var showingSearch = false

    @State private var editing = false
    @State private var sortAscending = true

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with sort & edit
            HStack {
                Text("QuickUTC")
                    .font(.headline)
                Spacer()

                Button { store.collapsed.toggle() } label: {
                    Image(systemName: store.collapsed ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .help(store.collapsed ? "Show Clock" : "Hide Clock")

                Menu {
                    Button { sortBy(.name, ascending: true) } label: { Label("Name ↑", systemImage: "textformat") }
                    Button { sortBy(.name, ascending: false) } label: { Label("Name ↓", systemImage: "textformat") }
                    Divider()
                    Button { sortBy(.offset, ascending: true) } label: { Label("UTC Offset ↑", systemImage: "clock") }
                    Button { sortBy(.offset, ascending: false) } label: { Label("UTC Offset ↓", systemImage: "clock") }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Button { editing.toggle() } label: {
                    Image(systemName: editing ? "checkmark.circle" : "pencil.circle")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Selected clocks
            clockList

            Divider().padding(.vertical, 8)

            // Add timezone button / search
            if showingSearch {
                searchSection
            } else {
                Button { showingSearch = true } label: {
                    Label("Add Timezone", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            Divider().padding(.vertical, 8)

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

            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit QuickUTC", systemImage: "xmark.circle")
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Clock List

    private var clockList: some View {
        ForEach(Array(store.selectedIDs.enumerated()), id: \.element) { index, id in
            HStack {
                if editing {
                    Button { 
                        withAnimation {
                            let i = store.selectedIDs.firstIndex(of: id)!
                            if i > 0 { store.selectedIDs.swapAt(i, i - 1) }
                        }
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(cityName(for: id))
                        .font(.headline)
                    Text(offsetLabel(for: id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        .help("Set as menu bar clock")
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

    private func timeString(for id: String) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: id) ?? .gmt
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    private func cityName(for id: String) -> String {
        if id == "Etc/GMT" { return "GMT" }
        return id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
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

    // MARK: - Sorting

    private enum SortKey { case name, offset }

    private func sortBy(_ key: SortKey, ascending: Bool) {
        withAnimation {
            store.selectedIDs.sort { a, b in
                let result: Bool
                switch key {
                case .name:
                    result = cityName(for: a) < cityName(for: b)
                case .offset:
                    let sa = TimeZone(identifier: a)?.secondsFromGMT() ?? 0
                    let sb = TimeZone(identifier: b)?.secondsFromGMT() ?? 0
                    result = sa < sb
                }
                return ascending ? result : !result
            }
        }
    }
}
