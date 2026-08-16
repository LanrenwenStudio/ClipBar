#if os(iOS)
import SwiftUI

struct ProviderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let provider: QuotaProvider

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerHeroCard
                    accountsList
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(provider.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成", "Done")) {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }

    private var accounts: [AccountQuota] {
        model.sortedAccounts(model.accounts.filter { $0.account.provider == provider })
    }

    private var headerHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProviderGlyph(provider: provider, size: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.title2.weight(.bold))
                    Text(L10n.t("共 \(accounts.count) 个已授权账号", "\(accounts.count) authorized accounts"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("有效平均剩余", "Active Avg Remaining"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ClipBarTheme.percentText(averageRemaining))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(ClipBarTheme.progressColor(for: provider, remaining: averageRemaining))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.t("健康状态", "Health Status"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(healthStatusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(healthStatusColor)
                }
            }

            Divider()

            Toggle(
                L10n.t("在主看板与概览中显示", "Show in Dashboard & Overview"),
                isOn: Binding(
                    get: { !model.isProviderHidden(provider) },
                    set: { _ in
                        triggerHaptic(.light)
                        model.toggleProviderHidden(provider)
                    }
                )
            )
            .font(.subheadline)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var accountsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("账号列表", "Accounts"))
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(accounts, id: \.account.statusKey) { row in
                let isPinned = model.isAccountPinned(row)
                let isLocallyDisabled = model.isAccountDisabled(row)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                        .foregroundStyle(ClipBarTheme.accent)
                                }
                                Text(accountTitle(row))
                                    .font(.subheadline.weight(.semibold))
                                if isLocallyDisabled {
                                    Text(L10n.t("已忽略", "Ignored"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(ClipBarTheme.warning)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(ClipBarTheme.warning.opacity(0.12), in: Capsule())
                                }
                            }
                            if let email = row.account.email, !email.isEmpty {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            if let plan = QuotaParser.formatMembership(row.snapshot.planType) {
                                Text(plan)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.primary.opacity(0.85))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06), in: Capsule())
                            }

                            Button {
                                triggerHaptic(.light)
                                model.toggleAccountPinned(row)
                            } label: {
                                Image(systemName: isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isPinned ? ClipBarTheme.accent : Color.secondary.opacity(0.7))
                                    .frame(width: 26, height: 26)
                                    .background(Color.primary.opacity(0.05), in: Circle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                triggerHaptic(.light)
                                model.toggleAccountDisabled(row)
                            } label: {
                                Image(systemName: isLocallyDisabled ? "eye.slash.fill" : "eye")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isLocallyDisabled ? ClipBarTheme.warning : Color.secondary.opacity(0.7))
                                    .frame(width: 26, height: 26)
                                    .background(Color.primary.opacity(0.05), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if row.snapshot.windows.isEmpty {
                        if let error = row.snapshot.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(ClipBarTheme.warning)
                        } else {
                            Text(L10n.t("无活跃额度窗口", "No active quota window"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(row.snapshot.windows) { window in
                            QuotaBar(window: window, tint: ClipBarTheme.progressColor(for: provider, remaining: window.remainingPercent))
                        }
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(isLocallyDisabled ? 0.55 : 1.0)
                .contextMenu {
                    Button {
                        model.toggleAccountPinned(row)
                    } label: {
                        Label(
                            isPinned ? L10n.t("取消置顶", "Unpin Account") : L10n.t("置顶此账号", "Pin Account to Top"),
                            systemImage: isPinned ? "pin.slash" : "pin"
                        )
                    }

                    Button {
                        model.toggleAccountDisabled(row)
                    } label: {
                        Label(
                            isLocallyDisabled ? L10n.t("恢复启用此账号", "Enable Account") : L10n.t("忽略/禁用此账号", "Ignore / Disable Account"),
                            systemImage: isLocallyDisabled ? "checkmark.circle" : "eye.slash"
                        )
                    }

                    Divider()

                    if let email = row.account.email, !email.isEmpty {
                        Button {
                            UIPasteboard.general.string = email
                        } label: {
                            Label(L10n.t("复制邮箱", "Copy Email"), systemImage: "doc.on.doc")
                        }
                    }

                    if let accountID = row.account.accountID ?? row.account.fileName {
                        Button {
                            UIPasteboard.general.string = accountID
                        } label: {
                            Label(L10n.t("复制账号标识", "Copy Account ID"), systemImage: "number")
                        }
                    }
                }
            }
        }
    }

    private func accountTitle(_ row: AccountQuota) -> String {
        let trimmed = row.account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let email = row.account.email, !email.isEmpty { return email }
        return row.account.statusKey
    }

    private var averageRemaining: Double? {
        StatusBarSummary.pooledRemaining(
            in: accounts,
            preferredWindow: model.settings.statusQuotaWindow,
            settings: model.settings
        )
    }
    private var healthStatusText: String {
        guard let avg = averageRemaining else { return L10n.t("未知", "Unknown") }
        if avg <= 0.5 { return L10n.t("已耗尽", "Exhausted") }
        if avg <= 20 { return L10n.t("额度紧张", "Low Quota") }
        return L10n.t("正常", "Normal")
    }

    private var healthStatusColor: Color {
        guard let avg = averageRemaining else { return .secondary }
        if avg <= 0.5 { return ClipBarTheme.danger }
        if avg <= 20 { return ClipBarTheme.warning }
        return ClipBarTheme.success
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
#endif
