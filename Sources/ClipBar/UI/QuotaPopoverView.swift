#if os(macOS)
import SwiftUI

struct QuotaPopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            if !model.groupedAccounts.isEmpty {
                providerTabs
            }
            Divider().opacity(0.7)
            content
            Divider().opacity(0.7)
            PopoverFooterBar(openSettings: model.openSettings)
        }
        .background(.regularMaterial)
        .tint(ClipBarTheme.brandColor(for: model.visibleProvider))
        .frame(width: ClipBarTheme.popoverWidth)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ClipBarTheme.brandColor(for: model.visibleProvider))
                .frame(height: 2)
                .animation(.easeInOut(duration: 0.2), value: model.visibleProvider)
        }
    }
    private var header: some View {
        HStack(alignment: .center, spacing: ClipBarTheme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ClipBarTheme.spacingS) {
                    Text("ClipBar")
                        .font(.headline)
                    ConnectionBadge(title: connectionText, color: connectionColor)
                }
                Text(headerSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: ClipBarTheme.spacingM)

            RefreshToolbarButton(
                isRefreshing: model.connection.isRefreshing,
                isEnabled: model.settings.isConfigured,
                action: refresh
            )
        }
        .padding(.horizontal, ClipBarTheme.horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var providerTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: ClipBarTheme.spacingS) {
                ForEach(model.groupedAccounts, id: \.provider) { group in
                    ProviderTab(
                        provider: group.provider,
                        accountCount: group.rows.count,
                        isSelected: model.visibleProvider == group.provider,
                        action: { model.selectProvider(group.provider) }
                    )
                }
            }
            .padding(.horizontal, ClipBarTheme.horizontalPadding)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var content: some View {
        if !model.settings.isConfigured {
            UnavailableStateView(
                title: L10n.t("还没有接上 CLIProxyAPI", "CLIProxyAPI is not connected"),
                detail: L10n.t("先填本地管理地址和密钥，再拉订阅额度。", "Add the local management URL and key to load subscription quotas."),
                systemImage: "plug",
                actionTitle: L10n.t("填写密钥", "Enter key"),
                action: model.openSettings
            )
        } else if model.accounts.isEmpty {
            switch model.connection {
            case .refreshing:
                ProgressView(L10n.t("正在读取账号…", "Loading accounts…"))
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 160)
            case .failed(let message):
                UnavailableStateView(
                    title: L10n.t("连不上管理接口", "Management API unreachable"),
                    detail: message,
                    systemImage: "exclamationmark.triangle"
                )
            default:
                UnavailableStateView(
                    title: L10n.t("没有订阅账号", "No subscription accounts"),
                    detail: L10n.t("确认 CLIProxyAPI 已启动，并且 auth 目录里有 Codex / Claude / Gemini / Antigravity 账号。", "Make sure CLIProxyAPI is running and has Codex, Claude, Gemini, or Antigravity auth files."),
                    systemImage: "person.3"
                )
            }
        } else {
            VStack(spacing: 0) {
                ProviderSummaryCard(
                    provider: model.visibleProvider,
                    accountCount: model.visibleTabAccounts.count,
                    remaining: pooledRemaining
                )
                Divider().padding(.horizontal, ClipBarTheme.horizontalPadding)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.visibleTabAccounts) { row in
                            if row.id != model.visibleTabAccounts.first?.id {
                                Divider().padding(.horizontal, ClipBarTheme.horizontalPadding)
                            }
                            AccountCard(row: row)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(height: accountsHeight)
            }
            .id(model.visibleProvider)
            .transaction { $0.animation = nil }
        }
    }

    private var accountsHeight: CGFloat {
        let height = model.visibleTabAccounts.reduce(CGFloat.zero) { partial, row in
            let windows = CGFloat(max(row.snapshot.windows.count, 1))
            return partial + 52.0 + windows * 38.0
        }
        return min(ClipBarTheme.popoverMaxListHeight, max(96.0, height))
    }

    private var headerSubtitle: String {
        switch model.connection {
        case .unconfigured:
            L10n.t("等待配置", "Waiting for setup")
        case .refreshing:
            L10n.t("刷新中…", "Refreshing…")
        case .failed(let message):
            message
        case .idle, .online:
            L10n.t(
                "更新于 \(model.lastRefreshText) · \(model.healthyCount)/\(model.accounts.count) 可用",
                "Updated \(model.lastRefreshText) · \(model.healthyCount)/\(model.accounts.count) ready"
            )
        }
    }

    private var connectionText: String {
        switch model.connection {
        case .unconfigured:
            L10n.t("未配置", "Not configured")
        case .refreshing:
            L10n.t("刷新中", "Refreshing")
        case .failed:
            L10n.t("连接失败", "Error")
        case .idle, .online:
            L10n.t("在线", "Online")
        }
    }

    private var connectionColor: Color {
        switch model.connection {
        case .unconfigured:
            .secondary
        case .refreshing:
            ClipBarTheme.accent
        case .failed:
            ClipBarTheme.danger
        case .idle, .online:
            ClipBarTheme.success
        }
    }

    private var pooledRemaining: Double? {
        StatusBarSummary.pooledRemaining(
            in: model.visibleTabAccounts,
            preferredWindow: model.settings.statusQuotaWindow
        )
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}

struct PopoverRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isSettingsPresented {
                SettingsView()
            } else {
                QuotaPopoverView()
            }
        }
    }
}
#endif
