import SwiftUI

struct ProviderTab: View {
    let provider: QuotaProvider
    let accountCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ProviderGlyph(
                    provider: provider,
                    size: 12,
                    tint: isSelected ? brand : .secondary
                )
                Text(provider.displayName)
                Text("\(accountCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? brand.opacity(0.82) : Color.secondary.opacity(0.7))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? brand : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? brand.opacity(0.16) : Color.clear, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : ClipBarTheme.hairline, lineWidth: 1)
            }
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
