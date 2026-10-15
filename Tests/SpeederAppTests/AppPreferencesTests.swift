import Foundation
import Combine
import Testing
import SpeederCore
@testable import Speeder

@Suite("App preferences")
@MainActor
struct AppPreferencesTests {
    @Test func defaultsAndPersistence() {
        let name = "Speeder.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppPreferences(defaults: defaults)
        #expect(settings.showSpeed)
        #expect(settings.animateSpider)
        #expect(settings.goal == 60)
        #expect(!settings.onboardingComplete)
        settings.showSpeed = false
        settings.animateSpider = false
        settings.accentHex = "3478F6"
        settings.goal = 85
        settings.onboardingComplete = true
        let restored = AppPreferences(defaults: defaults)
        #expect(!restored.showSpeed)
        #expect(!restored.animateSpider)
        #expect(restored.goal == 85)
        #expect(restored.accentHex == "3478F6")
        #expect(restored.onboardingComplete)
    }

    @Test func storedGoalIsClamped() {
        let name = "Speeder.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(0, forKey: "goal")
        #expect(AppPreferences(defaults: defaults).goal == 10)
        defaults.set(500, forKey: "goal")
        #expect(AppPreferences(defaults: defaults).goal == 200)
    }
    @Test func pauseDiscardsEventsAndResetClearsTheSnapshot() {
        let name = "Speeder.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let session = TypingSession()
        let store = SpeedStore(session: session, preferences: AppPreferences(defaults: defaults))
        store.handle(.character)
        store.updateSnapshot()
        #expect(store.stats.totalKeystrokes == 1)
        store.togglePaused()
        store.handle(.character)
        store.updateSnapshot()
        #expect(store.isPaused)
        #expect(!store.isMonitoring)
        #expect(store.stats.totalKeystrokes == 1)
        #expect(store.captureLabel == "Tracking paused")
        store.reset()
        #expect(store.stats == .empty)
        #expect(store.history.isEmpty)
        store.stop()
    }

    @Test func idleSnapshotsDoNotRepublishUnchangedStats() {
        let name = "Speeder.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.animateSpider = false
        let store = SpeedStore(preferences: preferences)
        var emissions = 0
        let subscription = store.$stats.sink { _ in emissions += 1 }
        for _ in 0..<20 { store.updateSnapshot() }
        #expect(emissions == 1)
        store.handle(.character)
        store.updateSnapshot()
        #expect(emissions == 2)
        for _ in 0..<20 { store.updateSnapshot() }
        #expect(emissions == 2)
        subscription.cancel()
    }

}
