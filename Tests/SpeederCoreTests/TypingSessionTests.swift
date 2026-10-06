import Foundation
import Testing

@testable import SpeederCore

@Suite("Typing session")
struct TypingSessionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func makeSession() -> TypingSession {
        TypingSession(
            configuration: TypingSessionConfiguration(
                liveWindow: 5,
                pauseThreshold: 1.5,
                historyInterval: 1,
                historyCapacity: 10,
                charactersPerWord: 5,
                minimumMeasurementWindow: 1
            )
        )
    }

    /// Types `words` five-letter words, one keystroke every `interval` seconds.
    @discardableResult
    private func typeWords(
        _ words: Int,
        letters: Int = 5,
        every interval: TimeInterval,
        in session: TypingSession,
        from start: Date
    ) -> Date {
        var now = start
        for _ in 0..<words {
            for _ in 0..<letters {
                now = now.addingTimeInterval(interval)
                session.record(.character, at: now)
            }
            now = now.addingTimeInterval(interval)
            session.record(.separator, at: now)
        }
        return now
    }

    @Test("No stats before the first keystroke")
    func noStatsBeforeTyping() {
        let session = makeSession()
        #expect(session.stats(now: start) == .empty)
        #expect(!session.hasStarted)
        #expect(session.historySeries.isEmpty)
    }

    @Test("Words are counted on separators")
    func wordsAreCountedOnSeparators() {
        let session = makeSession()
        typeWords(2, every: 0.1, in: session, from: start)

        #expect(session.totalWords == 2)
        #expect(session.totalKeystrokes == 12) // 10 characters + 2 spaces
    }

    @Test("Backspace undoes the word in progress")
    func backspaceUndoesTheWordInProgress() {
        let session = makeSession()
        var now = start
        for _ in 0..<3 {
            now = now.addingTimeInterval(0.1)
            session.record(.character, at: now)
        }
        // One backspace still leaves a two-letter word.
        session.record(.deletion, at: now.addingTimeInterval(0.1))
        session.record(.separator, at: now.addingTimeInterval(0.2))
        #expect(session.totalWords == 1)

        now = now.addingTimeInterval(0.2)

        // Backspacing the whole word away means the next space closes nothing.
        for _ in 0..<3 {
            now = now.addingTimeInterval(0.1)
            session.record(.deletion, at: now)
        }
        session.record(.separator, at: now.addingTimeInterval(0.1))
        session.record(.separator, at: now.addingTimeInterval(0.2))
        #expect(session.totalWords == 1)
    }

    @Test("Live rate follows the gross WPM convention")
    func liveRateFollowsGrossWPM() {
        let session = makeSession()
        // 36 keystrokes (6 five-letter words plus their spaces) at one every
        // 0.2s = 300 characters per minute = 60 words per minute.
        let end = typeWords(6, every: 0.2, in: session, from: start)
        let stats = session.stats(now: end)

        #expect(stats.totalWords == 6)
        #expect(abs(stats.currentWPM - 60) < 0.001)
        #expect(abs(stats.peakWPM - 60) < 0.001)
        #expect(abs(stats.burstWPM - 60) < 0.001)
        // 6 words over 7s of typing: the average is a session-wide figure, so it
        // includes the time before the 5 second window starts.
        #expect(abs(stats.averageWPM - 6 / (7 / 60)) < 0.001)
    }

    @Test("The live rate is capped by the sliding window")
    func rateIsCappedByTheLiveWindow() {
        let session = makeSession()
        // 18 seconds of very fast typing: the live rate only sees the last 5.
        let end = typeWords(30, every: 0.05, in: session, from: start)
        let stats = session.stats(now: end)

        // 5s window, 99 keystrokes counted (the window is half-open), 5 seconds.
        #expect(abs(stats.currentWPM - 238) < 2)
        // The session average, however, spans the whole burst.
        #expect(stats.averageWPM < stats.currentWPM)
    }

    @Test("The first keystrokes do not produce absurd rates")
    func firstKeystrokesDoNotProduceAbsurdRates() {
        let session = makeSession()
        // 5 keystrokes in 0.3s: measured over the 1s minimum window, so the rate
        // stays believable instead of jumping to hundreds.
        let end = typeWords(1, every: 0.05, in: session, from: start)

        #expect(abs(session.stats(now: end).currentWPM - 60) < 0.001)
    }

    @Test("The rate freezes after a pause")
    func rateFreezesAfterAPause() {
        let session = makeSession()
        let end = typeWords(6, every: 0.2, in: session, from: start)

        let justAfter = session.stats(now: end.addingTimeInterval(0.5))
        #expect(justAfter.isTyping)
        #expect(abs(justAfter.currentWPM - 60) < 0.001)

        let longAfter = session.stats(now: end.addingTimeInterval(120))
        #expect(!longAfter.isTyping)
        #expect(abs(longAfter.currentWPM - 60) < 0.001)
        // Two minutes of silence do not become two minutes of typing: no keystroke
        // followed the pause, so the average still covers the 7s actually typed.
        #expect(abs(longAfter.averageWPM - 6 / (7 / 60)) < 0.001)
    }

    @Test("The burst resets after a pause, the peak does not")
    func burstResetsAfterAPauseWhileThePeakIsKept() {
        let session = makeSession()
        var now = typeWords(6, every: 0.2, in: session, from: start)
        #expect(abs(session.burstPeak - 60) < 0.001)

        // Long pause, then a slower burst: 12 keystrokes at one every 0.5s.
        now = now.addingTimeInterval(10)
        now = typeWords(2, every: 0.5, in: session, from: now)

        let stats = session.stats(now: now)
        // The window does not reach back past the pause, so the dead time before
        // this burst cannot deflate it.
        #expect(abs(stats.burstWPM - 24) < 0.001)
        #expect(abs(stats.peakWPM - 60) < 0.001)
    }

    @Test("Pauses do not inflate the session average")
    func pausesDoNotInflateTheAverage() {
        let session = makeSession()
        var now = typeWords(6, every: 0.2, in: session, from: start)
        now = now.addingTimeInterval(60) // a long coffee break
        session.record(.character, at: now)

        // 35 gaps of 0.2s while typing, plus at most one pause threshold.
        #expect(abs(session.activeDuration - 8.5) < 0.001)
        #expect(abs(session.stats(now: now).averageWPM - 6 / (8.5 / 60)) < 0.001)
    }

    @Test("History is sampled once per second and bounded")
    func historyIsSampledAndBounded() {
        let session = makeSession()
        let end = typeWords(40, every: 0.1, in: session, from: start)
        let history = session.historySeries

        #expect(history.count == session.configuration.historyCapacity)
        // The last sample is at most one sampling interval behind the last keystroke.
        let lag = abs(history.last?.date.timeIntervalSince(end) ?? .infinity)
        #expect(lag <= session.configuration.historyInterval)
        let spacing = zip(history, history.dropFirst()).map { $1.date.timeIntervalSince($0.date) }
        #expect(spacing.allSatisfy { $0 >= 1 })
    }

    @Test("Reset clears the session")
    func resetClearsEverything() {
        let session = makeSession()
        typeWords(4, every: 0.1, in: session, from: start)
        session.reset()

        #expect(session.stats(now: start.addingTimeInterval(10)) == .empty)
        #expect(session.historySeries.isEmpty)
    }

    @Test("Deletions reduce the live rate")
    func deletionsReduceTheLiveRate() {
        let clean = makeSession()
        let cleanEnd = typeWords(2, every: 0.2, in: clean, from: start)

        let session = makeSession()
        var now = typeWords(2, every: 0.2, in: session, from: start)
        for _ in 0..<5 {
            now = now.addingTimeInterval(0.2)
            session.record(.deletion, at: now)
        }

        let withDeletions = session.stats(now: now).currentWPM
        #expect(withDeletions < clean.stats(now: cleanEnd).currentWPM)
        // 12 keystrokes, 5 of them backspaces, over 3.2s of active time.
        #expect(abs(withDeletions - 30) < 0.001)
    }
    @Test("Incomplete words still update peak and history")
    func incompleteWordUpdatesMetrics() {
        let session = makeSession()
        for i in 0..<10 {
            session.record(.character, at: start.addingTimeInterval(Double(i) * 0.2))
        }
        #expect(session.totalWords == 0)
        #expect(session.sessionPeak > 0)
        #expect(!session.historySeries.isEmpty)
    }

    @Test("Clock changes cannot make active duration negative")
    func clockMovesBackwards() {
        let session = makeSession()
        session.record(.character, at: start)
        session.record(.separator, at: start.addingTimeInterval(-10))
        #expect(session.activeDuration == 0)
        #expect(session.stats(now: start).currentWPM.isFinite)
        #expect(session.lastKeystroke == start)
    }

    @Test("A short first word uses the minimum average window")
    func shortWordAverage() {
        let session = makeSession()
        session.record(.character, at: start)
        session.record(.separator, at: start.addingTimeInterval(0.01))
        #expect(session.stats(now: start.addingTimeInterval(0.01)).averageWPM == 60)
    }

    @Test("Long sessions preserve rates and totals after old events expire")
    func longSession() {
        let session = makeSession()
        let end = typeWords(10_000, every: 0.2, in: session, from: start)
        #expect(session.totalWords == 10_000)
        #expect(session.totalKeystrokes == 60_000)
        #expect(abs(session.stats(now: end).currentWPM - 60) < 3)
        #expect(session.historySeries.count == 10)
    }

}
