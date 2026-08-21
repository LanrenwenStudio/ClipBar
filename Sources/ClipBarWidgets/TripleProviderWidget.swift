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

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: entry.snapshot.lastUpdated)
    }

    private var glyphSize: CGFloat {
        switch count {
        case 5: return 11
        case 4: return 12
        default: return 13.5
        }
    }

    private var percentFontSize: CGFloat {
        switch count {
        case 5: return 12
        case 4: return 13
        default: return 14
        }
    }

    private var barHeight: CGFloat {
        switch count {
        case 5: return 5.0
        case 4: return 6.0
        default: return 7.5
        }
    }

    private var barRadius: CGFloat {
        2.0
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
            if displayProviders.isEmpty {
                placeholderRow
            } else {
                VStack(spacing: count >= 4 ? 4.0 : 6.0) {
                    ForEach(displayProviders) { p in
                        providerRow(p)
                    }
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
        let reset = WidgetFormatter.formatResetText(p.nearestResetText ?? p.windows.first?.resetText)

        return VStack(alignment: .leading, spacing: 2) {
            // Header Line: [Icon] [Name] <---- Spacer ----> [Percentage]
            HStack(alignment: .center, spacing: 5) {
                ProviderGlyph(provider: p.provider, size: glyphSize, tint: .primary)
                    .frame(width: glyphSize, height: glyphSize)

                Text(p.displayName)
                    .font(.system(size: count >= 4 ? 11 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: percentFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }

            // Full-Width Sleek Micro-Rounded Rectangle Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: barHeight)

                    RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                        .fill(rowColor)
                        .frame(
                            width: percent <= 0 ? 0 : max(barRadius, geo.size.width * CGFloat(percent / 100.0)),
                            height: barHeight
                        )
                }
            }
            .frame(height: barHeight)

            // Reset countdown timestamp
            if reset != "--" {
                HStack(spacing: 2.5) {
                    Spacer(minLength: 0)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 7, weight: .medium))
                    Text(reset)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
        }
    }
    private var placeholderRow: some View {
        VStack(alignment: .leading, spacing: 2.5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: glyphSize, height: glyphSize)

                Spacer()

                Text("--%")
                    .font(.system(size: percentFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }

            RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
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
                .foregroundStyle(Color.primary)

            Text("请在 App 中刷新连接")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(14)
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
