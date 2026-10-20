import SwiftUI

struct ProviderTab: View {
    let provider: QuotaProvider
    let accountCount: Int
    let isSelected: Bool
    var isHiddenFromMenuBar: Bool = false
    let action: () -> Void
    var onToggleVisibility: (() -> Void)? = nil
    var openSettings: (() -> Void)? = nil
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
                if isHiddenFromMenuBar {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 8))
                        .foregroundStyle(AccessDeckTheme.warning)
                }
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
        .contextMenu {
            if let onToggleVisibility {
                Button(action: onToggleVisibility) {
                    Label(
                        isHiddenFromMenuBar
                            ? L10n.t("在状态栏显示此渠道", "Show in Menu Bar")
                            : L10n.t("在状态栏隐藏此渠道", "Hide from Menu Bar"),
                        systemImage: isHiddenFromMenuBar ? "eye" : "eye.slash"
                    )
                }
            }
            if let openSettings {
                Divider()
                Button(action: openSettings) {
                    Label(L10n.t("渠道设置…", "Channel Settings…"), systemImage: "gearshape")
                }
            }
        }
        .help(isHiddenFromMenuBar ? L10n.t("\(provider.displayName)（已在状态栏隐藏，右键可修改）", "\(provider.displayName) (hidden from menu bar, right-click to change)") : provider.displayName)
        .animation(nil, value: isSelected)
        .accessibilityLabel(L10n.t(
            "\(provider.displayName)，\(accountCount) 个账号",
            "\(provider.displayName), \(accountCount) accounts"
        ))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var brand: Color {
        AccessDeckTheme.brandColor(for: provider)
    }
}
