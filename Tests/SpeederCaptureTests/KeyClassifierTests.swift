import CoreGraphics
import Testing
import SpeederCore
@testable import SpeederCapture

@Suite("Key classification")
struct KeyClassifierTests {
    private func event(_ code: CGKeyCode, text: String = "", flags: CGEventFlags = []) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
        let units = Array(text.utf16)
        units.withUnsafeBufferPointer {
            event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress)
        }
        event.flags = flags
        return event
    }

    @Test func printableAndUnicode() {
        #expect(KeyClassifier.classify(event(0, text: "a")) == .character)
        #expect(KeyClassifier.classify(event(0, text: "😀")) == .character)
        #expect(KeyClassifier.classify(event(0)) == .ignored)
    }

    @Test func editingKeys() {
        for key: CGKeyCode in [36, 48, 49, 76] {
            #expect(KeyClassifier.classify(event(key)) == .separator)
        }
        for key: CGKeyCode in [51, 117] {
            #expect(KeyClassifier.classify(event(key)) == .deletion)
        }
    }

    @Test func shortcutsAndFunctionKeys() {
        for flags: CGEventFlags in [.maskCommand, .maskAlternate, .maskControl] {
            #expect(KeyClassifier.classify(event(0, text: "a", flags: flags)) == .ignored)
            #expect(KeyClassifier.classify(event(51, flags: flags)) == .ignored)
        }
        for key: CGKeyCode in [53, 123, 122, 120, 111] {
            #expect(KeyClassifier.classify(event(key, text: "\u{F704}")) == .ignored)
        }
    }
}
