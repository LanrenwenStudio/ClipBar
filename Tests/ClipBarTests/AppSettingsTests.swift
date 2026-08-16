import Foundation
import Testing
@testable import ClipBar

struct AppSettingsTests {
    @Test("Refresh interval normalizes to supported presets and defaults to 5 minutes")
    func normalizesRefreshInterval() {
        #expect(AppSettings.default.refreshSeconds == 300)
        #expect(AppSettings.nearestRefreshInterval(to: 15) == 60)
        #expect(AppSettings.nearestRefreshInterval(to: 60) == 60)
        #expect(AppSettings.nearestRefreshInterval(to: 180) == 180)
        #expect(AppSettings.nearestRefreshInterval(to: 300) == 300)
        #expect(AppSettings.nearestRefreshInterval(to: 550) == 600)
        #expect(AppSettings.nearestRefreshInterval(to: 600) == 600)
        #expect(AppSettings.nearestRefreshInterval(to: 1000) == 900)
    }

    @Test("Status quota window defaults to 5h")
    func defaultsToFiveHourWindow() {
        #expect(AppSettings.default.statusQuotaWindow == .fiveHour)
    }

    @Test("Status quota window persists in UserDefaults")
    func persistsStatusQuotaWindow() {
        let suiteName = "ClipBarTests.SettingsStore.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = AppSettings.default
        settings.statusQuotaWindow = .weekly
        let store = SettingsStore(defaults: defaults)
        store.save(settings)

        #expect(store.load().statusQuotaWindow == .weekly)
    }
}
