import SpeederCore
import SwiftUI

/// The popover shown when clicking the status item: current burst, session
/// average, peak and a sparkline of the live speed.
struct StatsPanelView: View {
    @ObservedObject var store: SpeedStore

    private let panelWidth: CGFloat = 268

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            SparklineView(points: store.history, tint: sparklineTint)
                .frame(height: 46)
            Divider()
            grid
            footer
        }
        .padding(14)
        .frame(width: panelWidth)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(WPMFormatter.string(store.stats.currentWPM))")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(sparklineTint)
                .contentTransition(.numericText())
            Text("wpm")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(store.stats.isTyping ? "typing" : "paused")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(store.stats.isTyping ? sparklineTint.opacity(0.2) : Color.secondary.opacity(0.15)))
                .foregroundStyle(store.stats.isTyping ? sparklineTint : .secondary)
        }
    }

    private var grid: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
            GridRow {
                metric("Burst", "\(WPMFormatter.string(store.stats.burstWPM))")
                metric("Average", "\(WPMFormatter.string(store.stats.averageWPM))")
            }
            GridRow {
                metric("Peak", "\(WPMFormatter.string(store.stats.peakWPM))")
                metric("Words", "\(store.stats.totalWords)")
            }
            GridRow {
                metric("Keystrokes", "\(store.stats.totalKeystrokes)")
                metric("Active", WPMFormatter.duration(store.stats.activeDuration))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if !store.isAuthorized {
                Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            } else if !store.isMonitoring {
                Label("Not capturing keystrokes", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            } else {
                Text("Global keystroke capture on")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .frame(width: 118, alignment: .leading)
    }

    private var sparklineTint: Color {
        switch WPMFormatter.Tier.tier(for: store.stats.currentWPM, isTyping: store.stats.isTyping) {
        case .idle: return .secondary
        case .slow: return .blue
        case .steady: return .green
        case .brisk: return .orange
        case .fast: return .red
        }
    }
}

private struct SparklineView: View {
    let points: [WPMHistoryPoint]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let values = points.map(\.wpm)
            let maximum = max(values.max() ?? 0, 20)
            let denominator = max(points.count - 1, 1)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))

                if points.count > 1 {
                    Path { path in
                        for (index, point) in points.enumerated() {
                            let x = size.width * CGFloat(index) / CGFloat(denominator)
                            let y = size.height * (1 - CGFloat(point.wpm / maximum))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                    if let last = points.last {
                        let x = size.width
                        let y = size.height * (1 - CGFloat(last.wpm / maximum))
                        Circle()
                            .fill(tint)
                            .frame(width: 3, height: 3)
                            .position(x: x, y: y)
                    }
                } else {
                    Text("No typing yet")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
