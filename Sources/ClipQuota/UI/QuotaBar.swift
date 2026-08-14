import SwiftUI

struct QuotaBar: View {
    let window: QuotaWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(window.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(percentText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(barColor)
                if let resetText = window.resetText {
                    Text(resetText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(barColor)
                        .frame(width: proxy.size.width * fill)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var fill: CGFloat {
        CGFloat((window.remainingPercent ?? 0) / 100)
    }

    private var percentText: String {
        guard let remaining = window.remainingPercent else { return "—" }
        return "\(Int(remaining.rounded()))%"
    }

    private var barColor: Color {
        guard let remaining = window.remainingPercent else { return .secondary }
        if remaining <= 20 { return .red }
        if remaining <= 50 { return .orange }
        return .green
    }

    private var accessibilityText: String {
        let remaining = percentText
        if let resetText = window.resetText {
            return L10n.t("\(window.label) 剩余 \(remaining)，\(resetText) 后重置", "\(window.label) remaining \(remaining), resets in \(resetText)")
        }
        return L10n.t("\(window.label) 剩余 \(remaining)", "\(window.label) remaining \(remaining)")
    }
}
