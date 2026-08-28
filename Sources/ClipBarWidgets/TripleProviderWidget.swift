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
        case 5: return 9.0
        case 4: return 9.5
        default: return 10.0
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
        let splitWindows = splitQuotaWindows(for: p)
        let reset = WidgetFormatter.formatResetText(p.nearestResetText ?? p.windows.first?.resetText)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
                ProviderGlyph(provider: p.provider, size: glyphSize, tint: .primary)
                    .frame(width: glyphSize, height: glyphSize)

                Text(p.provider == .antigravity ? "Agy" : p.displayName)
                    .font(.system(size: count >= 4 ? 10.5 : 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                if let splitWindows {
                    HStack(alignment: .center, spacing: 2.5) {
                        Text(compactPercent(splitWindows.fiveHour))
                            .font(.system(size: percentFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)

                        Text("/")
                            .font(.system(size: max(7.5, percentFontSize - 2), weight: .regular, design: .rounded))
                            .foregroundStyle(Color.secondary.opacity(0.5))

                        Text(compactPercent(splitWindows.weekly))
                            .font(.system(size: percentFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                    }
                } else {
                    Text("\(Int(percent.rounded()))%")
                        .font(.system(size: percentFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                }
            }

            if let splitWindows {
                dualQuotaBars(
                    fiveHour: splitWindows.fiveHour,
                    weekly: splitWindows.weekly,
                    provider: p.provider
                )
            } else {
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
            }

            let fiveHourDuration = splitWindows.flatMap { formatRemainingDuration($0.fiveHour.resetText) }
            let weeklyResetRaw = splitWindows.flatMap { WidgetFormatter.formatResetText($0.weekly.resetText) }
            let rightReset = (weeklyResetRaw != nil && weeklyResetRaw != "--") ? weeklyResetRaw! : reset

            let showLeftReset = fiveHourDuration != nil && fiveHourDuration != "--"
            let showRightReset = rightReset != "--"

            if showLeftReset || showRightReset {
                HStack(alignment: .center, spacing: 2.5) {
                    if let fiveHourDuration, showLeftReset {
                        Text(fiveHourDuration)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                    }

                    Spacer(minLength: 0)

                    if showRightReset {
                        HStack(spacing: 2) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 7, weight: .medium))
                            Text(rightReset)
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                        }
                    }
                }
                .foregroundStyle(Color.secondary)
            }
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

    private func dualQuotaBars(
        fiveHour: QuotaWindowSummary,
        weekly: QuotaWindowSummary,
        provider: QuotaProvider
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            compactQuotaBar(fiveHour, label: "5h", provider: provider)
            compactQuotaBar(
                weekly,
                label: WidgetFormatter.isChinese ? "周" : "Week",
                provider: provider
            )
        }
    }

    private func compactQuotaBar(
        _ window: QuotaWindowSummary,
        label: String,
        provider: QuotaProvider
    ) -> some View {
        let percent = min(100, max(0, window.remainingPercent ?? 0))
        let color = ClipBarTheme.widgetBarColor(for: provider, remaining: window.remainingPercent)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: barHeight)

                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(color)
                    .frame(
                        width: percent <= 0 ? 0 : max(barRadius, geo.size.width * CGFloat(percent / 100.0)),
                        height: barHeight
                    )
            }
        }
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(compactPercent(window))")
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
