import SpeederCore
import SwiftUI

struct StatsPanelView: View {
    @Environment(\.speederAccent) private var accent
    @ObservedObject var store: SpeedStore
    var openDashboard: () -> Void
    var openSettings: () -> Void
    var width: CGFloat = 310

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 9) {
                    Text(WPMFormatter.string(store.stats.currentWPM))
                        .font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("words / min").font(.system(size: 11, weight: .medium))
                        Text(LocalizedStringKey(store.stats.isTyping && !store.isPaused ? "Current pace" : "Last pace")).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: store.togglePaused) {
                        Image(systemName: store.isPaused ? "play.fill" : "pause.fill").frame(width: 26, height: 26)
                    }.buttonStyle(.borderless).foregroundStyle(.secondary)
                        .help(LocalizedStringKey(store.isPaused ? "Resume tracking" : "Pause tracking"))
                        .accessibilityLabel(Text(LocalizedStringKey(store.isPaused ? "Resume tracking" : "Pause tracking")))
                }
                SpeedChart(points: store.history, compact: true).frame(height: 64)
                HStack(spacing: 14) {
                    MetricView(title: "Average", value: WPMFormatter.string(store.stats.averageWPM))
                    MetricView(title: "Peak", value: WPMFormatter.string(store.stats.peakWPM))
                    MetricView(title: "Words", value: "\(store.stats.totalWords)")
                }
                if !store.isAuthorized {
                    Button(action: store.requestAccess) {
                        Label("Enable Accessibility to start", systemImage: "lock.open")
                            .font(.system(size: 11))
                    }.buttonStyle(.borderless).foregroundStyle(accent)
                }
                Button(action: openDashboard) {
                    HStack {
                        Text("More statistics").fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }.font(.system(size: 12)).padding(11)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).foregroundStyle(accent)
            }.padding(20)
            Divider()
            HStack {
                Button(action: openSettings) { Image(systemName: "gearshape").frame(width: 24, height: 24) }
                    .help("Settings").accessibilityLabel("Settings")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.font(.system(size: 11))
            }.buttonStyle(.borderless).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 8)
        }.frame(width: width)
    }
}
