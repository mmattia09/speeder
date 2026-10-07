import AppKit
import SwiftUI

private struct SpeederAccentKey: EnvironmentKey {
    static let defaultValue = Color(red: 0.12, green: 0.62, blue: 0.49)
}

extension EnvironmentValues {
    var speederAccent: Color {
        get { self[SpeederAccentKey.self] }
        set { self[SpeederAccentKey.self] = newValue }
    }
}

struct ThemeView<Content: View>: View {
    @ObservedObject var preferences: AppPreferences
    @ViewBuilder var content: Content
    var body: some View { content.environment(\.speederAccent, preferences.accent).tint(preferences.accent) }
}

extension AppPreferences {
    var accent: Color {
        let value = UInt32(accentHex, radix: 16) ?? 0x1F9E7D
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    func setAccent(_ color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        accentHex = String(format: "%02X%02X%02X", Int((min(1, max(0, rgb.redComponent)) * 255).rounded()), Int((min(1, max(0, rgb.greenComponent)) * 255).rounded()), Int((min(1, max(0, rgb.blueComponent)) * 255).rounded()))
    }
}
