import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SpeedStore?
    private var mainWindow: MainWindowController?
    private var statusController: StatusItemController?
    private var authorizationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installApplicationMenu()

        let store = SpeedStore()
        self.store = store

        let mainWindow = MainWindowController(store: store)
        self.mainWindow = mainWindow
        let statusController = StatusItemController(store: store, mainWindow: mainWindow)
        statusController.install()
        self.statusController = statusController

        store.start()
        if !store.preferences.onboardingComplete { mainWindow.show(onboarding: true) }

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

    private func installApplicationMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Speeder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu
    }

    @MainActor @objc private func showSettings() { mainWindow?.show(.settings) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow?.show()
        return true
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
