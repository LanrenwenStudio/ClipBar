import SwiftUI

/// 细长微圆角垂直细线条分段指示器（Slender Vertical Tick / Slat Indicator）
/// 严格匹配用户参考图的物理形态与自适应撑满逻辑：
/// - 自动填满父容器的可用宽度（100% 撑开，不缩在中间）；
/// - 每一个竖条等宽撑满或按比例均匀填满整行（`frame(maxWidth: .infinity)`），条间留有精细的微间隙；
/// - 竖条保持纤细的高瘦纵横比（高 24~28pt，宽约 2.5~3.2pt）；
/// - 带有细致的微圆角（1.0~1.5pt）；
/// - 激活部分为品牌色，未激活部分为低透明度底槽。
struct SegmentedPillBar: View {
    let percent: Double
    let totalSegments: Int
    let barHeight: CGFloat
    let segmentSpacing: CGFloat
    let cornerRadius: CGFloat
    let activeColor: Color
    let inactiveColor: Color

    init(
        percent: Double,
        totalSegments: Int = 26,
        barHeight: CGFloat = 26.0,
        segmentSpacing: CGFloat = 2.2,
        cornerRadius: CGFloat = 1.2,
        activeColor: Color,
        inactiveColor: Color? = nil
    ) {
        self.percent = min(100, max(0, percent))
        self.totalSegments = max(1, totalSegments)
        self.barHeight = barHeight
        self.segmentSpacing = segmentSpacing
        self.cornerRadius = cornerRadius
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor ?? activeColor.opacity(0.18)
    }

    private var activeCount: Int {
        if percent <= 0 { return 0 }
        let raw = Double(totalSegments) * (percent / 100.0)
        let count = Int(raw.rounded())
        return max(1, min(totalSegments, count))
    }

    var body: some View {
        HStack(spacing: segmentSpacing) {
            ForEach(0..<totalSegments, id: \.self) { index in
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(index < activeCount ? activeColor : inactiveColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
    }
}

/// 重置卡精致胶囊徽标（Reset Credit Badge Pill）
/// 专为移动端（App 卡片、桌面 Widget、锁屏 Widget）设计：
/// - 采用 SF Symbol creditcard.fill 图标 + 等宽粗体数字；
/// - 半透明背景 + 细描边胶囊，与 iOS 原生设计规范及 AccessDeck 主题深度融合；
/// - 支持主题色（桌面/App）与自适应灰度（锁屏 Widget）。
struct ResetCreditPill: View {
    let count: Int
    var isAccent: Bool = true
    var fontSize: CGFloat = 8.5
    var iconSize: CGFloat = 7.5

    private var tintColor: Color {
        isAccent ? Color(red: 0.0, green: 0.52, blue: 1.0) : Color.primary
    }

    var body: some View {
        HStack(spacing: 2.5) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: iconSize, weight: .semibold))
            Text("\(count)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(tintColor)
        .padding(.horizontal, max(3.5, fontSize * 0.48))
        .padding(.vertical, max(1.2, fontSize * 0.18))
        .background(
            Capsule()
                .fill(isAccent ? tintColor.opacity(0.12) : Color.primary.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(isAccent ? tintColor.opacity(0.24) : Color.primary.opacity(0.14), lineWidth: 0.5)
        )
        .fixedSize()
    }
}

/// 连续平滑细长条进度条（Continuous Bar）
struct ContinuousPillBar: View {
    let percent: Double
    let barHeight: CGFloat
    let cornerRadius: CGFloat
    let activeColor: Color
    let inactiveColor: Color

    init(
        percent: Double,
        barHeight: CGFloat = 5.5,
        cornerRadius: CGFloat = 2.5,
        activeColor: Color,
        inactiveColor: Color? = nil
    ) {
        self.percent = min(100, max(0, percent))
        self.barHeight = barHeight
        self.cornerRadius = cornerRadius
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor ?? activeColor.opacity(0.18)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(inactiveColor)
                    .frame(height: barHeight)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(activeColor)
                    .frame(
                        width: max(0, min(geo.size.width, geo.size.width * (percent / 100.0))),
                        height: barHeight
                    )
            }
        }
        .frame(height: barHeight)
    }
}
