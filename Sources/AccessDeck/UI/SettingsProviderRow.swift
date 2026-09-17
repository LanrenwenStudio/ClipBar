import SwiftUI

struct SettingsProviderRow: View {
    let provider: QuotaProvider
    let accountCount: Int
    let remaining: Double?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    @Binding var isVisible: Bool
    @Binding var quotaDisplay: StatusQuotaDisplay?
    @Binding var customColorHex: String?

    var body: some View {
        HStack(spacing: 6) {
            // 上下调整顺序按钮
            HStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 14, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .foregroundStyle(canMoveUp ? Color.secondary : Color.secondary.opacity(0.2))

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 14, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .foregroundStyle(canMoveDown ? Color.secondary : Color.secondary.opacity(0.2))
            }

            // 显隐按钮
            Button(action: toggleVisibility) {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 10.5))
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(isVisible ? L10n.t("在菜单栏显示", "Visible in menu bar") : L10n.t("已在菜单栏隐藏", "Hidden from menu bar"))

            // 渠道图示
            ProviderGlyph(provider: provider, size: 12)

            // 渠道名称
            Text(provider.displayName)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)

            // 账号数胶囊
            Text("\(accountCount)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.primary.opacity(0.06)))

            Spacer(minLength: 4)

            // 颜色选择器
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(0.75)
                .frame(width: 18, height: 18)

            // 独立额度展示格式覆盖
            Picker("", selection: quotaDisplayBinding) {
                Text(L10n.t("默认", "Default")).tag(Optional<StatusQuotaDisplay>.none)
                Text(L10n.t("5h", "5h")).tag(Optional<StatusQuotaDisplay>.some(.fiveHour))
                Text(L10n.t("周", "Week")).tag(Optional<StatusQuotaDisplay>.some(.weekly))
                Text(L10n.t("双", "Both")).tag(Optional<StatusQuotaDisplay>.some(.both))
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.mini)
            .frame(width: 48)

            // 剩余额度百分比
            Text(AccessDeckTheme.percentText(remaining))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(AccessDeckTheme.progressColor(for: provider, remaining: remaining, customHex: customColorHex))
                .frame(minWidth: 32, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
        )
        .opacity(isVisible ? 1.0 : 0.6)
    }

    private var quotaDisplayBinding: Binding<StatusQuotaDisplay?> {
        Binding(
            get: { quotaDisplay },
            set: { quotaDisplay = $0 }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                if let customColorHex, let col = Color(hex: customColorHex) {
                    return col
                }
                return AccessDeckTheme.brandColor(for: provider)
            },
            set: { newColor in
                customColorHex = newColor.hexString
            }
        )
    }

    private func toggleVisibility() {
        isVisible.toggle()
    }
}
