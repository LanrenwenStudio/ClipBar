import SwiftUI

struct QuotaBar: View {
    let window: QuotaWindow
    var tint: Color = ClipBarTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.metricSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: ClipBarTheme.spacingS) {
                Text(titleText)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: ClipBarTheme.spacingS)
                if let resetText = window.resetText {
                    Text(resetText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }

            Capsule()
                .fill(ClipBarTheme.progressTrack)
                .frame(height: ClipBarTheme.barHeight)
                .overlay {
                    Capsule()
                        .fill(barColor)
                        .scaleEffect(x: fill, y: 1, anchor: .leading)
                }
                .clipShape(Capsule())
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var fill: CGFloat {
        CGFloat((window.remainingPercent ?? 0) / 100)
    }

    private var titleText: String {
        let percent = ClipBarTheme.percentText(window.remainingPercent)
        return L10n.t("\(window.label) 剩余 \(percent)", "\(window.label) \(percent) left")
    }

    private var barColor: Color {
        guard let remaining = window.remainingPercent else { return .secondary }
        if remaining <= 0.5 { return ClipBarTheme.danger }
        if remaining <= 20 { return ClipBarTheme.warning }
        return tint
    }

    private var accessibilityText: String {
        if let resetText = window.resetText {
            return L10n.t(
                "\(window.label) 剩余 \(ClipBarTheme.percentText(window.remainingPercent))，\(resetText) 后重置",
                "\(window.label) remaining \(ClipBarTheme.percentText(window.remainingPercent)), resets in \(resetText)"
            )
        }
        return L10n.t(
            "\(window.label) 剩余 \(ClipBarTheme.percentText(window.remainingPercent))",
            "\(window.label) remaining \(ClipBarTheme.percentText(window.remainingPercent))"
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        QuotaBar(
            window: QuotaWindow(id: "5h", label: "5h", remainingPercent: 89, resetText: "2h 14m"),
            tint: ClipBarTheme.brandColor(for: .codex)
        )
        QuotaBar(
            window: QuotaWindow(id: "7d", label: "7d", remainingPercent: 18, resetText: "4d"),
            tint: ClipBarTheme.brandColor(for: .claude)
        )
    }
    .padding(20)
    .frame(width: 360)
}
