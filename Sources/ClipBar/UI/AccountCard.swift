import SwiftUI

struct AccountCard: View {
    @Environment(AppModel.self) private var model
    let row: AccountQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if let error = row.snapshot.error, row.snapshot.windows.isEmpty {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(ClipBarTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 4) {
                    ForEach(row.snapshot.windows) { window in
                        QuotaBar(window: window, tint: ClipBarTheme.progressColor(for: row.account.provider, remaining: window.remainingPercent))
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
        )
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
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                }
                Text(primaryTitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                if isLocallyDisabled {
                    Text(L10n.t("已忽略", "Ignored"))
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                Spacer(minLength: 4)
                if let planLabel {
                    Text(planLabel)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.primary.opacity(0.05)))
                        .lineLimit(1)
                }
            }

            if let subtitleText {
                Text(subtitleText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
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
                    QuotaWindow(id: "7d", label: "周额度", remainingPercent: 64, resetText: "4d"),
                ],
                error: nil
            )
        )
    )
    .environment(AppModel())
    .frame(width: 360)
}
