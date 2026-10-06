// Note: do not add `import CoreFoundation` here. With the macOS 26 SDK it hides
// the CoreFoundation mach-port API from name lookup. AppKit and CoreGraphics
// already provide every CF type used below.
import AppKit
import CoreGraphics
import Foundation
import SpeederCore
import SpeederShims

/// Global keystroke capture built on a `CGEventTap` session tap.
///
/// Requires the app to be trusted for Accessibility; the app prompts before
/// calling `start()`.
public final class KeystrokeMonitor {
    public init() {}

    deinit { stop() }

    /// Called on the main queue for every key event classified as typing.
    public var onCharacter: ((TypedCharacter) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public enum Authorization {
        public static var isTrusted: Bool { AXIsProcessTrusted() }

        /// Asks the system to show the "grant Accessibility access" prompt.
        @discardableResult
        public static func prompt() -> Bool {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        public static func openSettings() {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            if let url { NSWorkspace.shared.open(url) }
        }
    }

    /// Installs the event tap. Returns `false` when the app is not trusted for
    /// Accessibility or the tap could not be created.
    public func start() -> Bool {
        guard tap == nil else { return true }
        guard Authorization.isTrusted else { return false }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = SpeederCreateRunLoopSourceForMachPort(tap)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    public func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        tap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        case .keyDown:
            let character = KeyClassifier.classify(event)
            guard character != .ignored else { return }
            onCharacter?(character)
        default:
            return
        }
    }
}
