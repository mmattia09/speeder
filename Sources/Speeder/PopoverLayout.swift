import Foundation

/// Leave room for the popover arrow and shadow below the menu-bar anchor.
enum PopoverLayout {
    static func contentSize(visibleFrame: CGRect, anchor: CGRect, idealHeight: CGFloat = 420) -> CGSize {
        CGSize(width: max(1, min(310, visibleFrame.width - 32)),
               height: max(1, min(idealHeight, min(anchor.minY, visibleFrame.maxY) - visibleFrame.minY - 32)))
    }
}
