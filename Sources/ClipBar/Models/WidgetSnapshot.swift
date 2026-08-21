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

    var nearestResetText: String? {
        let candidates = windows.compactMap(\.resetText).filter { !$0.isEmpty && $0 != "--" }
        return candidates.min { lhs, rhs in
            parseResetDuration(lhs) < parseResetDuration(rhs)
        }
    }
}

func parseResetDuration(_ text: String?) -> Double {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !text.isEmpty else {
        return .infinity
    }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: text) ?? ISO8601DateFormatter().date(from: text) {
        let diff = date.timeIntervalSinceNow
        return diff > 0 ? diff : 0
    }

    var total: Double = 0
    var matched = false
    let parts = text.split(separator: " ")
    for part in parts {
        let str = String(part)
        if str.contains(":") {
            let timeComponents = str.split(separator: ":")
            if timeComponents.count == 2, let h = Double(timeComponents[0]), let m = Double(timeComponents[1]) {
                total += h * 3600 + m * 60
                matched = true
            }
        } else if str.hasSuffix("d") || str.hasSuffix("天"), let v = Double(str.dropLast()) {
            total += v * 86400
            matched = true
        } else if str.hasSuffix("h") || str.hasSuffix("小时"), let v = Double(str.dropLast()) {
            total += v * 3600
            matched = true
        } else if str.hasSuffix("m") || str.hasSuffix("分") || str.hasSuffix("分钟"), let v = Double(str.dropLast()) {
            total += v * 60
            matched = true
        } else if str.hasSuffix("s") || str.hasSuffix("秒"), let v = Double(str.dropLast()) {
            total += v
            matched = true
        }
    }
    return matched ? total : .infinity
}

enum WidgetFormatter {
    static var isChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }

    static func freshnessText(from date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))
        if elapsed < 60 {
            return isChinese ? "刚刚" : "Just now"
        }
        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return isChinese ? "\(minutes)分钟前" : "\(minutes)m ago"
        }
        let hours = Int(elapsed / 3600)
        if hours < 24 {
            return isChinese ? "\(hours)小时前" : "\(hours)h ago"
        }
        let days = Int(elapsed / 86400)
        return isChinese ? "\(days)天前" : "\(days)d ago"
    }

    static func formatResetText(_ raw: String?, referenceDate: Date = Date()) -> String {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text != "--" else {
            return "--"
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let targetDate = iso.date(from: text) ?? ISO8601DateFormatter().date(from: text) {
            return formatTargetDate(targetDate, relativeTo: referenceDate)
        }

        let duration = parseResetDuration(text)
        if duration != .infinity && duration >= 0 {
            let targetDate = referenceDate.addingTimeInterval(duration)
            return formatTargetDate(targetDate, relativeTo: referenceDate)
        }

        return text
    }

    private static func humanPeriod(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<6:
            return "凌晨"
        case 6..<12:
            return "上午"
        case 12..<18:
            return "下午"
        default:
            return "晚上"
        }
    }

    private static func formatTargetDate(_ targetDate: Date, relativeTo now: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: targetDate)

        if !isChinese {
            if calendar.isDate(targetDate, inSameDayAs: now) {
                return "Today \(timeStr)"
            } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(targetDate, inSameDayAs: tomorrow) {
                return "Tomorrow \(timeStr)"
            } else {
                let startOfNow = calendar.startOfDay(for: now)
                let startOfTarget = calendar.startOfDay(for: targetDate)
                let diffDays = calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0
                if diffDays > 1 {
                    return "\(diffDays)d \(timeStr)"
                }
                return timeStr
            }
        }

        let period = humanPeriod(for: targetDate)
        if calendar.isDate(targetDate, inSameDayAs: now) {
            return "今天\(period) \(timeStr)"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(targetDate, inSameDayAs: tomorrow) {
            return "明天\(period) \(timeStr)"
        } else {
            let startOfNow = calendar.startOfDay(for: now)
            let startOfTarget = calendar.startOfDay(for: targetDate)
            let diffDays = calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0
            if diffDays == 2 {
                return "后天\(period) \(timeStr)"
            } else if diffDays > 2 {
                return "\(diffDays)天后 \(timeStr)"
            } else {
                return "今天\(period) \(timeStr)"
            }
        }
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

    enum CodingKeys: String, CodingKey {
        case lastUpdated, isConfigured, connectionStatus, providers, topThreeProviders, overallRemaining, totalAccounts, healthyAccounts
    }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        isConfigured = try container.decode(Bool.self, forKey: .isConfigured)
        connectionStatus = try container.decode(String.self, forKey: .connectionStatus)
        providers = try container.decode([ProviderWidgetData].self, forKey: .providers)
        topThreeProviders = try container.decode([ProviderWidgetData].self, forKey: .topThreeProviders)
        overallRemaining = try container.decodeIfPresent(Double.self, forKey: .overallRemaining)
        totalAccounts = try container.decode(Int.self, forKey: .totalAccounts)
        healthyAccounts = try container.decode(Int.self, forKey: .healthyAccounts)
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
                QuotaWindowSummary(label: "周额度", remainingPercent: 84.0, resetText: "周一")
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
                QuotaWindowSummary(label: "周额度", remainingPercent: 60.0, resetText: "周一")
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
