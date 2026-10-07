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
        store.$stats.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        store.preferences.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        render()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            guard let window = button.window, let screen = window.screen else { return }
            let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
            let width = PopoverLayout.contentSize(visibleFrame: screen.visibleFrame, anchor: anchor).width
            let panel = ThemeView(preferences: store.preferences) {
                StatsPanelView(store: store,
                               openDashboard: { [weak self] in self?.open(.statistics) },
                               openSettings: { [weak self] in self?.open(.settings) }, width: width)
            }
            let measuringView = NSHostingView(rootView: panel)
            let size = PopoverLayout.contentSize(visibleFrame: screen.visibleFrame, anchor: anchor,
                                                 idealHeight: ceil(measuringView.fittingSize.height))
            let content = ScrollView(.vertical) { panel }
                .frame(width: size.width, height: size.height)
            let hosting = NSHostingController(rootView: content)
            // SwiftUI's unconstrained ideal size must not resize the popover.
            hosting.sizingOptions = []
            hosting.preferredContentSize = size
            popover.contentViewController = hosting
            popover.contentSize = size
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    #if DEBUG
    /// Exercise AppKit's actual anchoring in the preview smoke check.
    func validatePopoverBounds() throws {
        // AppKit assigns the status item to its screen on the next run-loop turn.
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        togglePopover()
        defer { popover.performClose(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard let frame = popover.contentViewController?.view.window?.frame,
              let screen = statusItem?.button?.window?.screen,
              screen.frame.contains(frame) else {
            throw NSError(domain: "Speeder.Popover", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Popover is missing or extends beyond its screen"])
        }
        print("Popover fits screen: \(frame)")
    }
    #endif

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
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        button.title = store.preferences.showSpeed ? " \(WPMFormatter.string(store.menuBarWPM))" : ""
        button.toolTip = "Speeder · \(WPMFormatter.string(stats.currentWPM)) wpm · \(store.captureLabel)"
    }
}
