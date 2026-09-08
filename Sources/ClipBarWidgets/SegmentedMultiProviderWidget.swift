import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

/// 分段胶囊风格多渠道概览小组件视图（支持 1 / 2 / 3 渠道动态自适应）
struct SegmentedMultiProviderWidgetView: View {
    let entry: MultiProviderEntry
    let maxCount: Int

    private var displayProviders: [ProviderWidgetData] {
        let list = entry.snapshot.providers.isEmpty
            ? entry.snapshot.topThreeProviders
            : entry.snapshot.providers

        return Array(list.prefix(maxCount))
    }

    private var count: Int {
        max(1, displayProviders.count)
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: entry.snapshot.lastUpdated)
    }

    // 动态尺寸与分段配置
    private var glyphSize: CGFloat {
        switch count {
        case 1: return 15.0
        case 2: return 13.5
        default: return 12.5
        }
    }

    private var titleFontSize: CGFloat {
        switch count {
        case 1: return 13.5
        case 2: return 12.0
        default: return 11.5
        }
    }

    private var percentFontSize: CGFloat {
        switch count {
        case 1: return 11.5
        case 2: return 10.5
        default: return 10.0
        }
    }

    private var barHeight: CGFloat {
        switch count {
        case 1: return 16.0
        case 2: return 12.0
        default: return 9.5
        }
    }

    private var segmentCount: Int {
        switch count {
        case 1: return 32
        case 2: return 28
        default: return 26
        }
    }

    private var segmentSpacing: CGFloat {
        switch count {
        case 1: return 2.2
        case 2: return 2.0
        default: return 2.0
        }
    }

    private var cornerRadius: CGFloat {
        return 1.0
    }

    private var rowSpacing: CGFloat {
        switch count {
        case 1: return 0
        case 2: return 10.0
        default: return 6.5
        }
    }

    private var providerInnerSpacing: CGFloat {
        switch count {
        case 1: return 4.0
        case 2: return 3.0
        default: return 2.0
        }
    }

    private var resetFontSize: CGFloat {
        switch count {
        case 1: return 9.0
        case 2: return 8.0
        default: return 7.5
        }
    }

    private var resetIconSize: CGFloat {
        switch count {
        case 1: return 8.0
        case 2: return 7.0
        default: return 6.5
        }
    }

    var body: some View {
        if !entry.snapshot.isConfigured {
            unconfiguredView
        } else if displayProviders.isEmpty {
            exhaustedOrEmptyView
        } else {
            multiProviderCard
        }
    }

    private var multiProviderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Bar: [11/11 (Left)] <--- Spacer ---> [↻ 8分钟前 (Right)]
            HStack(alignment: .center) {
                Text("\(entry.snapshot.healthyAccounts)/\(entry.snapshot.totalAccounts)")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.secondary)

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                    Text(freshnessText)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
            .padding(.top, 2)

            Spacer(minLength: 2)

            // Main Provider Rows
            VStack(spacing: rowSpacing) {
                ForEach(displayProviders) { p in
                    providerRow(p)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private func providerRow(_ p: ProviderWidgetData) -> some View {
        let percent = min(100, max(0, p.remainingPercent ?? 0))
        let rowColor = ClipBarTheme.widgetBarColor(for: p.provider, remaining: percent)
        let splitWindows = splitQuotaWindows(for: p)
        let reset = WidgetFormatter.formatResetText(p.nearestResetText ?? p.windows.first?.resetText)

        return VStack(alignment: .leading, spacing: providerInnerSpacing) {
            // 头部：图标 + 标题 + 百分比
            HStack(alignment: .center, spacing: 5) {
                ProviderGlyph(provider: p.provider, size: glyphSize, tint: .primary)
                    .frame(width: glyphSize, height: glyphSize)

                Text(p.provider == .antigravity ? "Agy" : p.displayName)
                    .font(.system(size: titleFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                if let splitWindows {
                    let fivePercent = splitWindows.fiveHour.remainingPercent ?? 0
                    let isLow = fivePercent <= 20
                    let isCritical = fivePercent <= 10
                    let badgeTint: Color = isCritical ? ClipBarTheme.danger : (isLow ? ClipBarTheme.warning : Color.primary)
                    let badgeBg: Color = isCritical ? ClipBarTheme.danger.opacity(0.16) : (isLow ? ClipBarTheme.warning.opacity(0.14) : Color.primary.opacity(0.06))

                    HStack(alignment: .bottom, spacing: 3.0) {
                        // [5小时百分比 5h] 紧凑精致胶囊，避免挤占左侧渠道名
                        HStack(spacing: 1.0) {
                            Text(compactPercent(splitWindows.fiveHour))
                                .font(.system(size: max(6.8, percentFontSize - 2.8), weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(badgeTint)
                            Text("5h")
                                .font(.system(size: max(5.8, percentFontSize - 4.2), weight: .semibold, design: .rounded))
                                .foregroundStyle(isLow ? badgeTint : Color.secondary)
                        }
                        .padding(.horizontal, 3.0)
                        .padding(.vertical, 1.0)
                        .background(
                            Capsule()
                                .fill(badgeBg)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isLow ? badgeTint.opacity(0.35) : Color.clear, lineWidth: 0.5)
                        )

                        // 周额度百分比
                        Text(compactPercent(splitWindows.weekly))
                            .font(.system(size: percentFontSize + 0.5, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                    }
                    .layoutPriority(1)
                } else {
                    Text("\(Int(percent.rounded()))%")
                        .font(.system(size: percentFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .layoutPriority(1)
                }
            }

            // 进度条：统一采用单渠道同款完整的整条分段条（与头部周额度呼应，更舒展更具统一感）
            let mainPercent = splitWindows?.weekly.remainingPercent ?? percent
            let barColor = ClipBarTheme.widgetBarColor(for: p.provider, remaining: mainPercent)

            SegmentedPillBar(
                percent: min(100, max(0, mainPercent ?? 0)),
                totalSegments: segmentCount,
                barHeight: barHeight,
                segmentSpacing: segmentSpacing,
                cornerRadius: cornerRadius,
                activeColor: barColor
            )

            // 底部重置时间
            let fiveHourDuration = splitWindows.flatMap { formatRemainingDuration($0.fiveHour.resetText) }
            let weeklyResetRaw = splitWindows.flatMap { WidgetFormatter.formatResetText($0.weekly.resetText) }
            let rightReset = (weeklyResetRaw != nil && weeklyResetRaw != "--") ? weeklyResetRaw! : reset

            let showLeftReset = fiveHourDuration != nil && fiveHourDuration != "--"
            let showRightReset = rightReset != "--"

            if showLeftReset || showRightReset {
                HStack(alignment: .center, spacing: 2.5) {
                    if let fiveHourDuration, showLeftReset {
                        Text(fiveHourDuration)
                            .font(.system(size: resetFontSize, weight: .medium, design: .rounded))
                    }

                    Spacer(minLength: 0)

                    if showRightReset {
                        HStack(spacing: 2) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: resetIconSize, weight: .medium))
                            Text(rightReset)
                                .font(.system(size: resetFontSize, weight: .medium, design: .rounded))
                        }
                    }
                }
                .foregroundStyle(Color.secondary)
            }
        }
    }

    private func dualSegmentedBars(
        fiveHour: QuotaWindowSummary,
        weekly: QuotaWindowSummary,
        provider: QuotaProvider
    ) -> some View {
        let halfSegments = max(3, segmentCount / 2)
        let fivePercent = min(100, max(0, fiveHour.remainingPercent ?? 0))
        let weekPercent = min(100, max(0, weekly.remainingPercent ?? 0))
        let fiveColor = ClipBarTheme.widgetBarColor(for: provider, remaining: fiveHour.remainingPercent)
        let weekColor = ClipBarTheme.widgetBarColor(for: provider, remaining: weekly.remainingPercent)

        return HStack(alignment: .center, spacing: 6) {
            SegmentedPillBar(
                percent: fivePercent,
                totalSegments: halfSegments,
                barHeight: barHeight,
                segmentSpacing: segmentSpacing,
                cornerRadius: cornerRadius,
                activeColor: fiveColor
            )
            SegmentedPillBar(
                percent: weekPercent,
                totalSegments: halfSegments,
                barHeight: barHeight,
                segmentSpacing: segmentSpacing,
                cornerRadius: cornerRadius,
                activeColor: weekColor
            )
        }
    }

    private func compactPercent(_ window: QuotaWindowSummary) -> String {
        guard let remaining = window.remainingPercent else { return "--" }
        return "\(Int(min(100, max(0, remaining)).rounded()))%"
    }

    private func formatRemainingDuration(_ raw: String?) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text != "--" else {
            return nil
        }
        let duration = parseResetDuration(text)
        if duration != .infinity && duration >= 0 {
            let totalMinutes = Int(duration / 60)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 && minutes > 0 {
                return WidgetFormatter.isChinese ? "\(hours)小时\(minutes)分" : "\(hours)h \(minutes)m"
            } else if hours > 0 {
                return WidgetFormatter.isChinese ? "\(hours)小时" : "\(hours)h"
            } else if minutes > 0 {
                return WidgetFormatter.isChinese ? "\(minutes)分" : "\(minutes)m"
            } else {
                return WidgetFormatter.isChinese ? "<1分" : "<1m"
            }
        }
        return text
    }

    private func splitQuotaWindows(
        for provider: ProviderWidgetData
    ) -> (fiveHour: QuotaWindowSummary, weekly: QuotaWindowSummary)? {
        guard let fiveHour = provider.windows.first(where: isFiveHourWindow),
              let weekly = provider.windows.first(where: isWeeklyWindow)
        else {
            return nil
        }
        return (fiveHour, weekly)
    }

    private func isFiveHourWindow(_ window: QuotaWindowSummary) -> Bool {
        let label = window.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return label == "5h" || label.contains("5h") || label.contains("five-hour") || label.contains("five hour")
    }

    private func isWeeklyWindow(_ window: QuotaWindowSummary) -> Bool {
        let label = window.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return label == "7d"
            || label.contains("周")
            || label == "week"
            || label.contains("weekly")
    }

    private var exhaustedOrEmptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "battery.0percent")
                .font(.system(size: 22))
                .foregroundStyle(ClipBarTheme.warning)

            Text("额度已消耗殆尽")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            Text(entry.snapshot.providers.isEmpty ? "还没有配置渠道 Token" : "所有渠道额度均已用尽")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(14)
    }

    private var unconfiguredView: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 20))
                .foregroundStyle(Color.primary)

            Text("暂无数据")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            Text("请在 App 中刷新连接")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(14)
    }
}

/// 新版：分段胶囊多渠道概览小组件
struct SegmentedMultiProviderWidget: Widget {
    static let kind: String = "SegmentedMultiProviderWidget"

    init() {}

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: MultiProviderTimelineProvider()
        ) { entry in
            SegmentedMultiProviderWidgetView(entry: entry, maxCount: 3)
                .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("多渠道胶囊概览")
        .description("采用分段微胶囊视觉设计，清晰展示最多 3 个可用 AI 渠道的额度与健康状态。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
