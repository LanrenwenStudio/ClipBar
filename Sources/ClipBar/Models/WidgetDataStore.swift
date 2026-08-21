import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

final class WidgetDataStore: @unchecked Sendable {
    static let shared = WidgetDataStore()
    static let appGroupID = "group.com.lanrenwen.clipbar"
    private let snapshotKey = "clipbar.widget.snapshot"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    private var sharedContainerFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
            .appendingPathComponent("widget_snapshot.json")
    }

    init() {}

    func saveSnapshot(_ snapshot: ClipBarWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        if let shared = sharedDefaults {
            shared.set(data, forKey: snapshotKey)
        }
        UserDefaults.standard.set(data, forKey: snapshotKey)
        if let fileURL = sharedContainerFileURL {
            try? data.write(to: fileURL, options: .atomic)
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func loadSnapshot() -> ClipBarWidgetSnapshot {
        if let shared = sharedDefaults, let data = shared.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(ClipBarWidgetSnapshot.self, from: data) {
            return snapshot
        }
        if let fileURL = sharedContainerFileURL, let data = try? Data(contentsOf: fileURL),
           let snapshot = try? JSONDecoder().decode(ClipBarWidgetSnapshot.self, from: data) {
            return snapshot
        }
        if let data = UserDefaults.standard.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(ClipBarWidgetSnapshot.self, from: data) {
            return snapshot
        }
        return .empty
    }

    public func syncFrom(accounts: [AccountQuota], settings: AppSettings, connection: ConnectionState) {
        let ordered = StatusBarSummary.orderedProviders(from: accounts, settings: settings)
        var providerDataList: [ProviderWidgetData] = []

        for provider in ordered {
            let pAccounts = accounts.filter { $0.account.provider == provider }
            guard !pAccounts.isEmpty else { continue }

            let avgRemaining = StatusBarSummary.pooledRemaining(
                in: pAccounts,
                preferredWindow: settings.statusQuotaWindow,
                settings: settings
            )
            let healthyCount = pAccounts.filter { row in
                let isLocallyDisabled = settings.isAccountDisabled(statusKey: row.account.statusKey, serverDisabled: row.account.disabled)
                guard !isLocallyDisabled, !row.account.disabled, !row.account.unavailable, row.snapshot.error == nil else { return false }
                if let lowest = row.snapshot.lowestRemaining {
                    return lowest > 0.5
                }
                if let rem = row.snapshot.windows.compactMap(\.remainingPercent).first {
                    return rem > 0.5
                }
                return true
            }.count

            let statusText: String
            if let avg = avgRemaining {
                if QuotaDisplayScale.isExhausted(avg) {
                    statusText = "已耗尽"
                } else if QuotaDisplayScale.isLow(avg) {
                    statusText = "低额度"
                } else {
                    statusText = "正常"
                }
            } else {
                statusText = "正常"
            }

            var windows: [QuotaWindowSummary] = []
            let allWindows = pAccounts.flatMap(\.snapshot.windows)
            var labelGroups: [String: [QuotaWindow]] = [:]
            var orderedLabels: [String] = []
            for win in allWindows {
                let shortLabel = win.label
                    .replacingOccurrences(of: " (Rate Limit)", with: "")
                    .replacingOccurrences(of: " (Weekly)", with: "")
                if labelGroups[shortLabel] == nil {
                    labelGroups[shortLabel] = []
                    orderedLabels.append(shortLabel)
                }
                labelGroups[shortLabel]?.append(win)
            }

            for label in orderedLabels {
                guard let group = labelGroups[label], !group.isEmpty else { continue }
                let validRemainings = group.compactMap(\.remainingPercent)
                let avgPercent = validRemainings.isEmpty ? nil : (validRemainings.reduce(0, +) / Double(validRemainings.count))
                // Pick the earliest / nearest reset text among all accounts
                let earliestReset = group.compactMap(\.resetText).min { lhs, rhs in
                    parseResetDuration(lhs) < parseResetDuration(rhs)
                }
                windows.append(QuotaWindowSummary(
                    label: label,
                    remainingPercent: avgPercent,
                    resetText: earliestReset
                ))
            }
            providerDataList.append(ProviderWidgetData(
                providerRawValue: provider.rawValue,
                displayName: provider.displayName,
                remainingPercent: avgRemaining,
                accountCount: pAccounts.count,
                healthyCount: healthyCount,
                statusText: statusText,
                windows: Array(windows.prefix(2))
            ))
        }

        let overallRemaining = StatusBarSummary.pooledRemaining(
            in: accounts,
            preferredWindow: settings.statusQuotaWindow,
            settings: settings
        )

        let totalHealthy = accounts.filter { row in
            let isLocallyDisabled = settings.isAccountDisabled(statusKey: row.account.statusKey, serverDisabled: row.account.disabled)
            guard !isLocallyDisabled, !row.account.disabled, !row.account.unavailable, row.snapshot.error == nil else { return false }
            if let lowest = row.snapshot.lowestRemaining {
                return lowest > 0.5
            }
            if let rem = row.snapshot.windows.compactMap(\.remainingPercent).first {
                return rem > 0.5
            }
            return true
        }.count

        let connectionStr: String
        switch connection {
        case .online, .idle: connectionStr = "online"
        case .refreshing: connectionStr = "refreshing"
        case .failed(let err): connectionStr = "failed: \(err)"
        case .unconfigured: connectionStr = "unconfigured"
        }

        let snapshot = ClipBarWidgetSnapshot(
            lastUpdated: Date(),
            isConfigured: settings.isConfigured,
            connectionStatus: connectionStr,
            providers: providerDataList,
            topThreeProviders: Array(providerDataList.prefix(3)),
            overallRemaining: overallRemaining,
            totalAccounts: accounts.count,
            healthyAccounts: totalHealthy
        )
        saveSnapshot(snapshot)
    }
}
