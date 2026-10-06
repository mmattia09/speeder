import CoreGraphics
import Foundation
import SpeederCore

/// Classifies raw key events into the subset the metrics engine cares about.
///
/// Printable keys are resolved through the event's unicode string rather than
/// through a fixed keycode map, so the classification holds on any keyboard
/// layout. Only keys that really produce text count as typing; whitespace counts
/// as a word boundary. Shortcuts (⌘/⌥ combinations) and navigation keys are
/// ignored.
enum KeyClassifier {
    static let separatorKeyCodes: Set<Int> = [36, 48, 49, 76] // return, tab, space
    static let deletionKeyCodes: Set<Int> = [51, 117] // backspace, forward delete

    /// Keys that never produce text: escape and navigation keys.
    static let ignoredKeyCodes: Set<Int> = [
        53, // escape
        64, 79, 80, 90, 96, 97, 98, 99, 100, 101, 103, 105,
        106, 107, 109, 111, 113, 118, 120, 122, // F1–F20
        63, // fn
        114, 115, // home, end
        116, 121, // page up, page down
        123, 124, 125, 126, // arrows
    ]

    /// Modifier shortcuts do not count as typing.
    static func classify(_ event: CGEvent) -> TypedCharacter {
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskAlternate) || flags.contains(.maskControl) {
            return .ignored
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        if deletionKeyCodes.contains(keyCode) { return .deletion }
        if separatorKeyCodes.contains(keyCode) { return .separator }
        if ignoredKeyCodes.contains(keyCode) { return .ignored }

        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        buffer.withUnsafeMutableBufferPointer { pointer in
            event.keyboardGetUnicodeString(
                maxStringLength: pointer.count,
                actualStringLength: &length,
                unicodeString: pointer.baseAddress!
            )
        }
        guard length > 0 else { return .ignored }

        var onlyWhitespace = true
        for scalar in String(decoding: buffer.prefix(min(length, buffer.count)), as: UTF16.self).unicodeScalars {
            if scalar.value < 0x20 || scalar.value == 0x7F || (0xF700...0xF8FF).contains(scalar.value) {
                return .ignored // control characters
            }
            if !scalar.properties.isWhitespace {
                onlyWhitespace = false
            }
        }
        return onlyWhitespace ? .separator : .character
    }
}
