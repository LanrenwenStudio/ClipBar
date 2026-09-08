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

    private var displayWindow: QuotaWindowSummary? {
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
        let label = displayWindow?.label ?? (WidgetFormatter.isChinese ? "可用配额" : "Quota")

        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Header Row: [Provider Icon] [Provider Name] <--- Spacer ---> [↻ 8分钟前]
            HStack(alignment: .center, spacing: 5.5) {
                ProviderGlyph(provider: provider.provider, size: 16, tint: .primary)
                    .frame(width: 16, height: 16)

                Text(provider.provider == .antigravity ? "Agy" : provider.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                HStack(spacing: 2.5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                    Text(freshnessText)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
            .padding(.top, 1)

            Spacer(minLength: 4)

            // 2. Subtitle / Window Label
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)

            // 3. Hero Metric Big Percentage
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(percent.rounded()))")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text("%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.top, -2)

            Spacer(minLength: 4)

            // 4. Segmented Slat Bar (细长垂直微圆角竖线阵列：26条细长竖线自适应撑满卡片100%全宽)
            SegmentedPillBar(
                percent: percent,
                totalSegments: 26,
                barHeight: 26.0,
                segmentSpacing: 2.2,
                cornerRadius: 1.2,
                activeColor: activeColor
            )

            Spacer(minLength: 5)

            // 5. Bottom Info Row: [Reset Time] <--- Spacer ---> [Account Count]
            HStack(alignment: .center, spacing: 4) {
                if reset != "--" {
                    HStack(spacing: 2.5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 7.5, weight: .medium))
                        Text(reset)
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 4)

                if provider.accountCount > 0 {
                    HStack(spacing: 2.5) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 7.5, weight: .medium))
                        Text(WidgetFormatter.isChinese ? "\(provider.accountCount)个账号" : "\(provider.accountCount) accts")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
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
