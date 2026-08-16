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
