import Foundation
import Testing

@testable import SpeederCore

@Suite("WPM formatting")
struct WPMFormatterTests {
    @Test("Rounding")
    func rounding() {
        #expect(WPMFormatter.string(0) == "0")
        #expect(WPMFormatter.string(59.4) == "59")
        #expect(WPMFormatter.string(59.5) == "60")
        #expect(WPMFormatter.string(-3) == "0")
        #expect(WPMFormatter.string(.nan) == "0")
    }

    @Test("Duration")
    func duration() {
        #expect(WPMFormatter.duration(0) == "0s")
        #expect(WPMFormatter.duration(42) == "42s")
        #expect(WPMFormatter.duration(60) == "1m")
        #expect(WPMFormatter.duration(252) == "4m 12s")
        #expect(WPMFormatter.duration(3600) == "1h")
        #expect(WPMFormatter.duration(50000) == "13h 53m")
    }

    @Test("Tiers")
    func tiers() {
        #expect(WPMFormatter.Tier.tier(for: 0, isTyping: false) == .idle)
        #expect(WPMFormatter.Tier.tier(for: 10, isTyping: true) == .slow)
        #expect(WPMFormatter.Tier.tier(for: 30, isTyping: true) == .steady)
        #expect(WPMFormatter.Tier.tier(for: 50, isTyping: true) == .brisk)
        #expect(WPMFormatter.Tier.tier(for: 90, isTyping: true) == .fast)
        // A frozen rate from just before the pause still shows its own tier.
        #expect(WPMFormatter.Tier.tier(for: 90, isTyping: false) == .fast)
    }
}
