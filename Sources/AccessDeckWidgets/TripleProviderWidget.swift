import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

struct MultiProviderEntry: TimelineEntry {
    let date: Date
    let snapshot: AccessDeckWidgetSnapshot
    let style: WidgetProgressBarStyle
    let showResetCredits: Bool
    let channelCount: Int
    let selectedProviders: [WidgetProviderChoice]

    init(
        date: Date,
        snapshot: AccessDeckWidgetSnapshot,
        style: WidgetProgressBarStyle = .segmented,
        showResetCredits: Bool = true,
        channelCount: Int = 4,
        selectedProviders: [WidgetProviderChoice] = [.auto, .auto, .auto, .auto]
    ) {
        self.date = date
        self.snapshot = snapshot
        self.style = style
        self.showResetCredits = showResetCredits
        self.channelCount = channelCount
        self.selectedProviders = selectedProviders
    }
}

// Backward compatibility alias
typealias TripleProviderEntry = MultiProviderEntry

struct MultiProviderTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = MultiProviderEntry
    typealias Intent = MultiProviderIntent

    func placeholder(in context: Context) -> MultiProviderEntry {
        MultiProviderEntry(
            date: Date(),
            snapshot: .preview,
            style: .segmented,
            showResetCredits: true,
            channelCount: 4,
            selectedProviders: [.auto, .auto, .auto, .auto]
        )
    }

    func snapshot(for configuration: MultiProviderIntent, in context: Context) async -> MultiProviderEntry {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        return MultiProviderEntry(
            date: Date(),
            snapshot: snapshot.providers.isEmpty ? .preview : snapshot,
            style: configuration.style,
            showResetCredits: configuration.showResetCredits,
            channelCount: configuration.count.rawValue,
            selectedProviders: [
                configuration.channel1,
                configuration.channel2,
                configuration.channel3,
                configuration.channel4
            ]
        )
    }

    func timeline(for configuration: MultiProviderIntent, in context: Context) async -> Timeline<MultiProviderEntry> {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        let entry = MultiProviderEntry(
            date: Date(),
            snapshot: snapshot.providers.isEmpty ? .preview : snapshot,
            style: configuration.style,
            showResetCredits: configuration.showResetCredits,
            channelCount: configuration.count.rawValue,
            selectedProviders: [
                configuration.channel1,
                configuration.channel2,
                configuration.channel3,
                configuration.channel4
            ]
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

typealias TripleProviderTimelineProvider = MultiProviderTimelineProvider

struct MultiProviderWidgetView: View {
    let entry: MultiProviderEntry
    var maxCount: Int = 4

    private var displayProviders: [ProviderWidgetData] {
        let all = entry.snapshot.providers.isEmpty
            ? AccessDeckWidgetSnapshot.preview.providers
            : entry.snapshot.providers
        return resolveDisplayProviders(
            allProviders: all,
            choices: entry.selectedProviders,
            targetCount: max(1, min(4, entry.channelCount))
        )
    }

    private var count: Int {
        max(1, displayProviders.count)
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: entry.snapshot.lastUpdated)
    }

    private var glyphSize: CGFloat {
        switch count {
        case 1: return 14.5
        case 2: return 13.5
        case 3: return 12.5
        default: return 10.5
        }
    }

    private var percentFontSize: CGFloat {
        switch count {
        case 1: return 11.0
        case 2: return 10.0
        case 3: return 9.5
        default: return 8.5
        }
    }

    private var barHeight: CGFloat {
        switch count {
        case 1: return 6.0
        case 2: return 5.0
        case 3: return 4.5
        default: return 3.8
        }
    }

    private var barRadius: CGFloat {
        barHeight / 2
    }

    var body: some View {
        if !entry.snapshot.isConfigured || entry.snapshot.providers.isEmpty {
            unconfiguredView
        } else if entry.style == .segmented {
            SegmentedMultiProviderWidgetView(entry: entry, maxCount: entry.channelCount)
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
                VStack(spacing: count >= 4 ? 4.0 : (count == 3 ? 6.0 : 8.0)) {
                    ForEach(displayProviders) { p in
                        providerRow(p)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, count >= 4 ? 13 : 15)
        .padding(.top, count >= 4 ? 8 : 10)
        .padding(.bottom, count >= 4 ? 8 : 10)
    }

    private func providerRow(_ p: ProviderWidgetData) -> some View {
        let splitWindows = splitQuotaWindows(for: p)
        let reset = WidgetFormatter.formatResetText(p.nearestResetText ?? p.windows.first?.resetText)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
                ProviderGlyph(provider: p.provider, size: glyphSize, tint: .primary)
                    .frame(width: glyphSize, height: glyphSize)

                if entry.showResetCredits, p.provider == .codex, let credits = p.resetCreditCount, credits > 0 {
                    ResetCreditPill(count: credits, expiresAt: p.resetCreditExpiresAt, isAccent: true, fontSize: 8.5, iconSize: 7.0)
                } else {
                    Text(p.provider == .antigravity ? "Agy" : p.displayName)
                        .font(.system(size: count >= 4 ? 10.0 : 11.0, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 4)

                if let splitWindows {
                    let fivePercent = splitWindows.fiveHour.remainingPercent ?? 0
                    let isLow = fivePercent <= 20
                    let isCritical = fivePercent <= 10
                    let badgeTint: Color = isCritical ? AccessDeckTheme.danger : (isLow ? AccessDeckTheme.warning : Color.primary)
                    let badgeBg: Color = isCritical ? AccessDeckTheme.danger.opacity(0.16) : (isLow ? AccessDeckTheme.warning.opacity(0.14) : Color.primary.opacity(0.06))

                    HStack(alignment: .bottom, spacing: 2.5) {
                        // [5小时百分比 5h] 紧凑胶囊，保护渠道名空间
                        HStack(spacing: 1.0) {
                            Text(compactPercent(splitWindows.fiveHour))
                                .font(.system(size: max(6.5, percentFontSize - 2.5), weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(badgeTint)
                            Text(p.nearestFiveHourDisplayText ?? "5h")
                                .font(.system(size: max(5.5, percentFontSize - 4.0), weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(isLow ? badgeTint : Color.secondary)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 2.5)
                        .padding(.vertical, 0.8)
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
                            .font(.system(size: percentFontSize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
                } else {
                    if let rem = p.remainingPercent {
                        Text("\(Int(min(100, max(0, rem)).rounded()))%")
                            .font(.system(size: percentFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .layoutPriority(1)
                    } else {
                        Text("免费")
                            .font(.system(size: max(8.0, percentFontSize - 0.5), weight: .bold, design: .rounded))
                            .foregroundStyle(AccessDeckTheme.success)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
            }

            // 进度条：统一整条连续平滑微胶囊（与头部周额度呼应，纤细精致）
            let mainPercent = splitWindows?.weekly.remainingPercent ?? (p.remainingPercent ?? 100)
            let barColor = p.remainingPercent != nil
                ? AccessDeckTheme.widgetBarColor(for: p.provider, remaining: mainPercent)
                : AccessDeckTheme.success

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: barHeight)

                    Rectangle()
                        .fill(barColor)
                        .frame(
                            width: mainPercent <= 0 ? 0 : max(0, min(geo.size.width, geo.size.width * CGFloat(mainPercent / 100.0))),
                            height: barHeight
                        )
                }
            }
            .frame(height: barHeight)

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
        AppIntentConfiguration(
            kind: Self.kind,
            intent: MultiProviderIntent.self,
            provider: MultiProviderTimelineProvider()
        ) { entry in
            Group {
                if entry.style == .continuous {
                    MultiProviderWidgetView(entry: entry, maxCount: entry.channelCount)
                } else {
                    SegmentedMultiProviderWidgetView(entry: entry, maxCount: entry.channelCount)
                }
            }
            .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("多渠道概览")
        .description("展示主力 AI 渠道的额度与健康状态，支持在设置中自选 1~4 个渠道及切换进度条样式。")
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
