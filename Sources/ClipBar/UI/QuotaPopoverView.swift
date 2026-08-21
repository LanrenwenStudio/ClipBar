#if os(macOS)
import SwiftUI

struct QuotaPopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            header
            if !model.groupedAccounts.isEmpty {
                providerTabs
            }
            content
            footer
        }
        .padding(12)
        .frame(width: ClipBarTheme.popoverWidth)
    }
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("ClipBar")
                        .font(.system(size: 13, weight: .semibold))
                    ConnectionBadge(title: connectionText, color: connectionColor)
                }
                Text(headerSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(model.connection.isRefreshing ? 360 : 0))
                    .animation(
                        model.connection.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: model.connection.isRefreshing
                    )
            }
            .buttonStyle(.plain)
            .disabled(!model.settings.isConfigured || model.connection.isRefreshing)
            .help(L10n.t("刷新额度", "Refresh quotas"))
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }
    private var providerTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                ForEach(model.groupedAccounts, id: \.provider) { group in
                    ProviderTab(
                        provider: group.provider,
                        accountCount: group.rows.count,
                        isSelected: model.visibleProvider == group.provider,
                        action: { model.selectProvider(group.provider) }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
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
            VStack(spacing: 6) {
                ProviderSummaryCard(
                    provider: model.visibleProvider,
                    accountCount: model.visibleTabAccounts.count,
                    remaining: pooledRemaining
                )

                ViewThatFits(in: .vertical) {
                    VStack(spacing: 6) {
                        ForEach(model.visibleTabAccounts) { row in
                            AccountCard(row: row)
                        }
                    }
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(model.visibleTabAccounts) { row in
                                AccountCard(row: row)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: ClipBarTheme.popoverMaxListHeight)
                }
            }
            .id(model.visibleProvider)
            .transaction { $0.animation = nil }
        }
    }
    private var footer: some View {
        PopoverFooterBar(openSettings: model.openSettings)
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
        Task { await model.refresh(force: true) }
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
