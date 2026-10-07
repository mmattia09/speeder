import Foundation
import Testing
@testable import Speeder

@Suite("Popover screen bounds")
struct PopoverLayoutTests {
    @Test func standardDisplay() {
        let size = PopoverLayout.contentSize(visibleFrame: CGRect(x: 0, y: 30, width: 1440, height: 850),
                                             anchor: CGRect(x: 1400, y: 880, width: 40, height: 24))
        #expect(size == CGSize(width: 310, height: 420))
    }

    @Test func smallDisplayLeavesRoomForChrome() {
        let frame = CGRect(x: 0, y: 40, width: 300, height: 340)
        let anchor = CGRect(x: 260, y: 380, width: 40, height: 24)
        let size = PopoverLayout.contentSize(visibleFrame: frame, anchor: anchor)
        #expect(size.width + 32 <= frame.width)
        #expect(size.height + 32 <= anchor.minY - frame.minY)
    }

    @Test func secondaryDisplayUsesItsOwnCoordinates() {
        let frame = CGRect(x: -1920, y: -1080, width: 1920, height: 1056)
        let anchor = CGRect(x: -100, y: -24, width: 40, height: 24)
        #expect(PopoverLayout.contentSize(visibleFrame: frame, anchor: anchor) == CGSize(width: 310, height: 420))
    }
}
