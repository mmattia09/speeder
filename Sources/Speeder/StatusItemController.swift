import AppKit
import Combine
import SpeederCapture
import SpeederCore
import SwiftUI

/// Owns the menu-bar item: the animated spider plus the live WPM, and the
/// popover menu with the session details.
@MainActor
final class StatusItemController: NSObject {
    private let store: SpeedStore
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var cancellables = Set<AnyCancellable>()

    init(store: SpeedStore) {
        self.store = store
    }

    func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            statusItem.menu = makeMenu()
            button.toolTip = "Speeder — words per minute"
            button.setAccessibilityLabel("Speeder typing speed")
        }

        store.$stats
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.render() }
            .store(in: &cancellables)

        render()
    }

    // MARK: - Rendering

    private func render() {
        guard let button = statusItem?.button else { return }
        let stats = store.stats

        let spider = SpiderView(
            wpm: stats.currentWPM,
            isTyping: stats.isTyping,
            phase: Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
        )
        .frame(width: 22, height: 18)

        let renderer = ImageRenderer(content: spider)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        if let image = renderer.nsImage {
            image.size = NSSize(width: 22, height: 18)
            image.isTemplate = false
            button.image = image
        }

        let tier = WPMFormatter.Tier.tier(for: stats.currentWPM, isTyping: stats.isTyping)
        button.attributedTitle = NSAttributedString(
            string: " \(WPMFormatter.string(stats.currentWPM))",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: stats.isTyping ? tier.color : NSColor.tertiaryLabelColor,
            ]
        )
        button.toolTip = tooltip(for: stats)
    }

    private func tooltip(for stats: TypingStats) -> String {
        """
        Speeder
        Current: \(WPMFormatter.string(stats.currentWPM)) wpm
        Burst: \(WPMFormatter.string(stats.burstWPM)) wpm
        Average: \(WPMFormatter.string(stats.averageWPM)) wpm
        Peak: \(WPMFormatter.string(stats.peakWPM)) wpm
        \(stats.totalWords) words in \(WPMFormatter.duration(stats.activeDuration))
        """
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        self.menu = menu

        let panelItem = NSMenuItem()
        let hosting = NSHostingView(rootView: StatsPanelView(store: store))
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        panelItem.view = hosting
        menu.addItem(panelItem)

        menu.addItem(.separator())

        let reset = NSMenuItem(title: "Reset Session", action: #selector(resetSession), keyEquivalent: "r")
        reset.target = self
        reset.isEnabled = true
        menu.addItem(reset)

        let copy = NSMenuItem(title: "Copy Stats", action: #selector(copyStats), keyEquivalent: "c")
        copy.target = self
        copy.isEnabled = true
        menu.addItem(copy)

        let settings = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        settings.target = self
        settings.isEnabled = true
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Speeder", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        quit.isEnabled = true
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func resetSession() {
        store.reset()
    }

    @objc private func copyStats() {
        let stats = store.stats
        let summary = """
        Speeder — \(WPMFormatter.string(stats.currentWPM)) wpm now
        Burst \(WPMFormatter.string(stats.burstWPM)) · Average \(WPMFormatter.string(stats.averageWPM)) · Peak \(WPMFormatter.string(stats.peakWPM)) wpm
        \(stats.totalWords) words · \(stats.totalKeystrokes) keystrokes · \(WPMFormatter.duration(stats.activeDuration)) active
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    @objc private func openAccessibilitySettings() {
        KeystrokeMonitor.Authorization.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private extension WPMFormatter.Tier {
    var color: NSColor {
        switch self {
        case .idle: return .tertiaryLabelColor
        case .slow: return .systemBlue
        case .steady: return .systemGreen
        case .brisk: return .systemOrange
        case .fast: return .systemRed
        }
    }
}
