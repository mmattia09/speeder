import Foundation

/// Shared presentation helpers for words-per-minute values.
public enum WPMFormatter {
    /// Rounds a rate the way typing tests do: nearest integer.
    public static func rounded(_ wpm: Double) -> Int {
        guard wpm.isFinite, wpm > 0 else { return 0 }
        return Int(wpm.rounded())
    }

    public static func string(_ wpm: Double) -> String {
        "\(rounded(wpm))"
    }

    /// Compact duration used in the detail panel, e.g. `4m 12s`.
    public static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let minutes = total / 60
        let seconds = total % 60
        if minutes == 0 { return "\(seconds)s" }
        if seconds == 0 { return "\(minutes)m" }
        return "\(minutes)m \(seconds)s"
    }

    /// Qualitative tier of a rate, used to colour the spider.
    public enum Tier: Int, Comparable, Sendable {
        case idle
        case slow
        case steady
        case brisk
        case fast

        public static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public static func tier(for wpm: Double, isTyping: Bool) -> Tier {
            guard isTyping || wpm > 0 else { return .idle }
            switch wpm {
            case ..<25: return .slow
            case ..<45: return .steady
            case ..<70: return .brisk
            default: return .fast
            }
        }
    }
}
