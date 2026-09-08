import Foundation

struct SettingsStore {
    private enum Key {
        static let baseURL = "clipbar.baseURL"
        static let managementKey = "clipbar.managementKey"
        static let backendURL = "clipbar.backendURL"
        static let backendAccessToken = "clipbar.backendAccessToken"
        static let refreshSeconds = "clipbar.refreshSeconds"
        static let statusItemOrder = "clipbar.statusItemOrder"
        static let hiddenStatusItemIDs = "clipbar.hiddenStatusItemIDs"
        static let hideEmptyStatusItems = "clipbar.hideEmptyStatusItems"
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        migrateLegacyKeysIfNeeded()
        var settings = AppSettings.default
        if let baseURL = defaults.string(forKey: Key.baseURL), !baseURL.isEmpty {
            settings.baseURL = baseURL
        }
        if let key = defaults.string(forKey: Key.managementKey) {
            settings.managementKey = key
        }
        if let backendURL = defaults.string(forKey: Key.backendURL), !backendURL.isEmpty {
            settings.backendURL = backendURL
        }
        if let token = defaults.string(forKey: Key.backendAccessToken), !token.isEmpty {
            settings.backendAccessToken = token
        }
        let refresh = defaults.integer(forKey: Key.refreshSeconds)
        if refresh > 0 {
            settings.refreshSeconds = refresh
        }
        settings.statusItemOrder = defaults.stringArray(forKey: Key.statusItemOrder) ?? []
        settings.hiddenStatusItemIDs = defaults.stringArray(forKey: Key.hiddenStatusItemIDs) ?? []
        if defaults.object(forKey: Key.hideEmptyStatusItems) != nil {
            settings.hideEmptyStatusItems = defaults.bool(forKey: Key.hideEmptyStatusItems)
        }
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
        defaults.set(settings.normalizedBaseURL, forKey: Key.baseURL)
        defaults.set(settings.normalizedManagementKey, forKey: Key.managementKey)
        defaults.set(settings.normalizedBackendURL, forKey: Key.backendURL)
        defaults.set(settings.normalizedBackendAccessToken, forKey: Key.backendAccessToken)
        defaults.set(settings.clampedRefreshSeconds, forKey: Key.refreshSeconds)
        defaults.set(settings.statusItemOrder, forKey: Key.statusItemOrder)
        defaults.set(settings.hiddenStatusItemIDs, forKey: Key.hiddenStatusItemIDs)
        defaults.set(settings.hideEmptyStatusItems, forKey: Key.hideEmptyStatusItems)
        defaults.set(settings.statusQuotaWindow.rawValue, forKey: Key.statusQuotaWindow)
        defaults.set(settings.statusQuotaDisplay.rawValue, forKey: Key.statusQuotaDisplay)
        defaults.set(
            settings.statusQuotaDisplayOverrides.mapValues(\.rawValue),
            forKey: Key.statusQuotaDisplayOverrides
        )
        defaults.set(settings.providerCustomColors, forKey: Key.providerCustomColors)
        defaults.set(settings.disabledAccountKeys, forKey: Key.disabledAccountKeys)
        defaults.set(settings.pinnedAccountKeys, forKey: Key.pinnedAccountKeys)
        defaults.set(settings.sortByRemainingQuota, forKey: Key.sortByRemainingQuota)
        defaults.set(settings.appTheme.rawValue, forKey: Key.appTheme)
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
        guard defaults.object(forKey: Key.managementKey) == nil else { return }
        let pairs = [
            ("clipquota.baseURL", Key.baseURL),
            ("clipquota.managementKey", Key.managementKey),
            ("clipquota.backendURL", Key.backendURL),
            ("clipquota.backendAccessToken", Key.backendAccessToken),
            ("clipquota.refreshSeconds", Key.refreshSeconds),
            ("clipquota.statusItemOrder", Key.statusItemOrder),
            ("clipquota.hiddenStatusItemIDs", Key.hiddenStatusItemIDs),
            ("clipquota.hideEmptyStatusItems", Key.hideEmptyStatusItems),
            ("clipquota.statusQuotaWindow", Key.statusQuotaWindow),
            ("clipquota.statusQuotaDisplay", Key.statusQuotaDisplay)
        ]
        for (old, new) in pairs {
            if defaults.object(forKey: new) == nil, let value = defaults.object(forKey: old) {
                defaults.set(value, forKey: new)
            }
        }
    }
}
