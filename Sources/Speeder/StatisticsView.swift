import Charts
import SpeederCore
import SwiftUI

struct DailyActivity: Identifiable {
    let date: Date
    var total: ActivityMinute
    var id: Date { date }

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

struct StatisticsView: View {
    @Environment(\.speederAccent) private var accent
    @ObservedObject var store: SpeedStore
    @State private var days = 30
    @State private var hovered: DailyActivity?

    private var activity: [DailyActivity] {
        let all = DailyActivity.aggregate(store.archiveRows)
        guard days > 0 else { return all }
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date()))!
        return all.filter { $0.date >= start }
    }
    private var total: ActivityMinute {
        activity.reduce(ActivityMinute(minute: 0)) { value, day in var sum = value; sum.merge(day.total); return sum }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The bigger picture.").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("Your rhythm over days, weeks and months.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Menu("Export all data") {
                    Button("JSON…") { store.exportAll(csv: false) }
                    Button("CSV…") { store.exportAll(csv: true) }
                }.fixedSize()
            }
            Picker("Period", selection: $days) {
                Text("7 days").tag(7); Text("30 days").tag(30); Text("All time").tag(0)
            }.pickerStyle(.segmented).frame(width: 270)
            if let error = store.storageError { Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
            HStack(spacing: 12) {
                Surface { MetricView(title: "Words", value: total.words.formatted()) }
                Surface { MetricView(title: "Average", value: WPMFormatter.string(total.averageWPM), unit: "wpm") }
                Surface { MetricView(title: "Peak", value: WPMFormatter.string(total.peakWPM), unit: "wpm") }
            }
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Daily activity").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(hovered.map { L("%@ · %lld words · %@ wpm", $0.date.formatted(date: .abbreviated, time: .omitted), $0.total.words, WPMFormatter.string($0.total.averageWPM)) } ?? L("Hover to explore"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if activity.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: "chart.bar.xaxis").font(.largeTitle).foregroundStyle(accent)
                            Text("A new chapter starts today").fontWeight(.medium)
                            Text("Your typing will appear here. Past sessions from older versions cannot be recovered.").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).frame(height: 190)
                    } else {
                        Chart(activity) { day in
                            BarMark(x: .value(L("Day"), day.date, unit: .day), y: .value(L("Words"), day.total.words))
                                .foregroundStyle(accent.gradient).cornerRadius(3)
                        }.frame(height: 190)
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Color.clear.contentShape(Rectangle()).onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        let plot = geometry[proxy.plotAreaFrame]
                                        if plot.contains(location), let date: Date = proxy.value(atX: location.x - plot.minX) {
                                            hovered = activity.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                                        } else { hovered = nil }
                                    case .ended: hovered = nil
                                    }
                                }
                            }
                        }
                    }
                    HStack {
                        Text(L("Active days: %lld", activity.count))
                        Spacer()
                        Text(L("%@ typing · %lld keystrokes", WPMFormatter.duration(total.activeSeconds), total.keystrokes))
                    }.font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if !activity.isEmpty {
                Surface {
                    VStack(spacing: 12) {
                        HStack { Text("Recent days").fontWeight(.semibold); Spacer(); Text("Words · Average · Active time").foregroundStyle(.secondary) }
                        ForEach(activity.suffix(14).reversed()) { day in
                            Divider()
                            HStack {
                                Text(day.date, format: .dateTime.day().month(.abbreviated).year())
                                Spacer()
                                Text("\(day.total.words) · \(WPMFormatter.string(day.total.averageWPM)) wpm · \(WPMFormatter.duration(day.total.activeSeconds))").monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }.font(.system(size: 11))
                }
            }
            Text("Stored locally as minute summaries. Exports include the complete history, regardless of the selected period. No key text is stored.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .onAppear { store.saveArchive() }
        .onChange(of: days) { _ in hovered = nil }
        .alert("Data export", isPresented: Binding(get: { store.exportMessage != nil }, set: { if !$0 { store.exportMessage = nil } })) {
            Button("OK") { store.exportMessage = nil }
        } message: { Text(store.exportMessage ?? "") }
    }
}
