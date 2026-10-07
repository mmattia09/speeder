import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var accentHex: String { didSet { defaults.set(accentHex, forKey: "accentHex") } }
    @Published var showSpeed: Bool { didSet { defaults.set(showSpeed, forKey: "showSpeed") } }
    @Published var animateSpider: Bool { didSet { defaults.set(animateSpider, forKey: "animateSpider") } }
    @Published var goal: Double { didSet { defaults.set(goal, forKey: "goal") } }
    @Published var onboardingComplete: Bool { didSet { defaults.set(onboardingComplete, forKey: "onboardingComplete") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["showSpeed": true, "animateSpider": true, "goal": 60.0])
        accentHex = defaults.string(forKey: "accentHex") ?? "1F9E7D"
        showSpeed = defaults.bool(forKey: "showSpeed")
        animateSpider = defaults.bool(forKey: "animateSpider")
        goal = min(200, max(10, defaults.double(forKey: "goal")))
        onboardingComplete = defaults.bool(forKey: "onboardingComplete")
    }
}
