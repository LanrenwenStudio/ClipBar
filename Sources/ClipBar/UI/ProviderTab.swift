import SwiftUI

struct ProviderTab: View {
    let provider: QuotaProvider
    let accountCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4.5) {
                ProviderGlyph(
                    provider: provider,
                    size: 11,
                    tint: isSelected ? .primary : .secondary
                )
                Text(provider.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                Text("\(accountCount)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.5))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? Color.primary.opacity(0.09) : Color.primary.opacity(0.03))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.primary.opacity(0.15) : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(nil, value: isSelected)
        .accessibilityLabel(L10n.t(
            "\(provider.displayName)，\(accountCount) 个账号",
            "\(provider.displayName), \(accountCount) accounts"
        ))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var brand: Color {
        ClipBarTheme.brandColor(for: provider)
    }
}
