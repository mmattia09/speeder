import AppKit
import Combine
import SpeederCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let store: SpeedStore
    private let mainWindow: MainWindowController
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(store: SpeedStore, mainWindow: MainWindowController) {
        self.store = store
        self.mainWindow = mainWindow
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.setAccessibilityLabel("Speeder typing speed")
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatsPanelView(
            store: store,
            openDashboard: { [weak self] in self?.open(.session) },
            openSettings: { [weak self] in self?.open(.settings) }
        ))
        store.$stats.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        store.preferences.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        render()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    private func open(_ page: AppPage) {
        popover.performClose(nil)
        mainWindow.show(page)
    }

    private func render() {
        guard let button = statusItem?.button else { return }
        let stats = store.stats
        let animate = store.preferences.animateSpider && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let spider = SpiderView(wpm: stats.currentWPM, isTyping: stats.isTyping && !store.isPaused && animate,
                                phase: animate ? Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600) : 0)
            .frame(width: 14, height: 12)
        let renderer = ImageRenderer(content: spider)
        renderer.scale = button.window?.backingScaleFactor ?? 2
        if let image = renderer.nsImage {
            image.size = NSSize(width: 14, height: 12)
            image.isTemplate = true
            button.image = image
        }
        button.imagePosition = store.preferences.showSpeed ? .imageLeading : .imageOnly
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.title = store.preferences.showSpeed ? " \(WPMFormatter.string(stats.currentWPM))" : ""
        button.toolTip = "Speeder · \(WPMFormatter.string(stats.currentWPM)) wpm · \(store.captureLabel)"
    }
}
