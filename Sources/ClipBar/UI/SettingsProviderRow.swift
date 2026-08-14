import SwiftUI

struct SettingsProviderRow: View {
    let provider: QuotaProvider
    let accountCount: Int
    let remaining: Double?
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: ClipBarTheme.spacingS) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Toggle("", isOn: $isVisible)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            ProviderGlyph(provider: provider, size: 13)

            Text(provider.displayName)
            Text(L10n.t("\(accountCount) 个", "\(accountCount)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: ClipBarTheme.spacingS)

            Text(ClipBarTheme.percentText(remaining))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(ClipBarTheme.progressColor(for: provider, remaining: remaining))
        }
        .frame(minHeight: 28)
    }
}
