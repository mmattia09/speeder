import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    let route = WindowRoute()
    private let store: SpeedStore

    init(store: SpeedStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Speeder"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 800, height: 580)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: DashboardView(store: store, preferences: store.preferences, route: route))
        window.delegate = self
        window.setFrameAutosaveName("SpeederDashboard")
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ page: AppPage = .session, onboarding: Bool = false) {
        route.page = page
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if onboarding { route.showsOnboarding = true }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
