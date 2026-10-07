import Foundation
import SpeederCore

struct ChartSample: Identifiable {
    let point: WPMHistoryPoint
    let x: Double
    let series: Int
    var id: UUID { point.id }
}

enum ChartTimeline {
    static func samples(_ points: [WPMHistoryPoint]) -> [ChartSample] {
        var x = 0.0
        var series = 0
        return points.enumerated().map { index, point in
            if index > 0 {
                let previous = points[index - 1]
                let gap = point.date.timeIntervalSince(previous.date)
                let paused = point.segment != previous.segment || gap > 2.5
                if paused { series += 1 }
                x += paused ? 1.5 : max(0.001, gap)
            }
            return ChartSample(point: point, x: x, series: series)
        }
    }

    static func nearest(to x: Double, in samples: [ChartSample]) -> ChartSample? {
        guard let first = samples.first, let last = samples.last, x >= first.x, x <= last.x else { return nil }
        if let upper = samples.firstIndex(where: { $0.x >= x }), upper > 0,
           samples[upper - 1].series != samples[upper].series,
           x > samples[upper - 1].x + 0.15, x < samples[upper].x - 0.15 { return nil }
        return samples.min { abs($0.x - x) < abs($1.x - x) }
    }
}
