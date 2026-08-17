import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

struct MultiProviderEntry: TimelineEntry {
    let date: Date
    let snapshot: ClipBarWidgetSnapshot
}

// Backward compatibility alias
typealias TripleProviderEntry = MultiProviderEntry

struct MultiProviderTimelineProvider: TimelineProvider {
    typealias Entry = MultiProviderEntry

    func placeholder(in context: Context) -> MultiProviderEntry {
        MultiProviderEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (MultiProviderEntry) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        completion(MultiProviderEntry(date: Date(), snapshot: snapshot.providers.isEmpty ? .preview : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MultiProviderEntry>) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        let entry = MultiProviderEntry(date: Date(), snapshot: snapshot.providers.isEmpty ? .preview : snapshot)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

typealias TripleProviderTimelineProvider = MultiProviderTimelineProvider

struct MultiProviderWidgetView: View {
    let entry: MultiProviderEntry
    let maxCount: Int

    private var displayProviders: [ProviderWidgetData] {
        let list = entry.snapshot.providers
        if list.isEmpty {
            return Array(entry.snapshot.topThreeProviders.prefix(maxCount))
        }
        return Array(list.prefix(maxCount))
    }

    private var count: Int {
        max(1, displayProviders.count)
    }

    private var isChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }

    private var freshnessText: String {
        let elapsed = max(0, entry.date.timeIntervalSince(entry.snapshot.lastUpdated))
        if elapsed < 60 {
            return isChinese ? "刚刚" : "Just now"
        }
        if elapsed < 3_600 {
            let minutes = max(1, Int(elapsed / 60))
            return isChinese ? "\(minutes)分钟前" : "\(minutes)m ago"
        }
        if elapsed < 86_400 {
            let hours = max(1, Int(elapsed / 3_600))
            return isChinese ? "\(hours)小时前" : "\(hours)h ago"
        }
        return isChinese ? "较早" : "Earlier"
    }

    private var statusDotColor: Color {
        let snapshot = entry.snapshot
        // 拿不到数据 / 未配置 / 无账号 -> 红色；正常拿到数据 -> 绿色
        if !snapshot.isConfigured || snapshot.providers.isEmpty || snapshot.totalAccounts == 0 {
            return Color.red
        }
        return Color.green
    }

    private var glyphSize: CGFloat {
        switch count {
        case 5: return 12
        case 4: return 13
        case 3: return 13.5
        default: return 15
        }
    }

    private var nameFontSize: CGFloat {
        switch count {
        case 5: return 9.5
        case 4: return 10.5
        case 3: return 11.5
        default: return 12.5
        }
    }

    private var percentFontSize: CGFloat {
        switch count {
        case 5: return 11
        case 4: return 12
        case 3: return 13.5
        default: return 14.5
        }
    }

    private var barHeight: CGFloat {
        switch count {
        case 5: return 3.5
        case 4: return 4
        case 3: return 4.5
        default: return 5.5
        }
    }

    private var rowInnerSpacing: CGFloat {
        switch count {
        case 5: return 2.5
        case 4: return 3
        case 3: return 3.5
        default: return 4
        }
    }

    var body: some View {
        if !entry.snapshot.isConfigured || entry.snapshot.providers.isEmpty {
            unconfiguredView
        } else {
            multiProviderCard
        }
    }

    private var multiProviderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Bar: ["11/11" (Left)] <--------> [🟢 Freshness "刚刚" (Right)]
            HStack(alignment: .center, spacing: 4) {
                Text("\(entry.snapshot.healthyAccounts)/\(entry.snapshot.totalAccounts)")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.secondary)

                Spacer(minLength: 4)

                HStack(spacing: 3.5) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 5, height: 5)

                    Text(freshnessText)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            // Top Spacer before rows
            Spacer(minLength: 0)

            // Main Provider Rows (Pure Icon + Progress Bar + Percentage)
            if displayProviders.isEmpty {
                placeholderRow
            } else {
                ForEach(Array(displayProviders.enumerated()), id: \.element.id) { index, p in
                    if index > 0 {
                        Spacer(minLength: 0)
                    }
                    providerRow(p)
                }
            }

            // Bottom Spacer
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
    }

    private func quotaColor(for percent: Double) -> Color {
        let threshold = Double(entry.snapshot.lowQuotaThreshold)
        if percent <= 0.5 {
            return Color(uiColor: .systemRed)
        }
        if percent <= threshold {
            return Color(uiColor: .systemOrange)
        }
        return Color.primary
    }

    private func providerRow(_ p: ProviderWidgetData) -> some View {
        let percent = min(100, max(0, p.remainingPercent ?? 0))
        let isExhausted = percent <= 0.5
        let rowColor = quotaColor(for: percent)
        let reset = p.nearestResetText

        let trailingText: String = {
            if isExhausted, let reset, !reset.isEmpty {
                return reset
            }
            return "\(Int(percent.rounded()))%"
        }()

        let isShowingReset = isExhausted && reset != nil && !(reset?.isEmpty ?? true)
        let fontSz: CGFloat = isShowingReset ? max(10, percentFontSize - 1) : percentFontSize

        return VStack(alignment: .leading, spacing: rowInnerSpacing) {
            // Header Line: [Icon] [Provider Name] <---- Spacer ----> [Percentage or Reset Time]
            HStack(alignment: .center, spacing: 5) {
                ProviderGlyph(provider: p.provider, size: glyphSize)
                    .frame(width: glyphSize, height: glyphSize)

                Text(p.displayName)
                    .font(.system(size: nameFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(trailingText)
                    .font(.system(size: fontSz, weight: .heavy, design: .rounded))
                    .foregroundStyle(rowColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Full-Width Sleek Progress Bar (Matching SingleProvider style)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: barHeight)

                    Capsule()
                        .fill(rowColor)
                        .frame(
                            width: isExhausted ? 0 : max(barHeight, geo.size.width * CGFloat(percent / 100.0)),
                            height: barHeight
                        )
                }
            }
            .frame(height: barHeight)
        }
    }

    private var placeholderRow: some View {
        VStack(alignment: .leading, spacing: rowInnerSpacing) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: glyphSize, height: glyphSize)

                Text("--")
                    .font(.system(size: nameFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondary)

                Spacer()

                Text("--%")
                    .font(.system(size: percentFontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }

            Capsule()
                .fill(Color.primary.opacity(0.06))
                .frame(height: barHeight)
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
}

// Backward compatibility
typealias TripleProviderWidgetView = MultiProviderWidgetView

// 1. 三渠道小组件
struct TripleProviderWidget: Widget {
    static let kind: String = "TripleProviderWidget"

    init() {}

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: MultiProviderTimelineProvider()
        ) { entry in
            MultiProviderWidgetView(entry: entry, maxCount: 3)
                .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("三渠道概览")
        .description("展示主力 3 个 AI 渠道的额度与健康状态。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview("3渠道") {
    MultiProviderWidgetView(
        entry: MultiProviderEntry(date: Date(), snapshot: .preview),
        maxCount: 3
    )
    .frame(width: 155, height: 155)
}

#Preview("4渠道") {
    MultiProviderWidgetView(
        entry: MultiProviderEntry(date: Date(), snapshot: .preview),
        maxCount: 4
    )
    .frame(width: 155, height: 155)
}

#Preview("5渠道") {
    MultiProviderWidgetView(
        entry: MultiProviderEntry(date: Date(), snapshot: .preview),
        maxCount: 5
    )
    .frame(width: 155, height: 155)
}
