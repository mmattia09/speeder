import Foundation
import Testing
@testable import SpeederCore

struct MenuBarSmootherTests {
    @Test func batchesFiveRates() {
        var smoother = MenuBarSmoother()
        let date = Date(timeIntervalSince1970: 100)
        for value in [20.0, 40, 60, 80] { smoother.record(value, at: date) }
        #expect(smoother.value == 0)
        smoother.record(100, at: date)
        #expect(smoother.value == 60)
        smoother.record(120, at: date)
        #expect(smoother.value == 60)
        smoother.idle(at: date.addingTimeInterval(2))
        #expect(smoother.value == 120)
        smoother.idle(at: date.addingTimeInterval(3))
        #expect(smoother.value == 120)
    }

    @Test func pauseBeforeFirstKeystrokeDoesNotSplitTheFirstBurst() {
        let session = TypingSession()
        let start = Date(timeIntervalSince1970: 100)
        session.breakBurst()
        session.record(.character, at: start)
        session.record(.character, at: start.addingTimeInterval(1))
        #expect(session.historySeries.first?.segment == session.historySeries.last?.segment)
    }

    @Test func pausesSeparateChartSegments() {
        let session = TypingSession()
        let start = Date(timeIntervalSince1970: 100)
        session.record(.character, at: start)
        session.record(.character, at: start.addingTimeInterval(1))
        session.record(.character, at: start.addingTimeInterval(60))
        #expect(session.historySeries.first?.segment != session.historySeries.last?.segment)
        let previous = session.historySeries.last?.segment
        session.breakBurst()
        session.record(.character, at: start.addingTimeInterval(60.1))
        #expect(session.historySeries.last?.segment != previous)
    }
}
