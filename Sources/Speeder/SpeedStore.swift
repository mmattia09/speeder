import AppKit
import Combine
import Foundation
import SpeederCapture
import SpeederCore
import UniformTypeIdentifiers

/// Owns the typing session and republishes a snapshot on every tick.
@MainActor
final class SpeedStore: ObservableObject {
    @Published private(set) var stats: TypingStats = .empty
    @Published private(set) var history: [WPMHistoryPoint] = []
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var isMonitoring: Bool = false

    @Published private(set) var isPaused = false
    let preferences: AppPreferences

    @Published private(set) var menuBarWPM: Double = 0
    @Published private(set) var archiveRows: [ActivityMinute] = []
    @Published var storageError: String?
    @Published var exportMessage: String?
    private let archive: StatisticsArchive?
    private var smoother = MenuBarSmoother()
    private var lastSave = Date()

    private let session: TypingSession
    private let monitor: KeystrokeMonitor
    private var timer: Timer?
    private var lastAuthorizationCheck = Date.distantPast

    init(
        session: TypingSession = TypingSession(),
        monitor: KeystrokeMonitor = KeystrokeMonitor(),
        preferences: AppPreferences? = nil,
        archive: StatisticsArchive? = nil
    ) {
        self.archive = archive
        self.preferences = preferences ?? AppPreferences()
        self.session = session
        self.monitor = monitor
        do { archiveRows = try archive?.rows() ?? [] } catch { storageError = error.localizedDescription }

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
        guard !isPaused, character != .ignored else { return }
        let date = Date()
        let oldWords = session.totalWords
        let oldDuration = session.activeDuration
        let oldSample = session.historySeries.last?.id
        session.record(character, at: date)
        let current = session.stats(now: date)
        smoother.record(current.currentWPM, at: date)
        menuBarWPM = smoother.value
        let point = session.historySeries.last
        archive?.record(at: date, words: session.totalWords - oldWords, keystrokes: 1,
                        activeSeconds: session.activeDuration - oldDuration, peak: current.currentWPM,
                        sample: point?.id != oldSample ? point?.wpm : nil)
    }

    var captureLabel: String {
        if isPaused { return "Tracking paused" }
        if !isAuthorized { return "Permission needed" }
        if !isMonitoring { return "Capture unavailable" }
        return stats.isTyping ? "Typing now" : "Ready when you are"
    }

    func togglePaused() {
        isPaused.toggle()
        session.breakBurst()
        smoother.flush()
        menuBarWPM = smoother.value
        saveArchive()
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
        saveArchive()
        session.reset()
        smoother = MenuBarSmoother()
        menuBarWPM = 0
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

    func saveArchive() {
        guard let archive else { return }
        lastSave = Date()
        guard archive.hasPendingChanges || storageError != nil else { return }
        do {
            try archive.flush()
            archiveRows = try archive.rows()
            storageError = nil
        } catch { storageError = "History could not be saved: \(error.localizedDescription)" }
    }

    func exportAll(csv: Bool) {
        guard let archive else { exportMessage = "The history database is unavailable."; return }
        saveArchive()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [csv ? .commaSeparatedText : .json]
        panel.nameFieldStringValue = "Speeder-history.\(csv ? "csv" : "json")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try archive.export(csv: csv).write(to: url, options: .atomic)
            exportMessage = "All recorded minute summaries were exported to \(url.lastPathComponent)."
        } catch { exportMessage = "Export failed: \(error.localizedDescription)" }
    }

    func stop() {
        saveArchive()
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
        if Date().timeIntervalSince(lastSave) >= 10 { saveArchive() }
        smoother.idle(at: Date())
        menuBarWPM = smoother.value
        updateSnapshot()
    }

    func updateSnapshot() {
        stats = session.stats()
        history = session.historySeries
    }
}
