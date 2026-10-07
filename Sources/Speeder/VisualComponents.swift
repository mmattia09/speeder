import Charts
import SpeederCore
import SwiftUI

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.055)))
    }
}

struct CaptureIndicator: View {
    @Environment(\.speederAccent) private var accent
    @ObservedObject var store: SpeedStore
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(store.isMonitoring ? accent : Color.orange).frame(width: 6, height: 6)
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
    @Environment(\.speederAccent) private var accent
    let points: [WPMHistoryPoint]
    var compact = false
    var goal: Double? = nil
    @State private var selected: ChartSample?
    private var samples: [ChartSample] { ChartTimeline.samples(points) }

    var body: some View {
        if points.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "waveform.path").font(.system(size: compact ? 20 : 28)).foregroundStyle(accent.opacity(0.7))
                Text("Your rhythm starts here").font(.system(size: compact ? 11 : 14, weight: .medium))
                if !compact { Text("Type in any app to see your speed over time.").font(.system(size: 12)).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(samples) { sample in
                    AreaMark(x: .value("Typing time", sample.x), y: .value("WPM", sample.point.wpm), series: .value("Burst", sample.series), stacking: .unstacked)
                        .foregroundStyle(LinearGradient(colors: [accent.opacity(0.2), accent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Typing time", sample.x), y: .value("WPM", sample.point.wpm), series: .value("Burst", sample.series))
                        .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2, lineCap: .round))
                    PointMark(x: .value("Typing time", sample.x), y: .value("WPM", sample.point.wpm))
                        .foregroundStyle(accent).symbolSize(4)
                }
                if let goal {
                    RuleMark(y: .value("Goal", goal)).foregroundStyle(Color.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                if let selected {
                    RuleMark(x: .value("Selected", selected.x)).foregroundStyle(Color.secondary.opacity(0.5))
                    PointMark(x: .value("Selected", selected.x), y: .value("WPM", selected.point.wpm))
                        .foregroundStyle(accent).symbolSize(35)
                }
            }
            .chartXScale(domain: 0...max(samples.last?.x ?? 0, 1))
            .chartYScale(domain: 0...max(20, (points.map(\.wpm).max() ?? 0) * 1.15, (goal ?? 0) * 1.2))
            .chartXAxis(.hidden)
            .chartYAxis(compact ? .hidden : .automatic)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle()).onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let plot = geometry[proxy.plotAreaFrame]
                            guard plot.contains(location), let x: Double = proxy.value(atX: location.x - plot.minX) else { selected = nil; return }
                            selected = ChartTimeline.nearest(to: x, in: samples)
                        case .ended: selected = nil
                        }
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if let selected {
                    HStack(spacing: 6) {
                        Text("\(WPMFormatter.string(selected.point.wpm)) wpm").fontWeight(.semibold)
                        Text(selected.point.date, style: .time).foregroundStyle(.secondary)
                    }.font(.system(size: compact ? 10 : 12)).padding(6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: points) { points in
                if let id = selected?.id { selected = samples.first { $0.id == id } }
            }
            .accessibilityLabel("Typing speed. Pauses appear as breaks; hover for WPM and actual time.")
        }
    }
}
