import Foundation

/// A keystroke as seen by the metrics engine.
public enum TypedCharacter: Equatable, Sendable {
    /// A printable character, worth one character towards the WPM count.
    case character
    /// A word boundary (space, return, tab): closes the current word.
    case separator
    /// A deletion (backspace, delete): removes one character from the word being typed.
    case deletion
    /// Anything that does not contribute to typing speed (arrows, shortcuts, dead keys...).
    case ignored
}

/// Tunables for ``TypingSession``. The defaults follow the usual typing-test
/// conventions: 5 characters per word and a 5 second sliding window.
public struct TypingSessionConfiguration: Equatable, Sendable {
    /// Width of the sliding window used for the live WPM.
    public var liveWindow: TimeInterval
    /// Silence longer than this counts as a pause: the live rate freezes and the burst resets.
    public var pauseThreshold: TimeInterval
    /// How often a point is appended to the history series.
    public var historyInterval: TimeInterval
    /// Maximum number of points kept in the history series.
    public var historyCapacity: Int
    /// Characters per word used by the "gross words per minute" convention.
    public var charactersPerWord: Double
    /// Lower bound for the elapsed time of a measurement, so the first keystrokes of a
    /// session cannot produce absurd rates.
    public var minimumMeasurementWindow: TimeInterval

    public init(
        liveWindow: TimeInterval = 5,
        pauseThreshold: TimeInterval = 1.5,
        historyInterval: TimeInterval = 1,
        historyCapacity: Int = 180,
        charactersPerWord: Double = 5,
        minimumMeasurementWindow: TimeInterval = 1
    ) {
        self.liveWindow = liveWindow
        self.pauseThreshold = pauseThreshold
        self.historyInterval = historyInterval
        self.historyCapacity = historyCapacity
        self.charactersPerWord = charactersPerWord
        self.minimumMeasurementWindow = minimumMeasurementWindow
    }
}

/// A single point of the live-WPM series, used to draw the history sparkline.
public struct WPMHistoryPoint: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let wpm: Double
    public let segment: Int

    public init(id: UUID = UUID(), date: Date, wpm: Double, segment: Int = 0) {
        self.id = id
        self.date = date
        self.wpm = wpm
        self.segment = segment
    }
}

/// Everything the menu bar and the detail panel need to render.
public struct TypingStats: Equatable, Sendable {
    /// Live rate, kept frozen until typing resumes.
    public var currentWPM: Double
    /// Best rate reached during the burst currently in progress.
    public var burstWPM: Double
    /// Average over the whole session, pauses excluded.
    public var averageWPM: Double
    /// Best rate ever reached in this session.
    public var peakWPM: Double
    public var totalKeystrokes: Int
    public var totalWords: Int
    /// Time spent actually typing: gaps longer than the pause threshold count as
    /// one threshold only.
    public var activeDuration: TimeInterval
    public var isTyping: Bool
    public var lastKeystroke: Date?

    public init(
        currentWPM: Double = 0,
        burstWPM: Double = 0,
        averageWPM: Double = 0,
        peakWPM: Double = 0,
        totalKeystrokes: Int = 0,
        totalWords: Int = 0,
        activeDuration: TimeInterval = 0,
        isTyping: Bool = false,
        lastKeystroke: Date? = nil
    ) {
        self.currentWPM = currentWPM
        self.burstWPM = burstWPM
        self.averageWPM = averageWPM
        self.peakWPM = peakWPM
        self.totalKeystrokes = totalKeystrokes
        self.totalWords = totalWords
        self.activeDuration = activeDuration
        self.isTyping = isTyping
        self.lastKeystroke = lastKeystroke
    }

    public static let empty = TypingStats()
}

/// Accumulates keystrokes and derives typing speeds from them.
///
/// A word is completed when a separator follows at least one character, so
/// backspaces undo the word being typed instead of inflating the count.
public final class TypingSession {
    private struct Event {
        let at: Date
        let delta: Double
    }

    public let configuration: TypingSessionConfiguration

    private var events: [Event] = []
    private var cumulativeDeltas: [Double] = [0]
    private var history: [WPMHistoryPoint] = []
    private var lastHistoryDate: Date?
    private var runningWordLength = 0

    public private(set) var totalKeystrokes: Int = 0
    public private(set) var totalWords: Int = 0
    public private(set) var activeDuration: TimeInterval = 0
    public private(set) var burstPeak: Double = 0
    public private(set) var sessionPeak: Double = 0
    public private(set) var sessionStart: Date?
    public private(set) var lastKeystroke: Date?

    /// First keystroke of the run in progress: the live window never reaches back
    /// past it, so a pause does not drag dead time into the rate.
    private var burstStart: Date?
    private var segment = 0
    private var forceNewBurst = false

    public init(configuration: TypingSessionConfiguration = TypingSessionConfiguration()) {
        precondition(configuration.liveWindow.isFinite && configuration.liveWindow > 0)
        precondition(configuration.pauseThreshold.isFinite && configuration.pauseThreshold > 0)
        precondition(configuration.historyInterval.isFinite && configuration.historyInterval > 0)
        precondition(configuration.historyCapacity > 0)
        precondition(configuration.charactersPerWord.isFinite && configuration.charactersPerWord > 0)
        precondition(configuration.minimumMeasurementWindow.isFinite && configuration.minimumMeasurementWindow > 0)
        self.configuration = configuration
    }

