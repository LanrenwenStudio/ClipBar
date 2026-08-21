import SwiftUI

struct ProviderSummaryCard: View {
    let provider: QuotaProvider
    let accountCount: Int
    let remaining: Double?

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
                Spacer(minLength: 4)
                Text(ClipBarTheme.percentText(remaining))
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(percentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6.5)

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(percentColor)
                        .frame(
                            width: fill <= 0 ? 0 : max(1.5, min(geo.size.width, geo.size.width * fill)),
                            height: 6.5
                        )
                }
            }
            .frame(height: 6.5)
            .accessibilityHidden(true)
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
        .accessibilityLabel(L10n.t(
            "\(provider.displayName) 剩余 \(ClipBarTheme.percentText(remaining))，\(accountCount) 个账号",
            "\(provider.displayName) remaining \(ClipBarTheme.percentText(remaining)), \(accountCount) accounts"
        ))
    }

    private var fill: CGFloat {
        CGFloat((remaining ?? 0) / 100)
    }

    private var percentColor: Color {
        ClipBarTheme.progressColor(for: provider, remaining: remaining)
    }
}
