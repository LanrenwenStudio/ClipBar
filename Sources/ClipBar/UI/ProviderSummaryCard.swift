import SwiftUI

struct ProviderSummaryCard: View {
    let provider: QuotaProvider
    let accountCount: Int
    let remaining: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.metricSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: ClipBarTheme.sectionSpacing) {
                HStack(spacing: ClipBarTheme.spacingS) {
                    ProviderGlyph(provider: provider, size: 14)
                    Text(provider.displayName)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(L10n.t("\(accountCount) 个账号", "\(accountCount) accounts"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: ClipBarTheme.spacingS)
                Text(ClipBarTheme.percentText(remaining))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(percentColor)
            }

            Capsule()
                .fill(ClipBarTheme.progressTrack)
                .frame(height: ClipBarTheme.barHeight)
                .overlay {
                    Capsule()
                        .fill(percentColor)
                        .scaleEffect(x: fill, y: 1, anchor: .leading)
                }
                .clipShape(Capsule())
                .accessibilityHidden(true)
        }
        .padding(.horizontal, ClipBarTheme.horizontalPadding)
        .padding(.vertical, 10)
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
