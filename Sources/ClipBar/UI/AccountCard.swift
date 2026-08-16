import SwiftUI

struct AccountCard: View {
    @Environment(AppModel.self) private var model
    let row: AccountQuota

    var body: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.spacingS) {
            header

            if let error = row.snapshot.error, row.snapshot.windows.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(ClipBarTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(row.snapshot.windows) { window in
                    QuotaBar(window: window, tint: ClipBarTheme.progressColor(for: row.account.provider, remaining: window.remainingPercent))
                }
            }
        }
        .padding(.horizontal, ClipBarTheme.horizontalPadding)
        .padding(.vertical, 8)
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
                    copyToClipboard(email)
                } label: {
                    Label(L10n.t("复制邮箱", "Copy Email"), systemImage: "doc.on.doc")
                }
            }

            if let accountID = row.account.accountID ?? row.account.fileName {
                Button {
                    copyToClipboard(accountID)
                } label: {
                    Label(L10n.t("复制账号标识", "Copy Account ID"), systemImage: "number")
                }
            }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.headerSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: ClipBarTheme.spacingS) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(primaryTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                if isLocallyDisabled {
                    Text(L10n.t("已忽略", "Ignored"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                Spacer(minLength: ClipBarTheme.spacingS)
                if let planLabel {
                    Text(planLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let subtitleText {
                Text(subtitleText)
                    .font(.footnote)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }
        }
    }

    private var primaryTitle: String {
        if let friendlyName {
            return friendlyName
        }
        return row.account.displayName
    }

    private var subtitleText: String? {
        if let email = row.account.email, !email.isEmpty, email != primaryTitle {
            return showsStatusLine ? "\(email) · \(statusText)" : email
        }
        return showsStatusLine ? statusText : nil
    }

    private var showsStatusLine: Bool {
        row.account.disabled
            || row.account.unavailable
            || row.snapshot.windows.contains(where: \.isExhausted)
            || row.snapshot.windows.contains(where: \.isLow)
            || row.snapshot.error != nil
            || !row.snapshot.hasLiveData
    }

    private var planLabel: String? {
        QuotaParser.formatMembership(row.snapshot.planType)
    }

    private var friendlyName: String? {
        guard let name = trimmedName else { return nil }
        if name == row.account.email { return nil }
        if name.hasSuffix(".json") || name.contains("@") { return nil }
        return name
    }

    private var trimmedName: String? {
        let name = row.account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private var statusText: String {
        if isLocallyDisabled {
            return L10n.t("已忽略", "Ignored")
        }
        if row.account.disabled {
            return L10n.t("已禁用", "Disabled")
        }
        if row.account.unavailable {
            return L10n.t("不可用", "Unavailable")
        }
        if row.snapshot.windows.contains(where: \.isExhausted) {
            return L10n.t("额度用尽", "Quota empty")
        }
        if row.snapshot.windows.contains(where: \.isLow) {
            return L10n.t("额度偏低", "Quota low")
        }
        if let error = row.snapshot.error {
            return error
        }
        if row.snapshot.hasLiveData {
            return L10n.t("正常", "Ready")
        }
        return row.account.status
    }

    private var subtitleColor: Color {
        if isLocallyDisabled || row.account.disabled || row.account.unavailable || row.snapshot.windows.contains(where: \.isExhausted) {
            return Color.secondary.opacity(0.65)
        }
        return .secondary
    }

    private var isPinned: Bool {
        model.isAccountPinned(row)
    }

    private var isLocallyDisabled: Bool {
        model.isAccountDisabled(row)
    }

    private func copyToClipboard(_ text: String) {
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#else
        UIPasteboard.general.string = text
#endif
    }
}

#Preview {
    AccountCard(
        row: AccountQuota(
            account: AuthAccount(
                id: "1",
                authIndex: "0",
                name: "Work",
                email: "ada@lanrenwen.com",
                provider: .codex,
                providerRaw: "codex",
                status: "active",
                statusMessage: nil,
                disabled: false,
                unavailable: false,
                accountID: nil,
                projectID: nil,
                fileName: nil
            ),
            snapshot: QuotaSnapshot(
                planType: "plus",
                windows: [
                    QuotaWindow(id: "5h", label: "5h", remainingPercent: 89, resetText: "2h 14m"),
                    QuotaWindow(id: "7d", label: "7d", remainingPercent: 64, resetText: "4d"),
                ],
                error: nil
            )
        )
    )
    .environment(AppModel())
    .frame(width: 360)
}
