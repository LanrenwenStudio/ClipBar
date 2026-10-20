import SwiftUI

struct ProviderSummaryCard: View {
    let provider: QuotaProvider
    let accountCount: Int
    let remaining: Double?
    let weeklyRemaining: Double?
    var customHex: String? = nil
    var isHiddenFromMenuBar: Bool = false
    var onToggleVisibility: (() -> Void)? = nil
    @State private var showingSchedulerSheet = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                ProviderGlyph(provider: provider, size: 12)
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(L10n.t("\(accountCount) 个账号", "\(accountCount) accounts"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if isHiddenFromMenuBar {
                    Button(action: { onToggleVisibility?() }) {
                        HStack(spacing: 2.5) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 8.5))
                            Text(L10n.t("已在状态栏隐藏", "Hidden in menu bar"))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(AccessDeckTheme.warning)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(AccessDeckTheme.warning.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("点击重新在状态栏显示此渠道", "Click to show this channel in menu bar"))
                }
                Spacer(minLength: 4)
                Text(AccessDeckTheme.percentText(remaining))
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(percentColor)
            }

            quotaBar(for: remaining, color: percentColor)

            if let weeklyRemaining {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.t("周额度", "Weekly quota"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(AccessDeckTheme.percentText(weeklyRemaining))
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(weeklyColor)
                }
                quotaBar(for: weeklyRemaining, color: weeklyColor)
            }

            if provider == .codex {
                Divider().opacity(0.3)
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(AccessDeckTheme.brandColor(for: .codex))
                    Text(L10n.t("Plus 额度智能调度", "Plus Quota Scheduler"))
                        .font(.system(size: 9.5, weight: .medium))
                    Spacer()
                    Button(action: { showingSchedulerSheet = true }) {
                        HStack(spacing: 2) {
                            Text(L10n.t("查看计划与记录", "View Plan & Logs"))
                                .font(.system(size: 9.5, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(AccessDeckTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .sheet(isPresented: $showingSchedulerSheet) {
                    CodexSchedulerDetailView()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func quotaBar(for value: Double?, color: Color) -> some View {
        let percent = max(0, min(100, value ?? 0))
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                // 底轨：极细轻量线条（3.5pt 带来精致高级感）
                RoundedRectangle(cornerRadius: 1.75, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 3.5)

                // 填充层：细腻平滑条
                if percent > 0 {
                    RoundedRectangle(cornerRadius: 1.75, style: .continuous)
                        .fill(color)
                        .frame(width: max(2, width * CGFloat(percent / 100.0)), height: 3.5)
                }
            }
            .frame(height: 3.5, alignment: .center)
        }
        .frame(height: 3.5)
        .accessibilityHidden(true)
    }

    private func fill(for value: Double?) -> CGFloat {
        CGFloat(max(0, min(100, value ?? 0)) / 100)
    }

    private var percentColor: Color {
        AccessDeckTheme.progressColor(for: provider, remaining: remaining, customHex: customHex)
    }

    private var weeklyColor: Color {
        AccessDeckTheme.progressColor(for: provider, remaining: weeklyRemaining, customHex: customHex)
    }

    private var accessibilityText: String {
        let weekly = weeklyRemaining.map { L10n.t(", 周额度 \(AccessDeckTheme.percentText($0))", ", weekly quota \(AccessDeckTheme.percentText($0))") } ?? ""
        return L10n.t(
            "\(provider.displayName) 剩余 \(AccessDeckTheme.percentText(remaining))\(weekly)，\(accountCount) 个账号",
            "\(provider.displayName) remaining \(AccessDeckTheme.percentText(remaining))\(weekly), \(accountCount) accounts"
        )
    }
}
