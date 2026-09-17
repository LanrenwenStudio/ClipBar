import Foundation

@MainActor
protocol SettingsCloudStore: AnyObject {
    var notificationObject: AnyObject { get }
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    @discardableResult
    func synchronize() -> Bool
}

@MainActor
final class UbiquitousSettingsCloudStore: SettingsCloudStore {
    private let store: NSUbiquitousKeyValueStore

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    var notificationObject: AnyObject { store }

    func data(forKey key: String) -> Data? {
        store.data(forKey: key)
    }

    func set(_ data: Data, forKey key: String) {
        store.set(data, forKey: key)
    }

    @discardableResult
    func synchronize() -> Bool {
        store.synchronize()
    }
}

@MainActor
final class SettingsStore {
    private enum Key {
        static let baseURL = "clipbar.baseURL"
        static let managementKey = "clipbar.managementKey"
        static let connectionMode = "clipbar.connectionMode"
        static let legacyBackendURL = "clipbar.backendURL"
        static let legacyBackendAccessToken = "clipbar.backendAccessToken"
        static let refreshSeconds = "clipbar.refreshSeconds"
        static let statusItemOrder = "clipbar.statusItemOrder"
        static let hiddenStatusItemIDs = "clipbar.hiddenStatusItemIDs"
        static let statusQuotaWindow = "clipbar.statusQuotaWindow"
        static let statusQuotaDisplay = "clipbar.statusQuotaDisplay"
        static let statusQuotaDisplayOverrides = "clipbar.statusQuotaDisplayOverrides"
        static let providerCustomColors = "clipbar.providerCustomColors"
        static let disabledAccountKeys = "clipbar.disabledAccountKeys"
        static let pinnedAccountKeys = "clipbar.pinnedAccountKeys"
        static let sortByRemainingQuota = "clipbar.sortByRemainingQuota"
        static let appTheme = "clipbar.appTheme"
        static let cachedAccounts = "clipbar.cachedAccounts"
        static let lastRefreshedAt = "clipbar.lastRefreshedAt"
        static let lastSelectedProvider = "clipbar.lastSelectedProvider"
    }

    private let defaults: UserDefaults
    private let cloud: any SettingsCloudStore
    private let secretStore: SettingsSecretStore
    private let syncsToCloud: Bool
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cloudKey = "clipbar.cloud.settings.v1"
    private let settingsTimestampKey = "clipbar.settings.updatedAt"
    private var cloudObserver: NSObjectProtocol?
    private var isApplyingCloudSettings = false

    struct CloudChange: Sendable {
        let settings: AppSettings
    }

    var onCloudChange: (@MainActor @Sendable (CloudChange) -> Void)?

    private struct CloudPayload: Codable {
        let timestamp: Double
        let data: Data
    }

