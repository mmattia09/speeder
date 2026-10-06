import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SpeedStore?
    private var statusController: StatusItemController?
    private var authorizationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = SpeedStore()
        self.store = store

        let statusController = StatusItemController(store: store)
        statusController.install()
        self.statusController = statusController

        store.start()

        // The user may have granted Accessibility access in System Settings
        // while the app was running.
        authorizationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in store.refreshAuthorization() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
        if let authorizationObserver {
            NotificationCenter.default.removeObserver(authorizationObserver)
        }
    }
}
