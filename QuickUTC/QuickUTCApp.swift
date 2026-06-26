import SwiftUI
import ServiceManagement

@main
struct QuickUTCApp: App {
    @State private var store = TimeZoneStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environment(store)
                .frame(width: 380)
        } label: {
            ClockLabel()
                .environment(store)
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        try? SMAppService.mainApp.register()
    }
}
