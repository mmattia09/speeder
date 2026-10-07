import Foundation

/// Publish the mean of five keystroke rates, then flush a partial batch on idle.
public struct MenuBarSmoother {
    public private(set) var value: Double = 0
    private var sum: Double = 0
    private var count = 0
    private var lastDate: Date?

    public init() {}

    public mutating func record(_ rate: Double, at date: Date) {
        if let lastDate, date.timeIntervalSince(lastDate) > 1.5 { flush() }
        sum += max(0, rate.isFinite ? rate : 0)
        count += 1
        lastDate = date
        if count >= 5 { flush() }
    }

    public mutating func idle(at date: Date) {
        if let lastDate, date.timeIntervalSince(lastDate) > 1.5 { flush() }
    }

    public mutating func flush() {
        guard count > 0 else { return }
        value = sum / Double(count)
        sum = 0
        count = 0
    }
}
