#if DEBUG
import AppKit
import SpeederCore
import SwiftUI

/// Renders the real views with synthetic statistics, without starting capture.
@MainActor
enum PreviewExport {
    static func run(directory: String) throws {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let name = "Speeder.Preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        let preferences = AppPreferences(defaults: defaults)
        let session = TypingSession()
        var date = Date().addingTimeInterval(-260)
        for index in 0..<650 {
            if index == 200 || index == 400 { date = date.addingTimeInterval(45) }
            date = date.addingTimeInterval(0.12 + 0.1 * (1 + sin(Double(index) / 29)))
            session.record(index % 6 == 5 ? .separator : .character, at: date)
        }
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = try StatisticsArchive(url: scratch.appendingPathComponent("preview.sqlite"))
        for day in 0..<30 {
            for minute in 0..<30 + day % 15 {
                let date = Calendar.current.date(byAdding: .day, value: -day, to: Calendar.current.startOfDay(for: Date()))!.addingTimeInterval(Double(600 + minute) * 60)
                archive.record(at: date, words: 30 + day % 25, keystrokes: 180 + day % 100, activeSeconds: 45,
                               peak: Double(70 + day % 30), sample: Double(40 + day % 25))
            }
        }
        try archive.flush()
        let store = SpeedStore(session: session, preferences: preferences, archive: archive)
        store.updateSnapshot()
        let mainWindow = MainWindowController(store: store)
        let statusItem = StatusItemController(store: store, mainWindow: mainWindow)
        statusItem.install()
        try statusItem.validatePopoverBounds()
        let route = WindowRoute()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .light ? "light" : "dark"
            try save(DashboardView(store: store, preferences: preferences, route: route).frame(width: 900, height: 740), scheme: scheme, to: url.appendingPathComponent("session-\(suffix).png"))
            route.page = .statistics
            try save(DashboardView(store: store, preferences: preferences, route: route).frame(width: 900, height: 740), scheme: scheme, to: url.appendingPathComponent("statistics-\(suffix).png"))
            route.page = .settings
            try save(DashboardView(store: store, preferences: preferences, route: route).frame(width: 900, height: 740), scheme: scheme, to: url.appendingPathComponent("settings-\(suffix).png"))
            route.page = .session
            try save(StatsPanelView(store: store, openDashboard: {}, openSettings: {}).background(Color(nsColor: .windowBackgroundColor)), scheme: scheme, to: url.appendingPathComponent("popover-\(suffix).png"))
            try save(OnboardingView(store: store, preferences: preferences, finish: {}).background(Color(nsColor: .windowBackgroundColor)), scheme: scheme, to: url.appendingPathComponent("onboarding-\(suffix).png"))
        }
        preferences.accentHex = "8B5CF6"
        route.page = .session
        try save(ThemeView(preferences: preferences) { DashboardView(store: store, preferences: preferences, route: route) }.frame(width: 900, height: 740), scheme: .dark, to: url.appendingPathComponent("custom-accent.png"))
        preferences.accentHex = "1F9E7D"
        let emptyStore = SpeedStore(preferences: preferences)
        try save(DashboardView(store: emptyStore, preferences: preferences, route: route).frame(width: 800, height: 580), scheme: .light, to: url.appendingPathComponent("empty-small.png"))
    }

    private static func save<V: View>(_ view: V, scheme: ColorScheme, to url: URL) throws {
        NSApp.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, scheme))
        let size = hosting.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderBack(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw CocoaError(.fileWriteUnknown) }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        window.orderOut(nil)
        try data.write(to: url)
    }
}
#endif
