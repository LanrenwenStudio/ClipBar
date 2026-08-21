import SwiftUI

struct QuotaBar: View {
    let window: QuotaWindow
    var tint: Color = ClipBarTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 3.5) {
            HStack(alignment: .center, spacing: 4) {
                Text(titleText)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                if let resetText = window.resetText {
                    Text(resetText)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6.5)

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(barColor)
                        .frame(
                            width: fill <= 0 ? 0 : max(1.5, min(geo.size.width, geo.size.width * fill)),
                            height: 6.5
                        )
                }
            }
            .frame(height: 6.5)
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
        ClipBarTheme.progressColor(for: .unknown, remaining: window.remainingPercent)
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
            window: QuotaWindow(id: "7d", label: "周额度", remainingPercent: 18, resetText: "4d"),
            tint: ClipBarTheme.brandColor(for: .claude)
        )
    }
    .padding(20)
    .frame(width: 360)
}
