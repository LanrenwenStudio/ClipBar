import SwiftUI

struct SettingsProviderRow: View {
    let provider: QuotaProvider
    let accountCount: Int
    let remaining: Double?
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Button(action: toggleVisibility) {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .frame(width: 18, height: 18)

            ProviderGlyph(provider: provider, size: 12)

            Text(provider.displayName)
                .font(.system(size: 11.5, weight: .medium))

            Text(L10n.t("\(accountCount) 个", "\(accountCount)"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text(ClipBarTheme.percentText(remaining))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ClipBarTheme.progressColor(for: provider, remaining: remaining))
        }
        .padding(.vertical, 2)
        .frame(minHeight: 28)
    }

    private func toggleVisibility() {
        isVisible.toggle()
    }
}