    init(
        defaults: UserDefaults = .standard,
        cloud: any SettingsCloudStore = UbiquitousSettingsCloudStore(),
        secretStore: SettingsSecretStore = KeychainSettingsSecretStore(),
        syncsToCloud: Bool = true
    ) {
        self.defaults = defaults
        self.cloud = cloud
        self.secretStore = secretStore
        self.syncsToCloud = syncsToCloud
        guard syncsToCloud else { return }

        adoptCloudIfNewer()
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud.notificationObject,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.adoptCloudIfNewer()
            }
        }
    }

    func load() -> AppSettings {
        migrateLegacyKeysIfNeeded()
        var settings = AppSettings.default
        if let baseURL = defaults.string(forKey: Key.baseURL), !baseURL.isEmpty {
            settings.baseURL = baseURL
        }
        if settings.baseURL.isEmpty {
            settings.baseURL = AppSettings.defaultBaseURL
        }
        if let key = secretStore.loadManagementKey() {
            settings.managementKey = key
        } else if let key = defaults.string(forKey: Key.managementKey) {
            settings.managementKey = key
            if secretStore.saveManagementKey(key) {
                defaults.removeObject(forKey: Key.managementKey)
            }
        }
        if let rawMode = defaults.string(forKey: Key.connectionMode),
           let mode = QuotaConnectionMode(rawValue: rawMode) {
            settings.connectionMode = mode
        }
        secretStore.removeLegacyAccessToken()
        removeLegacyBackendSettings()
        let refresh = defaults.integer(forKey: Key.refreshSeconds)
        if refresh > 0 {
            settings.refreshSeconds = refresh
        }
        settings.statusItemOrder = defaults.stringArray(forKey: Key.statusItemOrder) ?? []
        settings.hiddenStatusItemIDs = defaults.stringArray(forKey: Key.hiddenStatusItemIDs) ?? []
        if let raw = defaults.string(forKey: Key.statusQuotaWindow),
           let window = StatusQuotaWindow(rawValue: raw) {
            settings.statusQuotaWindow = window
        }
        if let raw = defaults.string(forKey: Key.statusQuotaDisplay),
           let display = StatusQuotaDisplay(rawValue: raw) {
            settings.statusQuotaDisplay = display
        }
        if let rawOverrides = defaults.dictionary(forKey: Key.statusQuotaDisplayOverrides) as? [String: String] {
            settings.statusQuotaDisplayOverrides = rawOverrides.reduce(into: [:]) { result, item in
                if let display = StatusQuotaDisplay(rawValue: item.value) {
                    result[item.key] = display
                }
            }
        }
        if let rawColors = defaults.dictionary(forKey: Key.providerCustomColors) as? [String: String] {
            settings.providerCustomColors = rawColors
        }
        settings.disabledAccountKeys = defaults.stringArray(forKey: Key.disabledAccountKeys) ?? []
        settings.pinnedAccountKeys = defaults.stringArray(forKey: Key.pinnedAccountKeys) ?? []
        if let rawTheme = defaults.string(forKey: Key.appTheme),
           let theme = AppTheme(rawValue: rawTheme) {
            settings.appTheme = theme
        }
        if defaults.object(forKey: Key.sortByRemainingQuota) != nil {
            settings.sortByRemainingQuota = defaults.bool(forKey: Key.sortByRemainingQuota)
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        saveLocal(settings)
        pushSettingsToCloud(settings)
    }

    // MARK: - iCloud settings sync

    private func pushSettingsToCloud(_ settings: AppSettings) {
        guard syncsToCloud, !isApplyingCloudSettings,
              let data = try? encoder.encode(SettingsPayload(settings: settings)) else { return }
        let timestamp = Date().timeIntervalSince1970
        guard let payload = try? encoder.encode(CloudPayload(timestamp: timestamp, data: data)) else { return }
        defaults.set(timestamp, forKey: settingsTimestampKey)
        cloud.set(payload, forKey: cloudKey)
        cloud.synchronize()
    }

    private func adoptCloudIfNewer() {
        guard syncsToCloud else { return }
        guard let payloadData = cloud.data(forKey: cloudKey),
              let payload = try? decoder.decode(CloudPayload.self, from: payloadData),
              let settingsPayload = try? decoder.decode(SettingsPayload.self, from: payload.data) else { return }

        let localTimestamp = defaults.double(forKey: settingsTimestampKey)
        guard payload.timestamp > localTimestamp else { return }
        defaults.set(payload.timestamp, forKey: settingsTimestampKey)
        isApplyingCloudSettings = true
        apply(settingsPayload.settings)
        isApplyingCloudSettings = false
        onCloudChange?(CloudChange(settings: settingsPayload.settings))
    }

    private func apply(_ settings: AppSettings) {
        var merged = settings
        if let localKey = secretStore.loadManagementKey() {
            merged.managementKey = localKey
            saveLocal(merged)
        } else {
            saveLocal(merged, updateManagementKey: false)
        }
    }

    private func saveLocal(_ settings: AppSettings, updateManagementKey: Bool = true) {
        defaults.set(settings.normalizedBaseURL, forKey: Key.baseURL)
        if updateManagementKey,
           secretStore.saveManagementKey(settings.normalizedManagementKey) {
            defaults.removeObject(forKey: Key.managementKey)
        }
        defaults.set(settings.connectionMode.rawValue, forKey: Key.connectionMode)
        removeLegacyBackendSettings()
        defaults.set(settings.clampedRefreshSeconds, forKey: Key.refreshSeconds)
        defaults.set(settings.statusItemOrder, forKey: Key.statusItemOrder)
        defaults.set(settings.hiddenStatusItemIDs, forKey: Key.hiddenStatusItemIDs)
        defaults.set(settings.statusQuotaWindow.rawValue, forKey: Key.statusQuotaWindow)
        defaults.set(settings.statusQuotaDisplay.rawValue, forKey: Key.statusQuotaDisplay)
        defaults.set(settings.statusQuotaDisplayOverrides.mapValues(\.rawValue), forKey: Key.statusQuotaDisplayOverrides)
        defaults.set(settings.providerCustomColors, forKey: Key.providerCustomColors)
        defaults.set(settings.disabledAccountKeys, forKey: Key.disabledAccountKeys)
        defaults.set(settings.pinnedAccountKeys, forKey: Key.pinnedAccountKeys)
        defaults.set(settings.sortByRemainingQuota, forKey: Key.sortByRemainingQuota)
        defaults.set(settings.appTheme.rawValue, forKey: Key.appTheme)
    }

    private struct SettingsPayload: Codable {
        let settings: AppSettings

        init(settings: AppSettings) {
            self.settings = settings
        }
    }

    func loadCachedAccounts() -> (accounts: [AccountQuota], lastRefreshedAt: Date?) {
        guard let data = defaults.data(forKey: Key.cachedAccounts),
              let accounts = try? JSONDecoder().decode([AccountQuota].self, from: data) else {
            return ([], nil)
        }
        let date = defaults.object(forKey: Key.lastRefreshedAt) as? Date
        return (accounts, date)
    }

    func saveCachedAccounts(_ accounts: [AccountQuota], at date: Date) {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: Key.cachedAccounts)
            defaults.set(date, forKey: Key.lastRefreshedAt)
        }
    }

    func loadLastSelectedProvider() -> QuotaProvider? {
        guard let raw = defaults.string(forKey: Key.lastSelectedProvider) else { return nil }
        return QuotaProvider(rawValue: raw)
    }

    func saveLastSelectedProvider(_ provider: QuotaProvider?) {
        if let raw = provider?.rawValue {
            defaults.set(raw, forKey: Key.lastSelectedProvider)
        } else {
            defaults.removeObject(forKey: Key.lastSelectedProvider)
        }
    }

    private func migrateLegacyKeysIfNeeded() {
        let pairs = [
            ("clipquota.baseURL", Key.baseURL),
            ("clipquota.managementKey", Key.managementKey),
            ("clipquota.refreshSeconds", Key.refreshSeconds),
            ("clipquota.statusItemOrder", Key.statusItemOrder),
            ("clipquota.hiddenStatusItemIDs", Key.hiddenStatusItemIDs),
            ("clipquota.statusQuotaWindow", Key.statusQuotaWindow),
            ("clipquota.statusQuotaDisplay", Key.statusQuotaDisplay)
        ]
        for (old, new) in pairs {
            if defaults.object(forKey: new) == nil, let value = defaults.object(forKey: old) {
                defaults.set(value, forKey: new)
            }
        }
        defaults.removeObject(forKey: "clipquota.backendURL")
        defaults.removeObject(forKey: "clipquota.backendAccessToken")
    }

    private func removeLegacyBackendSettings() {
        defaults.removeObject(forKey: Key.legacyBackendURL)
        defaults.removeObject(forKey: Key.legacyBackendAccessToken)
        defaults.removeObject(forKey: "clipquota.backendURL")
        defaults.removeObject(forKey: "clipquota.backendAccessToken")
    }
}
