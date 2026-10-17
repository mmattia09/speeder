import Foundation
import SpeederCore

struct ChartSample: Identifiable {
    let point: WPMHistoryPoint
    let x: Double
    var id: UUID { point.id }
}

enum ChartTimeline {
    static func samples(_ points: [WPMHistoryPoint]) -> [ChartSample] {
        // A burst's first keystroke has no measurable elapsed time. Its zero
        // rate is a warm-up placeholder, not a slowdown in typing.
        let points = points.enumerated().compactMap { index, point in
            let startsBurst = index == 0 || point.segment != points[index - 1].segment
                || point.date.timeIntervalSince(points[index - 1].date) > 2.5
            return startsBurst && point.wpm == 0 ? nil : point
        }
        var x = 0.0
        return points.enumerated().map { index, point in
            if index > 0 {
                let previous = points[index - 1]
                let gap = point.date.timeIntervalSince(previous.date)
                let paused = point.segment != previous.segment || gap > 2.5
                // Pause boundaries share the same active-time coordinate.
                // Keep both measured rates, without allocating time to inactivity.
                if !paused { x += max(0, gap) }
            }
            return ChartSample(point: point, x: x)
        }
    }

    static func nearest(to x: Double, in samples: [ChartSample]) -> ChartSample? {
        guard let first = samples.first, let last = samples.last, x >= first.x, x <= last.x else { return nil }
        // At a shared boundary prefer the sample after the pause.
        return samples.reversed().min { abs($0.x - x) < abs($1.x - x) }
    }
}
