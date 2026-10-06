import AppKit
import Combine
import Foundation
import SpeederCapture
import SpeederCore

/// Owns the typing session and republishes a snapshot on every tick.
@MainActor
final class SpeedStore: ObservableObject {
    @Published private(set) var stats: TypingStats = .empty
    @Published private(set) var history: [WPMHistoryPoint] = []
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var isMonitoring: Bool = false

    @Published private(set) var isPaused = false
    let preferences: AppPreferences

    private let session: TypingSession
    private let monitor: KeystrokeMonitor
    private var timer: Timer?
    private var lastAuthorizationCheck = Date.distantPast

    init(
        session: TypingSession = TypingSession(),
        monitor: KeystrokeMonitor = KeystrokeMonitor(),
        preferences: AppPreferences? = nil
    ) {
        self.preferences = preferences ?? AppPreferences()
        self.session = session
        self.monitor = monitor

        monitor.onCharacter = { [weak self] character in
            Task { @MainActor in self?.handle(character) }
        }
    }

    func start() {
        startTimer()
        isAuthorized = KeystrokeMonitor.Authorization.isTrusted
        isMonitoring = isAuthorized && monitor.start()
        refresh()
    }

    /// Called when the app becomes active: the user may have just granted
    /// Accessibility access in System Settings.
    func refreshAuthorization() {
        let wasAuthorized = isAuthorized
        isAuthorized = KeystrokeMonitor.Authorization.isTrusted
        guard isAuthorized, !isPaused else {
            monitor.stop()
            isMonitoring = false
            return
        }
        guard !wasAuthorized || !isMonitoring else { return }
        isMonitoring = monitor.start()
    }

    func handle(_ character: TypedCharacter) {
        guard !isPaused else { return }
        session.record(character)
    }

    var captureLabel: String {
        if isPaused { return "Tracking paused" }
        if !isAuthorized { return "Permission needed" }
        if !isMonitoring { return "Capture unavailable" }
        return stats.isTyping ? "Typing now" : "Ready when you are"
    }

    func togglePaused() {
        isPaused.toggle()
        refreshAuthorization()
        refresh()
    }

    func requestAccess() {
        _ = KeystrokeMonitor.Authorization.prompt()
        KeystrokeMonitor.Authorization.openSettings()
    }

    func copyStats() {
        let summary = "Speeder · Current \(WPMFormatter.string(stats.currentWPM)) WPM · Average \(WPMFormatter.string(stats.averageWPM)) · Peak \(WPMFormatter.string(stats.peakWPM)) · \(stats.totalWords) words · \(WPMFormatter.duration(stats.activeDuration)) active"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    func reset() {
        session.reset()
        refresh()
    }

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        monitor.stop()
        isMonitoring = false
    }

    private func refresh() {
        // Menu-bar apps may never become active after System Settings closes.
        if Date().timeIntervalSince(lastAuthorizationCheck) >= 2 {
            lastAuthorizationCheck = Date()
            refreshAuthorization()
        }
        updateSnapshot()
    }

    func updateSnapshot() {
        stats = session.stats()
        history = session.historySeries
    }
}
