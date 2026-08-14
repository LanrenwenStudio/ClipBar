import AppKit
import SwiftUI

struct QuotaPopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            if !model.groupedAccounts.isEmpty {
                providerTabs
                Divider()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .frame(width: 400, height: Self.popoverHeight)
    }

    private static var popoverHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        return min(visible - 28, max(760, visible * 0.82))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ClipQuota")
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.connection.isRefreshing || !model.settings.isConfigured)
            .accessibilityLabel(L10n.t("刷新额度", "Refresh quotas"))
        }
        .padding(12)
    }

    private var providerTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.groupedAccounts, id: \.provider) { group in
                    Button {
                        model.selectProvider(group.provider)
                    } label: {
                        HStack(spacing: 5) {
                            if let image = ProviderIcon.image(for: group.provider) {
                                Image(nsImage: image)
                                    .resizable()
                                    .frame(width: 13, height: 13)
                            }
                            Text(group.provider.displayName)
                            Text("\(group.rows.count)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            model.visibleProvider == group.provider
                                ? Color.accentColor.opacity(0.18)
                                : Color.primary.opacity(0.06),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    private var content: some View {
        Group {
            if !model.settings.isConfigured {
                placeholder(
                    title: L10n.t("还没有接上 CLIProxyAPI", "CLIProxyAPI is not connected"),
                    detail: L10n.t("先填本地管理地址和密钥，再拉订阅额度。", "Add the local management URL and key to load subscription quotas."),
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
                    placeholder(title: L10n.t("连不上管理接口", "Management API unreachable"), detail: message)
                default:
                    placeholder(
                        title: L10n.t("没有订阅账号", "No subscription accounts"),
                        detail: L10n.t("确认 CLIProxyAPI 已启动，并且 auth 目录里有 Codex / Claude / Gemini / Antigravity 账号。", "Make sure CLIProxyAPI is running and has Codex, Claude, Gemini, or Antigravity auth files.")
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Text(model.visibleProvider.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(model.visibleTabAccounts) { row in
                            AccountCard(row: row)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(L10n.t("设置", "Settings")) {
                model.openSettings()
            }
            Spacer()
            Button(L10n.t("退出", "Quit")) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
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
            L10n.t("更新于 \(model.lastRefreshText) · \(model.healthyCount)/\(model.accounts.count) 可用", "Updated \(model.lastRefreshText) · \(model.healthyCount)/\(model.accounts.count) ready")
        }
    }

    private func placeholder(
        title: String,
        detail: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: 160, alignment: .topLeading)
    }
}
