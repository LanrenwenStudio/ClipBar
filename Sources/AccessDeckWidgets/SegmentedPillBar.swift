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
