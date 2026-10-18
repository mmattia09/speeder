import Foundation
import Testing
@testable import Speeder

struct StatisticsImportTests {
    @Test(arguments: [false, true]) func roundTripAndDuplicateImport(csv: Bool) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try StatisticsArchive(url: folder.appendingPathComponent("source.sqlite"))
        source.record(at: Date(timeIntervalSince1970: 120), words: 3, keystrokes: 18, activeSeconds: 6, peak: 80, sample: 60)
        source.record(at: Date(timeIntervalSince1970: 180), words: 2, keystrokes: 12, activeSeconds: 5, peak: 70, sample: 50)
        let target = try StatisticsArchive(url: folder.appendingPathComponent("target.sqlite"))
        let data = try source.export(csv: csv)
        let first = try target.importData(data, csv: csv)
        #expect(first.added == 2)
        #expect(try target.rows() == source.rows())
        let second = try target.importData(data, csv: csv)
        #expect(second.added == 0 && second.skipped == 2)
        #expect(try target.rows() == source.rows())
        // Pending local activity wins over overlapping imported minutes.
        target.record(at: Date(timeIntervalSince1970: 120), words: 1, keystrokes: 5, activeSeconds: 1, peak: 90, sample: nil)
        _ = try target.importData(data, csv: csv)
        #expect(try target.rows().first?.words == 4)
    }

    @Test func invalidImportDoesNotPartiallyWrite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = try StatisticsArchive(url: folder.appendingPathComponent("stats.sqlite"))
        archive.record(at: Date(timeIntervalSince1970: 60), words: 1, keystrokes: 5, activeSeconds: 1, peak: 50, sample: nil)
        let before = try archive.rows()
        let header = "minute_utc,words,keystrokes,active_seconds,peak_wpm,rate_sum,samples\n"
        for bad in ["1970-01-01T00:03:00Z,-2,4,5,20,20,1", "1970-01-01T00:03:00Z,2,4,nan,20,20,1", "invalid"] {
            let data = Data((header + "1970-01-01T00:02:00Z,2,4,5,20,20,1\n" + bad).utf8)
            #expect(throws: (any Error).self) { try archive.importData(data, csv: true) }
            #expect(try archive.rows() == before)
        }
        #expect(throws: (any Error).self) { try archive.importData(Data("{\"schemaVersion\":2,\"minutes\":[]}".utf8), csv: false) }
        #expect(try archive.rows() == before)
    }
}
