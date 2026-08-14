import Foundation

struct SettingsStore {
    private enum Key {
        static let baseURL = "clipquota.baseURL"
        static let managementKey = "clipquota.managementKey"
        static let refreshSeconds = "clipquota.refreshSeconds"
        static let statusItemOrder = "clipquota.statusItemOrder"
        static let hiddenStatusItemIDs = "clipquota.hiddenStatusItemIDs"
        static let hideEmptyStatusItems = "clipquota.hideEmptyStatusItems"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
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
        return settings
    }

    func save(_ settings: AppSettings) {
        defaults.set(settings.normalizedBaseURL, forKey: Key.baseURL)
        defaults.set(settings.normalizedManagementKey, forKey: Key.managementKey)
        defaults.set(settings.clampedRefreshSeconds, forKey: Key.refreshSeconds)
        defaults.set(settings.statusItemOrder, forKey: Key.statusItemOrder)
        defaults.set(settings.hiddenStatusItemIDs, forKey: Key.hiddenStatusItemIDs)
        defaults.set(settings.hideEmptyStatusItems, forKey: Key.hideEmptyStatusItems)
    }
}
