import Foundation
import Testing
@testable import AccessDeck

@MainActor
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

    @Test("Direct CLIProxyAPI URL defaults to the LAN management endpoint")
    func directURLDefaultsToCPA() {
        #expect(AppSettings.default.baseURL == "http://192.168.1.3:8317")
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
        let suiteName = "AccessDeckTests.SettingsStore.\(UUID().uuidString)"
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
        let suiteName = "AccessDeckTests.SettingsStore.\(UUID().uuidString)"
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
        let suiteName = "AccessDeckTests.SettingsStore.\(UUID().uuidString)"
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

    @Test("Settings credentials are excluded from the local UserDefaults payload")
    func settingsCredentialsUseSecretStore() {
        let suiteName = "AccessDeckTests.SettingsStore.Secrets.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let secrets = TestSettingsSecretStore()
        let store = SettingsStore(defaults: defaults, secretStore: secrets, syncsToCloud: false)
        var settings = AppSettings.default
        settings.managementKey = "management-secret"
        store.save(settings)

        #expect(defaults.string(forKey: "clipbar.managementKey") == nil)
        #expect(secrets.managementKey == "management-secret")
        #expect(store.load().managementKey == "management-secret")

        let reloadedStore = SettingsStore(defaults: defaults, secretStore: secrets, syncsToCloud: false)
        #expect(reloadedStore.load().managementKey == "management-secret")
    }

    @Test("Cloud sync can be disabled for local tests")
    func localStoreCanDisableCloudSync() {
        let suiteName = "AccessDeckTests.SettingsStore.NoCloud.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults, syncsToCloud: false)
        var settings = AppSettings.default
        settings.baseURL = "http://example.test"
        store.save(settings)

        #expect(store.load().baseURL == "http://example.test")
    }

    @Test("Cloud settings adopt only when the incoming timestamp is newer")
    func adoptsNewerCloudSettingsOnly() {
        let suiteName = "AccessDeckTests.SettingsStore.Cloud.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let cloud = TestSettingsCloudStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(
            defaults: defaults,
            cloud: cloud,
            secretStore: TestSettingsSecretStore()
        )
        var newer = AppSettings.default
        newer.baseURL = "http://newer.example.test"
        newer.refreshSeconds = 600
        store.save(newer)

        #expect(store.load().baseURL == "http://newer.example.test")
        #expect(store.load().refreshSeconds == 600)

        var older = AppSettings.default
        older.baseURL = "http://older.example.test"
        older.refreshSeconds = 60
        let olderSettingsData = try! JSONEncoder().encode(CloudSettingsPayload(settings: older))
        let olderPayloadData = try! JSONEncoder().encode(CloudPayloadForTests(timestamp: 1, data: olderSettingsData))
        cloud.set(olderPayloadData, forKey: "clipbar.cloud.settings.v1")
        cloud.synchronize()

        #expect(store.load().baseURL == "http://newer.example.test")
        #expect(store.load().refreshSeconds == 600)
    }

    @Test("Cloud settings preserve the local Keychain management key")
    func cloudSettingsPreserveManagementKey() {
        let suiteName = "AccessDeckTests.SettingsStore.CloudSecret.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let cloud = TestSettingsCloudStore()
        let secrets = TestSettingsSecretStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults, cloud: cloud, secretStore: secrets, syncsToCloud: false)
        var local = AppSettings.default
        local.baseURL = "http://local.example.test"
        local.managementKey = "local-management-secret"
        store.save(local)
        defaults.removeObject(forKey: "clipbar.settings.updatedAt")

        var cloudSettings = AppSettings.default
        cloudSettings.baseURL = "http://cloud.example.test"
        let cloudSettingsData = try! JSONEncoder().encode(CloudSettingsPayload(settings: cloudSettings))
        let cloudPayloadData = try! JSONEncoder().encode(CloudPayloadForTests(timestamp: 9_999_999_999, data: cloudSettingsData))
        cloud.set(cloudPayloadData, forKey: "clipbar.cloud.settings.v1")
        cloud.synchronize()
        let cloudStore = SettingsStore(defaults: defaults, cloud: cloud, secretStore: secrets)

        let loaded = cloudStore.load()
        #expect(loaded.baseURL == "http://cloud.example.test")
        #expect(loaded.managementKey == "local-management-secret")
        #expect(secrets.managementKey == "local-management-secret")
    }

    @Test("Cloud sync does not erase a temporarily unavailable management key")
    func cloudSyncDoesNotEraseUnavailableManagementKey() {
        let suiteName = "AccessDeckTests.SettingsStore.CloudUnavailableSecret.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let cloud = TestSettingsCloudStore()
        let secrets = TestSettingsSecretStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        secrets.managementKey = "local-management-secret"
        secrets.hideManagementKey = true

        var cloudSettings = AppSettings.default
        cloudSettings.baseURL = "http://cloud.example.test"
        let cloudSettingsData = try! JSONEncoder().encode(CloudSettingsPayload(settings: cloudSettings))
        let cloudPayloadData = try! JSONEncoder().encode(CloudPayloadForTests(timestamp: 9_999_999_999, data: cloudSettingsData))
        cloud.set(cloudPayloadData, forKey: "clipbar.cloud.settings.v1")

        let store = SettingsStore(defaults: defaults, cloud: cloud, secretStore: secrets)
        secrets.hideManagementKey = false

        #expect(store.load().managementKey == "local-management-secret")
    }

    @Test("Legacy management key remains when Keychain migration fails")
    func preservesLegacyKeyWhenMigrationFails() {
        let suiteName = "AccessDeckTests.SettingsStore.LegacySecret.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let secrets = TestSettingsSecretStore()
        secrets.saveShouldFail = true
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("legacy-management-secret", forKey: "clipbar.managementKey")
        let store = SettingsStore(defaults: defaults, secretStore: secrets, syncsToCloud: false)

        #expect(store.load().managementKey == "legacy-management-secret")
        #expect(defaults.string(forKey: "clipbar.managementKey") == "legacy-management-secret")
    }


    private final class TestSettingsCloudStore: SettingsCloudStore, @unchecked Sendable {
        let notificationObject: AnyObject = NSObject()
        private var values: [String: Data] = [:]

        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data, forKey key: String) { values[key] = data }
        func synchronize() -> Bool { true }
    }

    private final class TestSettingsSecretStore: SettingsSecretStore, @unchecked Sendable {
        var managementKey: String?
        var hideManagementKey = false
        var saveShouldFail = false

        func loadManagementKey() -> String? { hideManagementKey ? nil : managementKey }
        @discardableResult
        func saveManagementKey(_ value: String) -> Bool {
            guard !saveShouldFail else { return false }
            managementKey = value.isEmpty ? nil : value
            return true
        }
        func removeLegacyAccessToken() {}
    }

    private struct CloudSettingsPayload: Codable {
        let settings: AppSettings
    }

    private struct CloudPayloadForTests: Codable {
        let timestamp: Double
        let data: Data
    }

    @Test("Last selected provider persists in UserDefaults")
    func persistsLastSelectedProvider() {
        let suiteName = "AccessDeckTests.SettingsStore.\(UUID().uuidString)"
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
