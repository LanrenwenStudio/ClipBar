import SwiftUI
import WidgetKit
import AppIntents
#if canImport(UIKit)
import UIKit
#endif

/// 分段胶囊风格单渠道小组件卡片
struct SegmentedSingleProviderQuotaCard: View {
    let entry: SingleProviderEntry
    let provider: ProviderWidgetData

    private var splitWindows: (fiveHour: QuotaWindowSummary, weekly: QuotaWindowSummary)? {
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

    private var displayWindow: QuotaWindowSummary? {
        if let split = splitWindows {
            return split.weekly
        }
        guard let target = provider.remainingPercent else {
            return provider.windows.first
        }
        return provider.windows.min { lhs, rhs in
            let lhsDiff = abs((lhs.remainingPercent ?? target) - target)
            let rhsDiff = abs((rhs.remainingPercent ?? target) - target)
            return lhsDiff < rhsDiff
        }
    }

    private var remainingPercent: Double {
        min(100, max(0, displayWindow?.remainingPercent ?? provider.remainingPercent ?? 0))
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: entry.snapshot.lastUpdated)
    }

    var body: some View {
        let percent = remainingPercent
        let activeColor = ClipBarTheme.widgetBarColor(for: provider.provider, remaining: percent)
        let reset = WidgetFormatter.formatResetText(displayWindow?.resetText ?? provider.nearestResetText)

        VStack(alignment: .leading, spacing: 0) {
            // 1. 顶部栏：[图标] [渠道名] <--- 弹性空白 ---> [↻ 8分钟前]
            HStack(alignment: .center, spacing: 6) {
                ProviderGlyph(provider: provider.provider, size: 16, tint: .primary)
                    .frame(width: 16, height: 16)

                Text(provider.provider == .antigravity ? "Agy" : provider.displayName)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                    Text(freshnessText)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
            .padding(.top, 1)

            Spacer(minLength: 6)

            // 2. 核心数值区域：[5小时额度 5h] 周额度
            if let split = splitWindows {
                let fivePercent = split.fiveHour.remainingPercent ?? 0
                let weekPercent = split.weekly.remainingPercent ?? 0
                let isLow = fivePercent <= 20
                let isCritical = fivePercent <= 10
                let badgeTint: Color = isCritical ? ClipBarTheme.danger : (isLow ? ClipBarTheme.warning : Color.primary)
                let badgeBg: Color = isCritical ? ClipBarTheme.danger.opacity(0.16) : (isLow ? ClipBarTheme.warning.opacity(0.14) : Color.primary.opacity(0.06))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 5) {
                        // [百分比 5h] 紧凑胶囊，小巧辅助呈现
                        HStack(spacing: 1.5) {
                            Text("\(Int(fivePercent.rounded()))%")
                                .font(.system(size: 12.0, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(badgeTint)
                            Text("5h")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(isLow ? badgeTint : Color.secondary)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(badgeBg)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isLow ? badgeTint.opacity(0.35) : Color.clear, lineWidth: 0.7)
                        )

                        // 周额度百分比（大号主视觉，层级分明）
                        Text("\(Int(weekPercent.rounded()))%")
                            .font(.system(size: 27, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(Color.primary)
                    }
                    .fixedSize(horizontal: true, vertical: false)

                }
            } else {
                let label = displayWindow?.label ?? (WidgetFormatter.isChinese ? "可用配额" : "Quota")
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(percent.rounded()))")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary)
                        Text("%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }

                    Text(label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer(minLength: 6)

            // 3. 分段进度条：细致高密度竖条阵列（32段、高度16pt、细密间隔2.2pt、微倒角1.0pt）
            SegmentedPillBar(
                percent: percent,
                totalSegments: 32,
                barHeight: 16.0,
                segmentSpacing: 2.2,
                cornerRadius: 1.0,
                activeColor: activeColor
            )

            Spacer(minLength: 6)

            // 4. 底部状态行：[重置时间] <--- Spacer ---> [账号数量]
            HStack(alignment: .center, spacing: 4) {
                if reset != "--" {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 8, weight: .medium))
                        Text(reset)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 4)

                if provider.accountCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8, weight: .medium))
                        Text(WidgetFormatter.isChinese ? "\(provider.accountCount)个账号" : "\(provider.accountCount) accts")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.secondary)
                }
            }
            .padding(.bottom, 1)
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
}

/// 分段胶囊风格单渠道小组件入口视图
struct SegmentedSingleProviderWidgetView: View {
    let entry: SingleProviderEntry

    private var targetProvider: ProviderWidgetData? {
        let providers = entry.snapshot.providers
        guard !providers.isEmpty else { return nil }

        switch entry.selectedChoice {
        case .auto:
            return providers.first
        case .codex:
            return providers.first(where: { $0.providerRawValue == "codex" })
        case .claude:
            return providers.first(where: { $0.providerRawValue == "claude" })
        case .gemini:
            return providers.first(where: { $0.providerRawValue == "gemini" })
        case .antigravity:
            return providers.first(where: { $0.providerRawValue == "antigravity" })
        case .grok:
            return providers.first(where: { $0.providerRawValue == "xai" })
        case .kimi:
            return providers.first(where: { $0.providerRawValue == "kimi" })
        }
    }

    var body: some View {
        if !entry.snapshot.isConfigured || entry.snapshot.providers.isEmpty {
            unconfiguredView
        } else if let provider = targetProvider {
            SegmentedSingleProviderQuotaCard(entry: entry, provider: provider)
        } else {
            noDataForSelectedProviderView
        }
    }

    private var unconfiguredView: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 20))
                .foregroundStyle(Color.primary)

            Text("暂无数据")
                .font(.system(size: 12, weight: .bold, design: .rounded))

            Text("请在 App 中刷新连接")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
    }

    private var noDataForSelectedProviderView: some View {
        VStack(spacing: 5) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 20))
                .foregroundStyle(Color.secondary)

            Text("渠道未配置")
                .font(.system(size: 12, weight: .bold, design: .rounded))

            Text("长按小组件选择已有渠道")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
    }
}

/// 新版：分段胶囊单渠道小组件
struct SegmentedSingleProviderWidget: Widget {
    static let kind: String = "SegmentedSingleProviderWidget"

    init() {}

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectProviderIntent.self,
            provider: SingleProviderTimelineProvider()
        ) { entry in
            SegmentedSingleProviderWidgetView(entry: entry)
                .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("单渠道胶囊进度")
        .description("采用分段微胶囊视觉设计，清晰展示指定 AI 渠道的额度与重置时间。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
