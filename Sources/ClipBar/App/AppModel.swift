import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var settings: AppSettings
    var accounts: [AccountQuota] = []
    var connection: ConnectionState = .unconfigured
    var lastRefreshedAt: Date?
    var selectedProvider: QuotaProvider?
    var launchAtLoginStatus: LaunchAtLoginStatus
    var launchAtLoginError: String?
    var isSettingsPresented = false
    var popoverDismissalRequest = 0

    @ObservationIgnored
    private let store: SettingsStore
    @ObservationIgnored
    private var pollTask: Task<Void, Never>?
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    @ObservationIgnored
    private let launchAtLoginService: LaunchAtLoginService

    init(
        store: SettingsStore = SettingsStore(),
        launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService()
    ) {
        self.launchAtLoginService = launchAtLoginService
        self.store = store
        let loadedSettings = store.load()
        self.settings = loadedSettings
        self.connection = loadedSettings.isConfigured ? .idle : .unconfigured
        self.launchAtLoginStatus = launchAtLoginService.status
        self.launchAtLoginError = nil
        start()
    }

    var statusSegments: [StatusSegment] {
        StatusBarSummary.segments(from: accounts, settings: settings)
    }

    var statusTitle: String {
        switch connection {
        case .unconfigured:
            "CPA"
        case .failed:
            "CPA !"
        case .idle, .refreshing, .online:
            StatusBarSummary.title(from: statusSegments, fallback: "CPA")
        }
    }

    var statusAccessibilityLabel: String {
        switch connection {
        case .unconfigured:
            L10n.t("ClipBar 未配置", "ClipBar is not configured")
        case .refreshing:
            L10n.t("正在刷新额度", "Refreshing quotas")
        case .failed(let message):
            L10n.t("连接失败：\(message)", "Connection failed: \(message)")
        case .idle, .online:
            statusSegments.isEmpty
                ? L10n.t("还没有额度数据", "No quota data yet")
                : statusSegments.map(\.title).joined(separator: ", ")
        }
    }

    var lastRefreshText: String {
        guard let lastRefreshedAt else {
            return L10n.t("尚未刷新", "Not refreshed yet")
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: lastRefreshedAt)
    }

    var groupedAccounts: [(provider: QuotaProvider, rows: [AccountQuota])] {
        orderedPreferenceProviders.compactMap { provider in
            let rows = sortedAccounts(accounts.filter { $0.account.provider == provider })
            return rows.isEmpty ? nil : (provider, rows)
        }
    }

    var visibleProvider: QuotaProvider {
        if let selectedProvider, groupedAccounts.contains(where: { $0.provider == selectedProvider }) {
            return selectedProvider
        }
        return groupedAccounts.first?.provider ?? .codex
    }

    var visibleTabAccounts: [AccountQuota] {
        sortedAccounts(accounts.filter { $0.account.provider == visibleProvider })
    }

    var orderedPreferenceProviders: [QuotaProvider] {
        StatusBarSummary.orderedProviders(from: accounts, settings: settings)
    }

    var healthyCount: Int {
        accounts.filter { row in
            let isLocallyDisabled = settings.isAccountDisabled(statusKey: row.account.statusKey, serverDisabled: row.account.disabled)
            return !isLocallyDisabled && row.account.isRoutable && !row.snapshot.windows.contains(where: \.isExhausted)
        }.count
    }

    func selectProvider(_ provider: QuotaProvider) {
        selectedProvider = provider
    }

    func selectAccount(_ key: String) {
        if let provider = QuotaProvider(rawValue: key) {
            selectedProvider = provider
            return
        }
        if let row = accounts.first(where: { $0.account.statusKey == key }) {
            selectedProvider = row.account.provider
        }
    }

    func isStatusItemVisible(_ provider: QuotaProvider) -> Bool {
        !settings.hiddenStatusItemIDSet.contains(provider.rawValue)
    }

    func setStatusItemVisible(_ provider: QuotaProvider, visible: Bool) {
        var hidden = settings.hiddenStatusItemIDSet
        if visible {
            hidden.remove(provider.rawValue)
        } else {
            hidden.insert(provider.rawValue)
        }
        settings.hiddenStatusItemIDs = Array(hidden).sorted()
        persistPreferences()
    }

    func setHideEmptyStatusItems(_ value: Bool) {
        settings.hideEmptyStatusItems = value
        persistPreferences()
    }

    func setStatusQuotaWindow(_ window: StatusQuotaWindow) {
        settings.statusQuotaWindow = window
        persistPreferences()
    }

    func toggleAccountDisabled(_ row: AccountQuota) {
        let key = row.account.statusKey
        if settings.disabledAccountKeys.contains(key) {
            settings.disabledAccountKeys.removeAll { $0 == key }
        } else {
            settings.disabledAccountKeys.append(key)
        }
        persistPreferences()
    }

    func toggleAccountPinned(_ row: AccountQuota) {
        let key = row.account.statusKey
        if settings.pinnedAccountKeys.contains(key) {
            settings.pinnedAccountKeys.removeAll { $0 == key }
        } else {
            settings.pinnedAccountKeys.append(key)
        }
        persistPreferences()
    }

    func isAccountDisabled(_ row: AccountQuota) -> Bool {
        settings.isAccountDisabled(statusKey: row.account.statusKey, serverDisabled: row.account.disabled)
    }

    func isAccountPinned(_ row: AccountQuota) -> Bool {
        settings.isAccountPinned(statusKey: row.account.statusKey)
    }
    func isProviderHidden(_ provider: QuotaProvider) -> Bool {
        settings.isProviderHidden(provider)
    }

    func toggleProviderHidden(_ provider: QuotaProvider) {
        settings.toggleProviderHidden(provider)
        persistPreferences()
    }

    func setSortByRemainingQuota(_ value: Bool) {
        settings.sortByRemainingQuota = value
        persistPreferences()
    }

    func setLowQuotaAlertThreshold(_ value: Int) {
        settings.lowQuotaAlertThreshold = value
        persistPreferences()
    }

    func setEnableNotifications(_ value: Bool) {
        settings.enableNotifications = value
        if value {
            NotificationManager.shared.requestAuthorization()
        }
        persistPreferences()
    }
    func setAppTheme(_ theme: AppTheme) {
        settings.appTheme = theme
        persistPreferences()
    }


    func sortedAccounts(_ rows: [AccountQuota]) -> [AccountQuota] {
        rows.sorted { a, b in
            let aPinned = settings.isAccountPinned(statusKey: a.account.statusKey)
            let bPinned = settings.isAccountPinned(statusKey: b.account.statusKey)
            if aPinned != bPinned {
                return aPinned && !bPinned
            }

            let aDisabled = settings.isAccountDisabled(statusKey: a.account.statusKey, serverDisabled: a.account.disabled)
            let bDisabled = settings.isAccountDisabled(statusKey: b.account.statusKey, serverDisabled: b.account.disabled)
            if aDisabled != bDisabled {
                return !aDisabled && bDisabled
            }

            if settings.sortByRemainingQuota {
                let aPercent = a.snapshot.windows.compactMap(\.remainingPercent).first ?? -1
                let bPercent = b.snapshot.windows.compactMap(\.remainingPercent).first ?? -1
                if aPercent != bPercent {
                    return aPercent > bPercent
                }
            }
            return a.account.displayName.localizedCaseInsensitiveCompare(b.account.displayName) == .orderedAscending
        }
    }

    func moveStatusItems(from source: IndexSet, to destination: Int) {
        var order = orderedPreferenceProviders
        order.move(fromOffsets: source, toOffset: destination)
        settings.statusItemOrder = order.map(\.rawValue)
        persistPreferences()
    }

    func reorderProvider(from sourceID: String, to targetID: String) {
        guard let source = QuotaProvider(rawValue: sourceID),
              let target = QuotaProvider(rawValue: targetID),
              source != target else { return }
        var order = orderedPreferenceProviders
        guard let fromIndex = order.firstIndex(of: source),
              let toIndex = order.firstIndex(of: target) else { return }
        order.remove(at: fromIndex)
        let insertIndex = order.firstIndex(of: target) ?? order.endIndex
        order.insert(source, at: insertIndex)
        settings.statusItemOrder = order.map(\.rawValue)
        persistPreferences()
    }

    func openSettings() {
        refreshLaunchAtLoginStatus()
        isSettingsPresented = true
    }

    func closeSettings() {
        isSettingsPresented = false
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLoginService.status
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        guard enabled != launchAtLoginStatus.isRegistered else { return }

        do {
            try launchAtLoginService.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            launchAtLoginError = L10n.t(
                "无法设置登录时启动：\(error.localizedDescription)",
                "Could not change launch at login: \(error.localizedDescription)"
            )
        }
    }

    func saveSettings(_ next: AppSettings) {
        settings.baseURL = next.normalizedBaseURL
        settings.managementKey = next.normalizedManagementKey
        settings.refreshSeconds = next.clampedRefreshSeconds
        persistPreferences()
        popoverDismissalRequest += 1
        restartPolling()
    }

    func refresh() async {
        guard settings.isConfigured else {
            connection = .unconfigured
            accounts = []
            WidgetDataStore.shared.syncFrom(accounts: [], settings: settings, connection: .unconfigured)
            return
        }
        refreshTask?.cancel()
        let settings = settings
        connection = .refreshing
        refreshTask = Task {
            do {
                let rows = try await QuotaService(client: ManagementClient(settings: settings)).refresh()
                accounts = rows
                lastRefreshedAt = Date()
                connection = .online
                if selectedProvider == nil {
                    selectedProvider = rows.first?.account.provider
                }
                WidgetDataStore.shared.syncFrom(accounts: rows, settings: settings, connection: .online)
                NotificationManager.shared.checkAndNotify(accounts: rows, settings: settings)
                return
            } catch {
                guard !Task.isCancelled else { return }
                connection = .failed(error.localizedDescription)
                WidgetDataStore.shared.syncFrom(accounts: accounts, settings: settings, connection: .failed(error.localizedDescription))
            }
        }
        await refreshTask?.value
    }

    private func persistPreferences() {
        store.save(settings)
        WidgetDataStore.shared.syncFrom(accounts: accounts, settings: settings, connection: connection)
    }

    private func start() {
        restartPolling()
        Task { await refresh() }
    }

    private func restartPolling() {
        pollTask?.cancel()
        let seconds = settings.clampedRefreshSeconds
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                await self?.refresh()
            }
        }
    }
}
