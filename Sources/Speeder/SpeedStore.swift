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

    private let session: TypingSession
    private let monitor: KeystrokeMonitor
    private var timer: Timer?
    private var lastAuthorizationCheck = Date.distantPast

    init(
        session: TypingSession = TypingSession(),
        monitor: KeystrokeMonitor = KeystrokeMonitor()
    ) {
        self.session = session
        self.monitor = monitor

        monitor.onCharacter = { [weak self] character in
            Task { @MainActor in self?.handle(character) }
        }
    }

    func start() {
        startTimer()
        isAuthorized = KeystrokeMonitor.Authorization.prompt()
        isMonitoring = isAuthorized && monitor.start()
        refresh()
    }

    /// Called when the app becomes active: the user may have just granted
    /// Accessibility access in System Settings.
    func refreshAuthorization() {
        let wasAuthorized = isAuthorized
        isAuthorized = KeystrokeMonitor.Authorization.isTrusted
        guard isAuthorized else {
            monitor.stop()
            isMonitoring = false
            return
        }
        guard !wasAuthorized || !isMonitoring else { return }
        isMonitoring = monitor.start()
    }

    func handle(_ character: TypedCharacter) {
        session.record(character)
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
        stats = session.stats()
        history = session.historySeries
    }
}
