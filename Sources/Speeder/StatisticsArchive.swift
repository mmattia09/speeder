import Foundation
import SQLite3

struct ActivityMinute: Codable, Identifiable, Equatable {
    var minute: Int64
    var words = 0
    var keystrokes = 0
    var activeSeconds: Double = 0
    var peakWPM: Double = 0
    var rateSum: Double = 0
    var samples = 0
    var id: Int64 { minute }
    var date: Date { Date(timeIntervalSince1970: Double(minute)) }
    var averageWPM: Double { activeSeconds > 0 ? Double(words) * 60 / max(activeSeconds, 1) : 0 }

    mutating func merge(_ other: ActivityMinute) {
        words += other.words; keystrokes += other.keystrokes
        activeSeconds += other.activeSeconds
        peakWPM = max(peakWPM, other.peakWPM)
        rateSum += other.rateSum; samples += other.samples
    }
}

/// Numeric minute aggregates only. Pending increments are committed atomically.
final class StatisticsArchive {
    private var database: OpaquePointer?
    private var pending: [Int64: ActivityMinute] = [:]

    var hasPendingChanges: Bool { !pending.isEmpty }

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Speeder/statistics.sqlite")
    }

    init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &database) == SQLITE_OK else {
            let error = failure()
            sqlite3_close(database)
            database = nil
            throw error
        }
        do {
            sqlite3_busy_timeout(database, 2000)
            try execute("PRAGMA journal_mode=WAL")
            try execute("CREATE TABLE IF NOT EXISTS minutes (minute INTEGER PRIMARY KEY, words INTEGER NOT NULL, keystrokes INTEGER NOT NULL, active_seconds REAL NOT NULL, peak_wpm REAL NOT NULL, rate_sum REAL NOT NULL, samples INTEGER NOT NULL)")
        } catch { sqlite3_close(database); database = nil; throw error }
    }

    deinit { sqlite3_close(database) }

    func record(at date: Date, words: Int, keystrokes: Int, activeSeconds: Double, peak: Double, sample: Double?) {
        let minute = Int64(floor(date.timeIntervalSince1970 / 60) * 60)
        var row = pending[minute] ?? ActivityMinute(minute: minute)
        row.merge(ActivityMinute(minute: minute, words: words, keystrokes: keystrokes,
                                 activeSeconds: activeSeconds, peakWPM: peak,
                                 rateSum: sample ?? 0, samples: sample == nil ? 0 : 1))
        pending[minute] = row
    }

    func flush() throws {
        guard !pending.isEmpty else { return }
        try execute("BEGIN IMMEDIATE")
        do {
            let sql = """
            INSERT INTO minutes VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(minute) DO UPDATE SET
              words=words+excluded.words, keystrokes=keystrokes+excluded.keystrokes,
              active_seconds=active_seconds+excluded.active_seconds,
              peak_wpm=MAX(peak_wpm,excluded.peak_wpm),
              rate_sum=rate_sum+excluded.rate_sum, samples=samples+excluded.samples
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
            defer { sqlite3_finalize(statement) }
            for row in pending.values {
                sqlite3_bind_int64(statement, 1, row.minute)
                sqlite3_bind_int64(statement, 2, Int64(row.words))
                sqlite3_bind_int64(statement, 3, Int64(row.keystrokes))
                sqlite3_bind_double(statement, 4, row.activeSeconds)
                sqlite3_bind_double(statement, 5, row.peakWPM)
                sqlite3_bind_double(statement, 6, row.rateSum)
                sqlite3_bind_int64(statement, 7, Int64(row.samples))
                guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
                sqlite3_reset(statement)
            }
            try execute("COMMIT")
            pending.removeAll()
        } catch { try? execute("ROLLBACK"); throw error }
    }

    func rows() throws -> [ActivityMinute] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT * FROM minutes ORDER BY minute", -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        var result: [Int64: ActivityMinute] = [:]
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            let minute = sqlite3_column_int64(statement, 0)
            result[minute] = ActivityMinute(minute: minute, words: Int(sqlite3_column_int64(statement, 1)),
                keystrokes: Int(sqlite3_column_int64(statement, 2)), activeSeconds: sqlite3_column_double(statement, 3),
                peakWPM: sqlite3_column_double(statement, 4), rateSum: sqlite3_column_double(statement, 5),
                samples: Int(sqlite3_column_int64(statement, 6)))
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw failure() }
        for row in pending.values {
            var merged = result[row.minute] ?? ActivityMinute(minute: row.minute)
            merged.merge(row); result[row.minute] = merged
        }
        return result.values.sorted { $0.minute < $1.minute }
    }

    func export(csv: Bool) throws -> Data {
        let values = try rows()
        if csv {
            let formatter = ISO8601DateFormatter()
            let header = "minute_utc,words,keystrokes,active_seconds,peak_wpm,rate_sum,samples\n"
            let lines = values.map { "\(formatter.string(from: $0.date)),\($0.words),\($0.keystrokes),\($0.activeSeconds),\($0.peakWPM),\($0.rateSum),\($0.samples)" }
            return Data((header + lines.joined(separator: "\n") + "\n").utf8)
        }
        struct Export: Encodable { let schemaVersion = 1; let resolution = "one minute"; let timestampUnit = "Unix seconds (UTC)"; let minutes: [ActivityMinute] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Export(minutes: values))
    }

    struct ImportResult { let added: Int; let skipped: Int }

    func importData(_ data: Data, csv: Bool) throws -> ImportResult {
        func invalid() -> NSError {
            NSError(domain: "Speeder.Import", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Invalid statistics file.")])
        }
        let values: [ActivityMinute]
        if csv {
            guard let text = String(data: data, encoding: .utf8) else { throw invalid() }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            guard lines.first == "minute_utc,words,keystrokes,active_seconds,peak_wpm,rate_sum,samples" else { throw invalid() }
            let formatter = ISO8601DateFormatter()
            values = try lines.dropFirst().map { line in
                let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
                guard fields.count == 7, let date = formatter.date(from: fields[0]),
                      date.timeIntervalSince1970 >= 0, date.timeIntervalSince1970 < 253402300800,
                      let words = Int(fields[1]), let keys = Int(fields[2]), let active = Double(fields[3]),
                      let peak = Double(fields[4]), let rate = Double(fields[5]), let samples = Int(fields[6]) else { throw invalid() }
                return ActivityMinute(minute: Int64(date.timeIntervalSince1970), words: words, keystrokes: keys,
                                      activeSeconds: active, peakWPM: peak, rateSum: rate, samples: samples)
            }
        } else {
            struct Document: Decodable { let schemaVersion: Int; let minutes: [ActivityMinute] }
            let document = try JSONDecoder().decode(Document.self, from: data)
            guard document.schemaVersion == 1 else { throw invalid() }
            values = document.minutes
        }
        var seen = Set<Int64>()
        for row in values {
            guard row.minute >= 0, row.minute < 253402300800, row.minute % 60 == 0,
                  seen.insert(row.minute).inserted,
                  [row.words, row.keystrokes, row.samples].allSatisfy({ $0 >= 0 && $0 <= 1_000_000_000 }),
                  [row.activeSeconds, row.peakWPM, row.rateSum].allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1_000_000_000 }) else { throw invalid() }
        }
        try flush()
        try execute("BEGIN IMMEDIATE")
        do {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "INSERT OR IGNORE INTO minutes VALUES (?, ?, ?, ?, ?, ?, ?)", -1, &statement, nil) == SQLITE_OK else { throw failure() }
            defer { sqlite3_finalize(statement) }
            var added = 0
            for row in values {
                sqlite3_bind_int64(statement, 1, row.minute)
                sqlite3_bind_int64(statement, 2, Int64(row.words))
                sqlite3_bind_int64(statement, 3, Int64(row.keystrokes))
                sqlite3_bind_double(statement, 4, row.activeSeconds)
                sqlite3_bind_double(statement, 5, row.peakWPM)
                sqlite3_bind_double(statement, 6, row.rateSum)
                sqlite3_bind_int64(statement, 7, Int64(row.samples))
                guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
                added += Int(sqlite3_changes(database))
                sqlite3_reset(statement)
            }
            try execute("COMMIT")
            return ImportResult(added: added, skipped: values.count - added)
        } catch { try? execute("ROLLBACK"); throw error }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    private func failure() -> NSError {
        NSError(domain: "Speeder.Archive", code: Int(sqlite3_errcode(database)),
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
}
