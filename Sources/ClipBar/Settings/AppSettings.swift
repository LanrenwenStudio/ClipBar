import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Sendable, Codable {
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

enum StatusQuotaDisplay: String, CaseIterable, Identifiable, Sendable, Codable {
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

enum QuotaConnectionMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case direct = "direct"
    case plugin = "plugin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .direct:
            L10n.t("CLIProxyAPI 直连", "Direct CLIProxyAPI")
        case .plugin:
            L10n.t("CLIProxyAPI Quota 插件", "CLIProxyAPI quota plugin")
        }
    }

    var description: String {
        switch self {
        case .direct:
            L10n.t(
                "由 AccessDeck 通过 CLIProxyAPI 管理接口读取账号并探测额度。",
                "AccessDeck reads auth entries and probes quotas through the CLIProxyAPI management API."
            )
        case .plugin:
            L10n.t(
                "读取 CLIProxyAPI 的 clipbar-quota 插件；需要先在 CPA 中安装并启用插件。",
                "Reads the clipbar-quota plugin; install and enable it in CPA first."
            )
        }
    }

    var systemImage: String {
        switch self {
        case .direct: "arrow.left.arrow.right"
        case .plugin: "puzzlepiece.extension"
        }
    }
}

struct AppSettings: Equatable, Sendable, Codable {
    static let refreshIntervalPresets = [60, 180, 300, 600, 900]

    var baseURL: String
    var managementKey: String
    var connectionMode: QuotaConnectionMode
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
        connectionMode: .direct,
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

    init(
        baseURL: String,
        managementKey: String,
        connectionMode: QuotaConnectionMode,
        refreshSeconds: Int,
        statusItemOrder: [String],
        hiddenStatusItemIDs: [String],
        hideEmptyStatusItems: Bool,
        statusQuotaWindow: StatusQuotaWindow,
        statusQuotaDisplay: StatusQuotaDisplay,
        statusQuotaDisplayOverrides: [String: StatusQuotaDisplay],
        providerCustomColors: [String: String],
        disabledAccountKeys: [String],
        pinnedAccountKeys: [String],
        sortByRemainingQuota: Bool,
        appTheme: AppTheme
    ) {
        self.baseURL = baseURL
        self.managementKey = managementKey
        self.connectionMode = connectionMode
        self.refreshSeconds = refreshSeconds
        self.statusItemOrder = statusItemOrder
        self.hiddenStatusItemIDs = hiddenStatusItemIDs
        self.hideEmptyStatusItems = hideEmptyStatusItems
        self.statusQuotaWindow = statusQuotaWindow
        self.statusQuotaDisplay = statusQuotaDisplay
        self.statusQuotaDisplayOverrides = statusQuotaDisplayOverrides
        self.providerCustomColors = providerCustomColors
        self.disabledAccountKeys = disabledAccountKeys
        self.pinnedAccountKeys = pinnedAccountKeys
        self.sortByRemainingQuota = sortByRemainingQuota
        self.appTheme = appTheme
    }

    var isConfigured: Bool {
        !normalizedBaseURL.isEmpty && !normalizedManagementKey.isEmpty
    }

    var activeURL: String {
        normalizedBaseURL
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

    // Credentials are deliberately excluded from Codable. They are stored in
    // SettingsSecretStore and must never enter an iCloud KVS payload.
    private enum CodingKeys: String, CodingKey {
        case baseURL
        case connectionMode
        case refreshSeconds
        case statusItemOrder
        case hiddenStatusItemIDs
        case hideEmptyStatusItems
        case statusQuotaWindow
        case statusQuotaDisplay
        case statusQuotaDisplayOverrides
        case providerCustomColors
        case disabledAccountKeys
        case pinnedAccountKeys
        case sortByRemainingQuota
        case appTheme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            baseURL: try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "",
            managementKey: "",
            connectionMode: try container.decodeIfPresent(QuotaConnectionMode.self, forKey: .connectionMode) ?? .direct,
            refreshSeconds: try container.decodeIfPresent(Int.self, forKey: .refreshSeconds) ?? 300,
            statusItemOrder: try container.decodeIfPresent([String].self, forKey: .statusItemOrder) ?? [],
            hiddenStatusItemIDs: try container.decodeIfPresent([String].self, forKey: .hiddenStatusItemIDs) ?? [],
            hideEmptyStatusItems: try container.decodeIfPresent(Bool.self, forKey: .hideEmptyStatusItems) ?? false,
            statusQuotaWindow: try container.decodeIfPresent(StatusQuotaWindow.self, forKey: .statusQuotaWindow) ?? .fiveHour,
            statusQuotaDisplay: try container.decodeIfPresent(StatusQuotaDisplay.self, forKey: .statusQuotaDisplay) ?? .fiveHour,
            statusQuotaDisplayOverrides: try container.decodeIfPresent([String: StatusQuotaDisplay].self, forKey: .statusQuotaDisplayOverrides) ?? [:],
            providerCustomColors: try container.decodeIfPresent([String: String].self, forKey: .providerCustomColors) ?? [:],
            disabledAccountKeys: try container.decodeIfPresent([String].self, forKey: .disabledAccountKeys) ?? [],
            pinnedAccountKeys: try container.decodeIfPresent([String].self, forKey: .pinnedAccountKeys) ?? [],
            sortByRemainingQuota: try container.decodeIfPresent(Bool.self, forKey: .sortByRemainingQuota) ?? true,
            appTheme: try container.decodeIfPresent(AppTheme.self, forKey: .appTheme) ?? .system
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(connectionMode, forKey: .connectionMode)
        try container.encode(refreshSeconds, forKey: .refreshSeconds)
        try container.encode(statusItemOrder, forKey: .statusItemOrder)
        try container.encode(hiddenStatusItemIDs, forKey: .hiddenStatusItemIDs)
        try container.encode(hideEmptyStatusItems, forKey: .hideEmptyStatusItems)
        try container.encode(statusQuotaWindow, forKey: .statusQuotaWindow)
        try container.encode(statusQuotaDisplay, forKey: .statusQuotaDisplay)
        try container.encode(statusQuotaDisplayOverrides, forKey: .statusQuotaDisplayOverrides)
        try container.encode(providerCustomColors, forKey: .providerCustomColors)
        try container.encode(disabledAccountKeys, forKey: .disabledAccountKeys)
        try container.encode(pinnedAccountKeys, forKey: .pinnedAccountKeys)
        try container.encode(sortByRemainingQuota, forKey: .sortByRemainingQuota)
        try container.encode(appTheme, forKey: .appTheme)
    }
}
