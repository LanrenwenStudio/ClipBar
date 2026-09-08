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

enum StatusQuotaDisplay: String, CaseIterable, Identifiable, Sendable {
    case fiveHour = "5h"
    case weekly = "7d"
    case both = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveHour:
            L10n.t("5 小时额度", "5-hour quota")
        case .weekly:
            L10n.t("周额度", "Weekly quota")
        case .both:
            L10n.t("两者都显示", "Show both")
        }
    }
}

struct AppSettings: Equatable, Sendable {
    static let refreshIntervalPresets = [60, 180, 300, 600, 900]
    static let backendURL = "http://192.168.1.3:8081"
    static let backendAccessToken = "clipbar-kevin"

    var baseURL: String
    var managementKey: String
    var backendURL: String
    var backendAccessToken: String
    var refreshSeconds: Int
    var statusItemOrder: [String]
    var hiddenStatusItemIDs: [String]
    var hideEmptyStatusItems: Bool
    var statusQuotaWindow: StatusQuotaWindow
    var statusQuotaDisplay: StatusQuotaDisplay
    var statusQuotaDisplayOverrides: [String: StatusQuotaDisplay]
    var providerCustomColors: [String: String]
    var disabledAccountKeys: [String]
    var pinnedAccountKeys: [String]
    var sortByRemainingQuota: Bool
    var appTheme: AppTheme

    private static let defaultBaseURL = ""

    static let `default` = AppSettings(
        baseURL: Self.defaultBaseURL,
        managementKey: "",
        backendURL: Self.backendURL,
        backendAccessToken: Self.backendAccessToken,
        refreshSeconds: 300,
        statusItemOrder: [],
        hiddenStatusItemIDs: [],
        hideEmptyStatusItems: false,
        statusQuotaWindow: .fiveHour,
        statusQuotaDisplay: .fiveHour,
        statusQuotaDisplayOverrides: [:],
        providerCustomColors: [:],
        disabledAccountKeys: [],
        pinnedAccountKeys: [],
        sortByRemainingQuota: true,
        appTheme: .system
    )
    var isConfigured: Bool {
        usesBackend || (!normalizedBaseURL.isEmpty && !normalizedManagementKey.isEmpty)
    }

    var usesBackend: Bool {
        !normalizedBackendURL.isEmpty && !normalizedBackendAccessToken.isEmpty
    }

    var activeURL: String {
        usesBackend ? normalizedBackendURL : normalizedBaseURL
    }

    var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedManagementKey: String {
        managementKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedBackendURL: String {
        backendURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedBackendAccessToken: String {
        backendAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func statusQuotaDisplay(for provider: QuotaProvider) -> StatusQuotaDisplay {
        statusQuotaDisplayOverrides[provider.rawValue] ?? statusQuotaDisplay
    }

    func statusQuotaDisplayOverride(for provider: QuotaProvider) -> StatusQuotaDisplay? {
        statusQuotaDisplayOverrides[provider.rawValue]
    }

    func customColorHex(for provider: QuotaProvider) -> String? {
        providerCustomColors[provider.rawValue]
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
