import SwiftUI

struct AccountCard: View {
    let row: AccountQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(row.account.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if row.account.provider == .codex, let plan = planLabel {
                    Text(plan)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                statusChip
            }

            if let error = row.snapshot.error, row.snapshot.windows.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(row.snapshot.windows) { window in
                    QuotaBar(window: window)
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusChip: some View {
        Text(statusText)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var planLabel: String? {
        QuotaParser.formatMembership(row.snapshot.planType)
    }

    private var statusText: String {
        if row.account.disabled {
            return L10n.t("已禁用", "Disabled")
        }
        if row.account.unavailable {
            return L10n.t("不可用", "Unavailable")
        }
        if row.snapshot.windows.contains(where: \.isExhausted) {
            return L10n.t("用尽", "Empty")
        }
        if row.snapshot.windows.contains(where: \.isLow) {
            return L10n.t("偏低", "Low")
        }
        if row.snapshot.hasLiveData {
            return L10n.t("正常", "Ready")
        }
        return row.account.status
    }

    private var statusColor: Color {
        if row.account.disabled || row.account.unavailable || row.snapshot.windows.contains(where: \.isExhausted) {
            return .red
        }
        if row.snapshot.windows.contains(where: \.isLow) || row.snapshot.error != nil {
            return .orange
        }
        if row.snapshot.hasLiveData {
            return .green
        }
        return .secondary
    }
}
