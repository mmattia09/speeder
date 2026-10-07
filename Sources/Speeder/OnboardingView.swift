import SwiftUI

struct OnboardingView: View {
    @Environment(\.speederAccent) private var accent
    @ObservedObject var store: SpeedStore
    @ObservedObject var preferences: AppPreferences
    var finish: () -> Void
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("WELCOME TO SPEEDER").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Text("\(step + 1) / 3").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Image(systemName: ["waveform.path", "lock.shield", "checkmark.circle"][step])
                .font(.system(size: 36, weight: .light)).foregroundStyle(accent)
                .frame(width: 72, height: 72).background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 12) {
                Text(["Get to know your rhythm.", "Your words stay yours.", "A little presence.\nA clearer picture."][step])
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text([
                    "A quiet companion in your menu bar. See your typing speed at a glance, then open your session for a closer look.",
                    "Speeder needs Accessibility access to count typing across apps. Key text is discarded immediately. Only numeric minute summaries are saved on your Mac; nothing is uploaded.",
                    "Click the tiny spider for your current pace. Open More statistics for your history, or set a comfortable WPM goal in Settings."
                ][step]).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
            if step == 1 {
                HStack {
                    CaptureIndicator(store: store)
                    Spacer()
                    Button(store.isAuthorized ? "Open Settings" : "Enable Accessibility", action: store.requestAccess)
                }
                Text("You can enable access later. Password fields protected by macOS are not captured.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack {
                if step > 0 { Button("Back") { step -= 1 }.buttonStyle(.plain).foregroundStyle(.secondary) }
                Spacer()
                Button(step == 2 ? "Make yourself at home" : step == 1 && !store.isAuthorized ? "Continue for now" : "Continue") {
                    if step < 2 { step += 1 }
                    else { preferences.onboardingComplete = true; finish() }
                }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 460, height: 450).tint(accent)
    }
}
