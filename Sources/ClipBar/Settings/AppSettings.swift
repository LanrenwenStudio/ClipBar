import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            L10n.t("跟随系统", "System")
        case .light:
            L10n.t("浅色模式", "Light")
        case .dark:
            L10n.t("深色模式", "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct AppSettings: Equatable, Sendable {
    static let refreshIntervalPresets = [60, 180, 300, 600, 900]

    var baseURL: String
    var managementKey: String
    var refreshSeconds: Int
    var statusItemOrder: [String]
    var hiddenStatusItemIDs: [String]
    var hideEmptyStatusItems: Bool
    var statusQuotaWindow: StatusQuotaWindow
    var disabledAccountKeys: [String]
    var pinnedAccountKeys: [String]
    var sortByRemainingQuota: Bool
    var appTheme: AppTheme

    static let `default` = AppSettings(
        baseURL: "http://127.0.0.1:8317",
        managementKey: "",
        refreshSeconds: 300,
        statusItemOrder: [],
        hiddenStatusItemIDs: [],
        hideEmptyStatusItems: false,
        statusQuotaWindow: .fiveHour,
        disabledAccountKeys: [],
        pinnedAccountKeys: [],
        sortByRemainingQuota: true,
        appTheme: .system
    )
    var isConfigured: Bool {
        !normalizedBaseURL.isEmpty && !normalizedManagementKey.isEmpty
    }

    var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedManagementKey: String {
        managementKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var clampedRefreshSeconds: Int {
        Self.nearestRefreshInterval(to: refreshSeconds)
    }

    static func nearestRefreshInterval(to seconds: Int) -> Int {
        refreshIntervalPresets.min(by: { abs($0 - seconds) < abs($1 - seconds) }) ?? 300
    }

    var hiddenStatusItemIDSet: Set<String> {
        Set(hiddenStatusItemIDs)
    }

    var disabledAccountKeySet: Set<String> {
        Set(disabledAccountKeys)
    }

    var pinnedAccountKeySet: Set<String> {
        Set(pinnedAccountKeys)
    }
    func isProviderHidden(_ provider: QuotaProvider) -> Bool {
        hiddenStatusItemIDSet.contains(provider.rawValue)
    }

    mutating func toggleProviderHidden(_ provider: QuotaProvider) {
        if isProviderHidden(provider) {
            hiddenStatusItemIDs.removeAll { $0 == provider.rawValue }
        } else {
            hiddenStatusItemIDs.append(provider.rawValue)
        }
    }

    func isAccountDisabled(statusKey: String, serverDisabled: Bool) -> Bool {
        serverDisabled || disabledAccountKeySet.contains(statusKey)
    }

    func isAccountPinned(statusKey: String) -> Bool {
        pinnedAccountKeySet.contains(statusKey)
    }
}
