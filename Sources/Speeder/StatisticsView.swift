import Charts
import SpeederCore
import SwiftUI

struct DailyActivity: Identifiable {
    let date: Date
    var total: ActivityMinute
    var id: Date { date }
    var chartDay: String { date.formatted(date: .abbreviated, time: .omitted) }

    static func aggregate(_ rows: [ActivityMinute], calendar: Calendar = .current) -> [DailyActivity] {
        var days: [Date: ActivityMinute] = [:]
        for row in rows {
            let day = calendar.startOfDay(for: row.date)
            var total = days[day] ?? ActivityMinute(minute: Int64(day.timeIntervalSince1970))
            total.merge(row); days[day] = total
        }
        return days.map { DailyActivity(date: $0.key, total: $0.value) }.sorted { $0.date < $1.date }
    }
}

private enum HistoryMetric: String, CaseIterable {
    case words = "Words", speed = "Average", duration = "Active time"
    var unit: String { switch self { case .words: return ""; case .speed: return "wpm"; case .duration: return "min" } }
    func value(_ day: DailyActivity) -> Double {
        switch self { case .words: return Double(day.total.words); case .speed: return day.total.averageWPM; case .duration: return day.total.activeSeconds / 60 }
    }
}

struct StatisticsView: View {
    @Environment(\.speederAccent) private var accent
    @ObservedObject var store: SpeedStore
    @State private var days = 30
    private var rows: [ActivityMinute] {
        guard days > 0 else { return store.archiveRows }
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date()))!
        return store.archiveRows.filter { $0.date >= start }
    }
    private var activity: [DailyActivity] { DailyActivity.aggregate(rows) }
    private var total: ActivityMinute {
        rows.reduce(ActivityMinute(minute: 0)) { value, row in var sum = value; sum.merge(row); return sum }
    }
    private var hourly: [Double] {
        var result = Array(repeating: 0.0, count: 24)
        for row in rows { result[Calendar.current.component(.hour, from: row.date)] += row.activeSeconds / 60 }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Statistics").font(.system(size: 25, weight: .semibold, design: .rounded))
                Spacer()
                Button("Import…", action: store.importStatistics)
                Menu("Export all data") {
                    Button("JSON…") { store.exportAll(csv: false) }
                    Button("CSV…") { store.exportAll(csv: true) }
                }.fixedSize()
            }
            HStack(spacing: 12) {
                Picker("Period", selection: $days) {
                    Text("7 days").tag(7); Text("30 days").tag(30); Text("90 days").tag(90); Text("All time").tag(0)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 320)
                Spacer()
                Text(L("Active days: %lld", activity.count)).font(.caption).foregroundStyle(.secondary)
            }
            if let error = store.storageError { Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
            HStack(spacing: 16) {
                MetricView(title: "Words", value: total.words.formatted())
                Divider()
                MetricView(title: "Average", value: WPMFormatter.string(total.averageWPM), unit: "wpm")
                Divider()
                MetricView(title: "Active time", value: WPMFormatter.duration(total.activeSeconds))
            }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
            if activity.isEmpty {
                ContentUnavailableHistory()
            } else {
                VStack(spacing: 22) {
                    ForEach(HistoryMetric.allCases, id: \.self) { metric in
                        HistoryChart(activity: activity, metric: metric)
                        Divider()
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Activity by hour").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("Active minutes · local time").font(.caption).foregroundStyle(.secondary)
                        }
                        Chart(0..<24, id: \.self) { hour in
                            BarMark(x: .value(L("Hour"), hour), y: .value(L("Active time"), hourly[hour]), width: .fixed(12))
                                .foregroundStyle(accent.opacity(0.75)).cornerRadius(2)
                        }.chartXScale(domain: -0.5...23.5)
                            .chartXAxis { AxisMarks(values: [0, 6, 12, 18]) }
                            .frame(height: 115)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent days").font(.system(size: 13, weight: .semibold))
                    Grid(horizontalSpacing: 20, verticalSpacing: 10) {
                        GridRow {
                            Text("Day").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Words"); Text("Average"); Text("Peak"); Text("Active time")
                        }.foregroundStyle(.secondary)
                        Divider()
                        ForEach(activity.suffix(30).reversed()) { day in
                            GridRow {
                                Text(day.date, format: .dateTime.day().month(.abbreviated).year()).frame(maxWidth: .infinity, alignment: .leading)
                                Text(day.total.words.formatted())
                                Text(WPMFormatter.string(day.total.averageWPM))
                                Text(WPMFormatter.string(day.total.peakWPM))
                                Text(WPMFormatter.duration(day.total.activeSeconds))
                            }.monospacedDigit()
                        }
                    }.font(.system(size: 11))
                }
            }
        }
        .onAppear { store.saveArchive() }
        .alert("Statistics", isPresented: Binding(get: { store.exportMessage != nil }, set: { if !$0 { store.exportMessage = nil } })) {
            Button("OK") { store.exportMessage = nil }
        } message: { Text(store.exportMessage ?? "") }
    }
}

private struct ContentUnavailableHistory: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis").font(.largeTitle).foregroundStyle(.secondary)
            Text("No recorded activity").fontWeight(.medium)
            Text("Type in any app or import a Speeder export.").foregroundStyle(.secondary)
        }.font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, 70)
    }
}

private struct HistoryChart: View {
    @Environment(\.speederAccent) private var accent
    let activity: [DailyActivity]
    let metric: HistoryMetric
    @State private var hovered: DailyActivity?
    private var ticks: [String] {
        stride(from: 0, to: activity.count, by: max(1, (activity.count + 3) / 4)).map { activity[$0].chartDay }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey(metric.rawValue)).font(.system(size: 13, weight: .semibold))
                if !metric.unit.isEmpty { Text(metric.unit).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if let day = hovered {
                    Text("\(day.chartDay) · \(metric.value(day).formatted(.number.precision(.fractionLength(0...1)))) \(metric.unit)")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }.frame(height: 18)
            Chart {
                ForEach(activity) { day in
                    if metric == .speed {
                        LineMark(x: .value(L("Day"), day.chartDay), y: .value(L(metric.rawValue), metric.value(day)))
                            .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value(L("Day"), day.chartDay), y: .value(L(metric.rawValue), metric.value(day)))
                            .foregroundStyle(accent).symbolSize(12)
                    } else {
                        BarMark(x: .value(L("Day"), day.chartDay), y: .value(L(metric.rawValue), metric.value(day)))
                            .foregroundStyle(accent.opacity(metric == .words ? 0.85 : 0.55)).cornerRadius(2)
                    }
                }
                if let hovered {
                    RuleMark(x: .value(L("Day"), hovered.chartDay)).foregroundStyle(.secondary.opacity(0.4))
                }
            }
            .chartXAxis { AxisMarks(values: ticks) { AxisValueLabel(anchor: .topLeading) } }
            .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) }
            .frame(height: 130)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle()).onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let plot = geometry[proxy.plotAreaFrame]
                            guard plot.contains(location), let day: String = proxy.value(atX: location.x - plot.minX) else { hovered = nil; return }
                            hovered = activity.first { $0.chartDay == day }
                        case .ended: hovered = nil
                        }
                    }
                }
            }
        }.onChange(of: activity.map(\.id)) { _ in hovered = nil }
    }
}
