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

    @Test("Direct CLIProxyAPI URL is blank by default")
    func directURLDefaultIsBlank() {
        #expect(AppSettings.default.baseURL.isEmpty)
    }

    @Test("Status quota window defaults to 5h")
    func defaultsToFiveHourWindow() {
        #expect(AppSettings.default.statusQuotaWindow == .fiveHour)
    }

    @Test("Menu bar quota display defaults to 5h")
    func defaultsToFiveHourMenuBarDisplay() {
        #expect(AppSettings.default.statusQuotaDisplay == .fiveHour)
    }

    @Test("Provider quota display overrides persist in UserDefaults")
    func persistsProviderStatusQuotaDisplayOverrides() {
        let suiteName = "ClipBarTests.SettingsStore.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = AppSettings.default
        settings.statusQuotaDisplay = .weekly
        settings.statusQuotaDisplayOverrides[QuotaProvider.codex.rawValue] = .both
        let store = SettingsStore(defaults: defaults)
        store.save(settings)

        let loaded = store.load()
        #expect(loaded.statusQuotaDisplay == .weekly)
        #expect(loaded.statusQuotaDisplay(for: .codex) == .both)
        #expect(loaded.statusQuotaDisplay(for: .claude) == .weekly)
    }

    @Test("Menu bar quota display persists in UserDefaults")
    func persistsStatusQuotaDisplay() {
        let suiteName = "ClipBarTests.SettingsStore.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = AppSettings.default
        settings.statusQuotaDisplay = .both
        let store = SettingsStore(defaults: defaults)
        store.save(settings)

        #expect(store.load().statusQuotaDisplay == .both)
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

    @Test("Last selected provider persists in UserDefaults")
    func persistsLastSelectedProvider() {
        let suiteName = "ClipBarTests.SettingsStore.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        #expect(store.loadLastSelectedProvider() == nil)

        store.saveLastSelectedProvider(.codex)
        #expect(store.loadLastSelectedProvider() == .codex)

        store.saveLastSelectedProvider(.claude)
        #expect(store.loadLastSelectedProvider() == .claude)
    }
}
