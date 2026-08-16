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
            let rows = accounts.filter { $0.account.provider == provider }
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
        accounts.filter { $0.account.provider == visibleProvider }
    }

    var orderedPreferenceProviders: [QuotaProvider] {
        StatusBarSummary.orderedProviders(from: accounts, settings: settings)
    }

    var healthyCount: Int {
        accounts.filter { $0.account.isRoutable && !$0.snapshot.windows.contains(where: \.isExhausted) }.count
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

    func moveStatusItems(from source: IndexSet, to destination: Int) {
        var order = orderedPreferenceProviders
        order.move(fromOffsets: source, toOffset: destination)
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
        Task { await refresh() }
    }

    func refresh() async {
        guard settings.isConfigured else {
            connection = .unconfigured
            accounts = []
            return
        }
        refreshTask?.cancel()
        let settings = settings
        connection = .refreshing
        refreshTask = Task {
            do {
                let rows = try await QuotaService(client: ManagementClient(settings: settings)).refresh()
                guard !Task.isCancelled else { return }
                accounts = rows
                lastRefreshedAt = Date()
                connection = .online
                if selectedProvider == nil {
                    selectedProvider = rows.first?.account.provider
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                connection = .failed(error.localizedDescription)
            }
        }
        await refreshTask?.value
    }

    private func persistPreferences() {
        store.save(settings)
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
