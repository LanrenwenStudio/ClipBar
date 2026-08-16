import Foundation

struct StatusSegment: Identifiable, Equatable, Sendable {
    var id: String
    var provider: QuotaProvider
    var remaining: Double?
    var accountCount: Int

    var percent: Int? {
        remaining.map { Int($0.rounded()) }
    }

    var percentText: String {
        if let percent { return "\(percent)%" }
        return "--"
    }

    var title: String {
        "\(provider.displayName) \(percentText)"
    }
}

enum StatusBarSummary {
    static func orderedProviders(
        from accounts: [AccountQuota],
        settings: AppSettings
    ) -> [QuotaProvider] {
        let present = QuotaProvider.allCases.filter { provider in
            accounts.contains { $0.account.provider == provider }
        }
        let presentSet = Set(present)
        var seen = Set<QuotaProvider>()
        var ordered: [QuotaProvider] = []
        for raw in settings.statusItemOrder {
            guard let provider = QuotaProvider(rawValue: raw),
                  presentSet.contains(provider),
                  seen.insert(provider).inserted
            else { continue }
            ordered.append(provider)
        }
        for provider in present where seen.insert(provider).inserted {
            ordered.append(provider)
        }
        return ordered
    }

    static func enabledAccounts(in rows: [AccountQuota]) -> [AccountQuota] {
        rows.filter { !$0.account.disabled }
    }

    static func segments(from accounts: [AccountQuota], settings: AppSettings) -> [StatusSegment] {
        let hidden = settings.hiddenStatusItemIDSet
        return orderedProviders(from: accounts, settings: settings).compactMap { provider in
            guard !hidden.contains(provider.rawValue) else { return nil }
            let rows = enabledAccounts(in: accounts.filter { $0.account.provider == provider })
            guard !rows.isEmpty else { return nil }
            let remaining = pooledRemaining(in: rows, preferredWindow: settings.statusQuotaWindow)
            if settings.hideEmptyStatusItems, let remaining, remaining <= 0 {
                return nil
            }
            return StatusSegment(
                id: provider.rawValue,
                provider: provider,
                remaining: remaining,
                accountCount: rows.count
            )
        }
    }

    /// Remaining / capacity across enabled accounts only.
    /// Each enabled account is one unit. Remaining is the average of its
    /// selected quota window when available, falling back to the other window when needed.
    static func pooledRemaining(
        in rows: [AccountQuota],
        preferredWindow: StatusQuotaWindow = .fiveHour
    ) -> Double? {
        let enabled = enabledAccounts(in: rows)
        guard !enabled.isEmpty else { return nil }
        var remainingUnits = 0.0
        for row in enabled {
            let percents = selectedPercents(in: row.snapshot.windows, preferredWindow: preferredWindow)
            guard !percents.isEmpty else { continue }
            remainingUnits += percents.reduce(0, +) / Double(percents.count) / 100
        }
        return remainingUnits / Double(enabled.count) * 100
    }

    private static func selectedPercents(
        in windows: [QuotaWindow],
        preferredWindow: StatusQuotaWindow
    ) -> [Double] {
        let preferredIDs: Set<String>
        let fallbackIDs: Set<String>
        switch preferredWindow {
        case .fiveHour:
            preferredIDs = ["5h", "five-hour", "5-hour"]
            fallbackIDs = ["7d", "week", "weekly", "seven-day"]
        case .weekly:
            preferredIDs = ["7d", "week", "weekly", "seven-day"]
            fallbackIDs = ["5h", "five-hour", "5-hour"]
        }

        if let preferred = windows.first(where: { preferredIDs.contains($0.id) })?.remainingPercent {
            return [preferred]
        }
        if let fallback = windows.first(where: { fallbackIDs.contains($0.id) })?.remainingPercent {
            return [fallback]
        }
        return windows.compactMap(\.remainingPercent)
    }

    static func title(from segments: [StatusSegment], fallback: String) -> String {
        segments.isEmpty ? fallback : segments.map(\.title).joined(separator: "  ")
    }
}
