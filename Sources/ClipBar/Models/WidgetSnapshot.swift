import Foundation

struct QuotaWindowSummary: Codable, Identifiable, Sendable {
    var id: String { label }
    let label: String
    let remainingPercent: Double?
    let resetText: String?

    init(label: String, remainingPercent: Double?, resetText: String?) {
        self.label = label
        self.remainingPercent = remainingPercent
        self.resetText = resetText
    }
}

struct ProviderWidgetData: Codable, Identifiable, Sendable {
    var id: String { providerRawValue }
    let providerRawValue: String
    let displayName: String
    let remainingPercent: Double?
    let accountCount: Int
    let healthyCount: Int
    let statusText: String
    let windows: [QuotaWindowSummary]

    init(
        providerRawValue: String,
        displayName: String,
        remainingPercent: Double?,
        accountCount: Int,
        healthyCount: Int,
        statusText: String,
        windows: [QuotaWindowSummary]
    ) {
        self.providerRawValue = providerRawValue
        self.displayName = displayName
        self.remainingPercent = remainingPercent
        self.accountCount = accountCount
        self.healthyCount = healthyCount
        self.statusText = statusText
        self.windows = windows
    }

    var provider: QuotaProvider {
        QuotaProvider(rawValue: providerRawValue) ?? .unknown
    }
}

struct ClipBarWidgetSnapshot: Codable, Sendable {
    let lastUpdated: Date
    let isConfigured: Bool
    let connectionStatus: String
    let providers: [ProviderWidgetData]
    let topThreeProviders: [ProviderWidgetData]
    let overallRemaining: Double?
    let totalAccounts: Int
    let healthyAccounts: Int

    init(
        lastUpdated: Date,
        isConfigured: Bool,
        connectionStatus: String,
        providers: [ProviderWidgetData],
        topThreeProviders: [ProviderWidgetData],
        overallRemaining: Double?,
        totalAccounts: Int,
        healthyAccounts: Int
    ) {
        self.lastUpdated = lastUpdated
        self.isConfigured = isConfigured
        self.connectionStatus = connectionStatus
        self.providers = providers
        self.topThreeProviders = topThreeProviders
        self.overallRemaining = overallRemaining
        self.totalAccounts = totalAccounts
        self.healthyAccounts = healthyAccounts
    }

    static var preview: ClipBarWidgetSnapshot {
        let claude = ProviderWidgetData(
            providerRawValue: "claude",
            displayName: "Claude",
            remainingPercent: 88.0,
            accountCount: 3,
            healthyCount: 3,
            statusText: "充足",
            windows: [
                QuotaWindowSummary(label: "5h 限制", remainingPercent: 92.0, resetText: "3h"),
                QuotaWindowSummary(label: "7d 周额度", remainingPercent: 84.0, resetText: "周一")
            ]
        )
        let codex = ProviderWidgetData(
            providerRawValue: "codex",
            displayName: "Codex",
            remainingPercent: 65.0,
            accountCount: 2,
            healthyCount: 2,
            statusText: "正常",
            windows: [
                QuotaWindowSummary(label: "5h 限制", remainingPercent: 70.0, resetText: "1h"),
                QuotaWindowSummary(label: "7d 周额度", remainingPercent: 60.0, resetText: "周一")
            ]
        )
        let gemini = ProviderWidgetData(
            providerRawValue: "geminiCLI",
            displayName: "Gemini",
            remainingPercent: 42.0,
            accountCount: 2,
            healthyCount: 1,
            statusText: "正常",
            windows: [
                QuotaWindowSummary(label: "Pro 模型桶", remainingPercent: 42.0, resetText: "明日"),
                QuotaWindowSummary(label: "Flash 模型桶", remainingPercent: 95.0, resetText: "明日")
            ]
        )
        let antigravity = ProviderWidgetData(
            providerRawValue: "antigravity",
            displayName: "Antigravity",
            remainingPercent: 18.0,
            accountCount: 1,
            healthyCount: 0,
            statusText: "低额度",
            windows: [
                QuotaWindowSummary(label: "日限额", remainingPercent: 18.0, resetText: "00:00")
            ]
        )

        return ClipBarWidgetSnapshot(
            lastUpdated: Date(),
            isConfigured: true,
            connectionStatus: "已连接",
            providers: [claude, codex, gemini, antigravity],
            topThreeProviders: [claude, codex, gemini],
            overallRemaining: 65.0,
            totalAccounts: 8,
            healthyAccounts: 6
        )
    }

    static var empty: ClipBarWidgetSnapshot {
        ClipBarWidgetSnapshot(
            lastUpdated: Date(),
            isConfigured: false,
            connectionStatus: "未连接",
            providers: [],
            topThreeProviders: [],
            overallRemaining: nil,
            totalAccounts: 0,
            healthyAccounts: 0
        )
    }
}
