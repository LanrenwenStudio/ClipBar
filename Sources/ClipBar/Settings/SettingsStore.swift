import Foundation

struct SettingsStore {
    private enum Key {
        static let baseURL = "clipbar.baseURL"
        static let managementKey = "clipbar.managementKey"
        static let refreshSeconds = "clipbar.refreshSeconds"
        static let statusItemOrder = "clipbar.statusItemOrder"
        static let hiddenStatusItemIDs = "clipbar.hiddenStatusItemIDs"
        static let hideEmptyStatusItems = "clipbar.hideEmptyStatusItems"
        static let statusQuotaWindow = "clipbar.statusQuotaWindow"
        static let disabledAccountKeys = "clipbar.disabledAccountKeys"
        static let pinnedAccountKeys = "clipbar.pinnedAccountKeys"
        static let lowQuotaAlertThreshold = "clipbar.lowQuotaAlertThreshold"
        static let enableNotifications = "clipbar.enableNotifications"
        static let sortByRemainingQuota = "clipbar.sortByRemainingQuota"
        static let appTheme = "clipbar.appTheme"
        static let cachedAccounts = "clipbar.cachedAccounts"
        static let lastRefreshedAt = "clipbar.lastRefreshedAt"
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
        settings.disabledAccountKeys = defaults.stringArray(forKey: Key.disabledAccountKeys) ?? []
        settings.pinnedAccountKeys = defaults.stringArray(forKey: Key.pinnedAccountKeys) ?? []
        if defaults.object(forKey: Key.lowQuotaAlertThreshold) != nil {
            settings.lowQuotaAlertThreshold = defaults.integer(forKey: Key.lowQuotaAlertThreshold)
        }
        if defaults.object(forKey: Key.enableNotifications) != nil {
            settings.enableNotifications = defaults.bool(forKey: Key.enableNotifications)
        }
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
        defaults.set(settings.clampedRefreshSeconds, forKey: Key.refreshSeconds)
        defaults.set(settings.statusItemOrder, forKey: Key.statusItemOrder)
        defaults.set(settings.hiddenStatusItemIDs, forKey: Key.hiddenStatusItemIDs)
        defaults.set(settings.hideEmptyStatusItems, forKey: Key.hideEmptyStatusItems)
        defaults.set(settings.statusQuotaWindow.rawValue, forKey: Key.statusQuotaWindow)
        defaults.set(settings.disabledAccountKeys, forKey: Key.disabledAccountKeys)
        defaults.set(settings.pinnedAccountKeys, forKey: Key.pinnedAccountKeys)
        defaults.set(settings.lowQuotaAlertThreshold, forKey: Key.lowQuotaAlertThreshold)
        defaults.set(settings.enableNotifications, forKey: Key.enableNotifications)
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

    private func migrateLegacyKeysIfNeeded() {
        guard defaults.object(forKey: Key.managementKey) == nil else { return }
        let pairs = [
            ("clipquota.baseURL", Key.baseURL),
            ("clipquota.managementKey", Key.managementKey),
            ("clipquota.refreshSeconds", Key.refreshSeconds),
            ("clipquota.statusItemOrder", Key.statusItemOrder),
            ("clipquota.hiddenStatusItemIDs", Key.hiddenStatusItemIDs),
            ("clipquota.hideEmptyStatusItems", Key.hideEmptyStatusItems),
            ("clipquota.statusQuotaWindow", Key.statusQuotaWindow)
        ]
        for (old, new) in pairs {
            if defaults.object(forKey: new) == nil, let value = defaults.object(forKey: old) {
                defaults.set(value, forKey: new)
            }
        }
    }
}
