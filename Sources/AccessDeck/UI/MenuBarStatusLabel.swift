#if os(macOS)
import SwiftUI

struct MenuBarStatusLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: AccessDeckTheme.spacingXS) {
            if model.statusSegments.isEmpty {
                AccessDeckMark(
                    isWarning: isWarning,
                    isRefreshing: model.connection.isRefreshing
                )
            } else {
                ForEach(Array(model.statusSegments.enumerated()), id: \.element.id) { index, segment in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.32))
                            .frame(width: 1, height: 11)
                            .accessibilityHidden(true)
                    }

                    HStack(spacing: 3) {
                        if let image = ProviderIcon.image(for: segment.provider, size: 13) {
                            Image(nsImage: image)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 13, height: 13)
                        }
                        displayTitle(for: segment)
                    }
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 2)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.statusAccessibilityLabel)
    }

    private var isWarning: Bool {
        if case .failed = model.connection { return true }
        return false
    }

    @ViewBuilder
    private func displayTitle(for segment: StatusSegment) -> some View {
        if let fiveHour = segment.fiveHourRemaining,
           let weekly = segment.weeklyRemaining {
            let isLow = fiveHour <= 20
            let isCritical = fiveHour <= 10
            let badgeColor: Color = isCritical ? AccessDeckTheme.danger : (isLow ? AccessDeckTheme.warning : .white)
            let badgeBg: Color = isCritical ? AccessDeckTheme.danger.opacity(0.24) : (isLow ? AccessDeckTheme.warning.opacity(0.22) : Color.white.opacity(0.12))

            HStack(alignment: .center, spacing: 4.5) {
                HStack(spacing: 2) {
                    Text("\(Int(fiveHour.rounded()))%")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(badgeColor)
                    Text(segment.fiveHourResetText ?? "--")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isLow ? badgeColor : Color.white.opacity(0.85))
                }
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(badgeBg))
                .overlay(
                    Capsule()
                        .strokeBorder(isLow ? badgeColor.opacity(0.4) : Color.clear, lineWidth: 0.5)
                )

                Text("\(Int(weekly.rounded()))%")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
            }
        } else {
            Text(segment.displayTitle)
                .monospacedDigit()
        }
    }
}

/// AccessDeck 的无数据品牌标记：一枚小型“叠层卡片 + 检查光点”，
/// 与应用的额度卡片视觉语言一致，比直接显示底层 CPA 服务名更有品牌识别度。
private struct AccessDeckMark: View {
    let isWarning: Bool
    let isRefreshing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .frame(width: 13, height: 13)
                .offset(x: -2, y: 1.5)

            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: 13, height: 13)
                .offset(x: 1.5, y: -1)

            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .strokeBorder(isWarning ? AccessDeckTheme.warning : Color.white.opacity(0.92), lineWidth: 1.5)
                .frame(width: 13, height: 13)
                .rotationEffect(.degrees(45))

            Circle()
                .fill(isWarning ? AccessDeckTheme.warning : AccessDeckTheme.success)
                .frame(width: 3.5, height: 3.5)
                .offset(x: 4.5, y: 4.5)
                .opacity(isRefreshing ? 0.35 : 1)
        }
        .frame(width: 17, height: 17)
        .rotationEffect(.degrees(-45))
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRefreshing)
    }
}
#endif