    public var historySeries: [WPMHistoryPoint] { history }

    public var hasStarted: Bool { sessionStart != nil }

    /// Records one keystroke. `character` decides what it means for the metrics.
    public func record(_ character: TypedCharacter, at date: Date = Date()) {
        guard character != .ignored else { return }

        // Keep the sorted event buffer valid if the system clock moves backwards.
        let date = max(date, lastKeystroke ?? date)
        if let previous = lastKeystroke {
            let gap = date.timeIntervalSince(previous)
            if gap > configuration.pauseThreshold || forceNewBurst {
                segment += 1
                lastHistoryDate = nil
                forceNewBurst = false
                burstPeak = 0
                burstStart = date
            }
            activeDuration += min(gap, configuration.pauseThreshold)
        } else {
            forceNewBurst = false
            sessionStart = date
            burstStart = date
        }

        lastKeystroke = date
        totalKeystrokes += 1

        switch character {
        case .character:
            appendEvent(at: date, delta: 1)
            runningWordLength += 1
        case .separator:
            // The space itself is typed, so it counts towards the characters per
            // minute; it also closes the word.
            appendEvent(at: date, delta: 1)
            if runningWordLength > 0 {
                totalWords += 1
                runningWordLength = 0
            }
        case .deletion:
            appendEvent(at: date, delta: -1)
            runningWordLength = max(0, runningWordLength - 1)
        case .ignored:
            break
        }

        let rate = currentRate(at: date)
        burstPeak = max(burstPeak, rate)
        sessionPeak = max(sessionPeak, rate)
        appendHistoryPoint(rate, at: date)
    }

    public func stats(now: Date = Date()) -> TypingStats {
        let evaluationDate = min(now, lastKeystroke ?? now)
        let current = currentRate(at: evaluationDate)
        let average = activeDuration > 0
            ? Double(totalWords) / (max(activeDuration, configuration.minimumMeasurementWindow) / 60)
            : 0

        let idle = lastKeystroke.map { now.timeIntervalSince($0) } ?? .infinity
        return TypingStats(
            currentWPM: current,
            burstWPM: burstPeak,
            averageWPM: average,
            peakWPM: sessionPeak,
            totalKeystrokes: totalKeystrokes,
            totalWords: totalWords,
            activeDuration: activeDuration,
            isTyping: idle <= configuration.pauseThreshold,
            lastKeystroke: lastKeystroke
        )
    }

    public func breakBurst() {
        forceNewBurst = true
        runningWordLength = 0
    }

    public func reset() {
        events.removeAll(keepingCapacity: true)
        cumulativeDeltas = [0]
        history.removeAll(keepingCapacity: true)
        lastHistoryDate = nil
        runningWordLength = 0
        totalKeystrokes = 0
        totalWords = 0
        activeDuration = 0
        burstPeak = 0
        sessionPeak = 0
        sessionStart = nil
        lastKeystroke = nil
        burstStart = nil
        segment = 0
        forceNewBurst = false
    }

    private func appendEvent(at date: Date, delta: Double) {
        // Only the live window is needed; session totals are stored separately.
        let obsolete = firstIndex(atOrAfter: date.addingTimeInterval(-configuration.liveWindow))
        if obsolete > 0 {
            events.removeFirst(obsolete)
            cumulativeDeltas = [0]
            for event in events {
                cumulativeDeltas.append(cumulativeDeltas.last! + event.delta)
            }
        }
        events.append(Event(at: date, delta: delta))
        cumulativeDeltas.append((cumulativeDeltas.last ?? 0) + delta)
    }

    private func appendHistoryPoint(_ wpm: Double, at date: Date) {
        if let last = lastHistoryDate, date.timeIntervalSince(last) < configuration.historyInterval {
            return
        }
        lastHistoryDate = date
        history.append(WPMHistoryPoint(date: date, wpm: wpm, segment: segment))
        if history.count > configuration.historyCapacity {
            history.removeFirst(history.count - configuration.historyCapacity)
        }
    }

    /// Gross words per minute over the trailing live window, evaluated at `date`.
    private func currentRate(at date: Date) -> Double {
        guard let start = sessionStart, start <= date else { return 0 }
        let anchor = max(start, burstStart ?? start)
        let windowStart = max(anchor, date.addingTimeInterval(-configuration.liveWindow))
        let characters = characterDelta(from: windowStart, to: date)
        guard characters > 0 else { return 0 }

        let elapsed = max(date.timeIntervalSince(windowStart), configuration.minimumMeasurementWindow)
        return (characters / configuration.charactersPerWord) / (elapsed / 60)
    }

    /// Net characters (typed minus deleted) in the half-open interval `start..<end`.
    private func characterDelta(from start: Date, to end: Date) -> Double {
        let lower = firstIndex(atOrAfter: start)
        let upper = firstIndex(atOrAfter: end)
        guard lower < upper else { return 0 }
        let delta = cumulativeDeltas[upper] - cumulativeDeltas[lower]
        return max(0, delta)
    }

    private func firstIndex(atOrAfter date: Date) -> Int {
        var low = 0
        var high = events.count
        while low < high {
            let mid = (low + high) / 2
            if events[mid].at < date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
