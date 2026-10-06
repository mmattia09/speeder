import Charts
import SpeederCore
import SwiftUI

extension Color {
    static let speederAccent = Color(red: 0.12, green: 0.62, blue: 0.49)
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.055)))
    }
}

struct CaptureIndicator: View {
    @ObservedObject var store: SpeedStore
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(store.isMonitoring ? Color.speederAccent : Color.orange).frame(width: 6, height: 6)
            Text(store.captureLabel).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricView: View {
    let title: String
    let value: String
    var unit = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 23, weight: .medium, design: .rounded)).monospacedDigit()
                if !unit.isEmpty { Text(unit).font(.system(size: 10)).foregroundStyle(.secondary) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SpeedChart: View {
    let points: [WPMHistoryPoint]
    var compact = false
    var goal: Double? = nil

    var body: some View {
        if points.count < 2 {
            VStack(spacing: 8) {
                Image(systemName: "waveform.path").font(.system(size: compact ? 20 : 28)).foregroundStyle(Color.speederAccent.opacity(0.7))
                Text("Your rhythm starts here").font(.system(size: compact ? 11 : 14, weight: .medium))
                if !compact { Text("Type in any app to see your speed over time.").font(.system(size: 12)).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("No typing history yet")
        } else {
            Chart {
                ForEach(points) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("WPM", point.wpm))
                        .foregroundStyle(LinearGradient(colors: [.speederAccent.opacity(0.2), .speederAccent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Time", point.date), y: .value("WPM", point.wpm))
                        .foregroundStyle(Color.speederAccent).lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2, lineCap: .round))
                }
                if let goal {
                    RuleMark(y: .value("Goal", goal)).foregroundStyle(Color.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal · \(Int(goal))").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                }
            }
            .chartYScale(domain: 0...max(20, (points.map(\.wpm).max() ?? 0) * 1.15, (goal ?? 0) * 1.2))
            .chartXAxis(compact ? .hidden : .automatic)
            .chartYAxis(compact ? .hidden : .automatic)
            .accessibilityLabel("Typing speed over time, in words per minute")
        }
    }
}
