import Foundation
import Testing
import SpeederCore
@testable import Speeder

struct StatisticsTests {
    @Test func persistenceAndCompleteExports() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("stats.sqlite")
        var archive: StatisticsArchive? = try StatisticsArchive(url: url)
        archive?.record(at: Date(timeIntervalSince1970: 120), words: 2, keystrokes: 12, activeSeconds: 2, peak: 80, sample: 60)
        archive?.record(at: Date(timeIntervalSince1970: 130), words: 1, keystrokes: 6, activeSeconds: 1, peak: 50, sample: 40)
        #expect(try archive?.rows().first?.words == 3)
        try archive?.flush()
        try archive?.flush() // Must not count the same deltas twice.
        archive = nil
        let restored = try StatisticsArchive(url: url)
        restored.record(at: Date(timeIntervalSince1970: 150), words: 1, keystrokes: 5, activeSeconds: 1, peak: 90, sample: nil)
        try restored.flush()
        let rows = try restored.rows()
        #expect(rows.count == 1)
        #expect(rows[0].words == 4)
        #expect(rows[0].keystrokes == 23)
        #expect(rows[0].activeSeconds == 4)
        #expect(rows[0].peakWPM == 90)
        #expect(rows[0].rateSum == 100)
        #expect(rows[0].samples == 2)
        struct Export: Decodable { let schemaVersion: Int; let minutes: [ActivityMinute] }
        let decoded = try JSONDecoder().decode(Export.self, from: restored.export(csv: false))
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.minutes == rows)
        let csv = String(data: try restored.export(csv: true), encoding: .utf8)!
        #expect(csv.contains("1970-01-01T00:02:00Z,4,23,4.0,90.0,100.0,2"))
    }

    @Test func corruptDatabaseIsNotOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("stats.sqlite")
        let badData = Data("not a sqlite database".utf8)
        try badData.write(to: url)
        #expect(throws: (any Error).self) { _ = try StatisticsArchive(url: url) }
        #expect(try Data(contentsOf: url) == badData)
    }

    @Test func dailyAverageUsesTotalActiveTime() {
        let rows = [ActivityMinute(minute: 120, words: 60, activeSeconds: 60), ActivityMinute(minute: 180, words: 10, activeSeconds: 30)]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let days = DailyActivity.aggregate(rows, calendar: calendar)
        #expect(days.count == 1)
        #expect(abs(days[0].total.averageWPM - 70.0 * 60 / 90) < 0.001)
    }

    @Test func chartCompressesPausesWithoutJoiningBursts() {
        let points = [WPMHistoryPoint(date: Date(timeIntervalSince1970: 0), wpm: 30),
                      WPMHistoryPoint(date: Date(timeIntervalSince1970: 1), wpm: 60),
                      WPMHistoryPoint(date: Date(timeIntervalSince1970: 600), wpm: 40, segment: 1)]
        let samples = ChartTimeline.samples(points)
        #expect(samples.last?.x == 2.5)
        #expect(samples[1].series != samples[2].series)
        #expect(ChartTimeline.nearest(to: 1, in: samples)?.point.wpm == 60)
        #expect(ChartTimeline.nearest(to: 1.7, in: samples) == nil)
        #expect(ChartTimeline.nearest(to: -1, in: samples) == nil)
    }

    @Test @MainActor func resettingSessionKeepsLongTermHistory() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = try StatisticsArchive(url: folder.appendingPathComponent("stats.sqlite"))
        let store = SpeedStore(archive: archive)
        store.handle(.character)
        store.handle(.separator)
        store.reset()
        #expect(store.stats == .empty)
        #expect(try archive.rows().reduce(0) { $0 + $1.words } == 1)
        #expect(try archive.rows().reduce(0) { $0 + $1.keystrokes } == 2)
        store.handle(.character)
        store.stop()
        #expect(try archive.rows().reduce(0) { $0 + $1.keystrokes } == 3)
    }
}
