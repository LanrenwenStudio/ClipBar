#if os(macOS)
import SwiftUI

struct MenuBarStatusLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: ClipBarTheme.spacingXS) {
            if model.statusSegments.isEmpty {
                Text(model.statusTitle)
                    .monospacedDigit()
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

    @ViewBuilder
    private func displayTitle(for segment: StatusSegment) -> some View {
        if let fiveHour = segment.fiveHourRemaining,
           let weekly = segment.weeklyRemaining {
            let isLow = fiveHour <= 20
            let isCritical = fiveHour <= 10
            let badgeColor: Color = isCritical ? ClipBarTheme.danger : (isLow ? ClipBarTheme.warning : .white)
            let badgeBg: Color = isCritical ? ClipBarTheme.danger.opacity(0.24) : (isLow ? ClipBarTheme.warning.opacity(0.22) : Color.white.opacity(0.12))

            HStack(alignment: .center, spacing: 4.5) {
                // 5 小时完整小胶囊（前置）
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
                .background(
                    Capsule()
                        .fill(badgeBg)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isLow ? badgeColor.opacity(0.4) : Color.clear, lineWidth: 0.5)
                )

                // 周额度
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
#endif
