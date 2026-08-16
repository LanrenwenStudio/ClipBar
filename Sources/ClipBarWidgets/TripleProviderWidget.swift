import SwiftUI
import WidgetKit

struct TripleProviderEntry: TimelineEntry {
    let date: Date
    let snapshot: ClipBarWidgetSnapshot
}

struct TripleProviderTimelineProvider: TimelineProvider {
    typealias Entry = TripleProviderEntry

    func placeholder(in context: Context) -> TripleProviderEntry {
        TripleProviderEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TripleProviderEntry) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        completion(TripleProviderEntry(date: Date(), snapshot: snapshot.providers.isEmpty ? .preview : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripleProviderEntry>) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        let entry = TripleProviderEntry(date: Date(), snapshot: snapshot)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TripleProviderWidgetView: View {
    let entry: TripleProviderEntry

    private var displayProviders: [ProviderWidgetData] {
        let list = entry.snapshot.topThreeProviders.isEmpty ? entry.snapshot.providers : entry.snapshot.topThreeProviders
        return Array(list.prefix(3))
    }

    var body: some View {
        if !entry.snapshot.isConfigured || entry.snapshot.providers.isEmpty {
            unconfiguredView
        } else {
            tripleCard
        }
    }

    private var tripleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Minimal Icon on left, Overall percentage pill on right
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ClipBarTheme.accent)

                Spacer(minLength: 4)

                if let overall = entry.snapshot.overallRemaining {
                    Text("\(Int(overall.rounded()))%")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(overallColor(overall))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(overallColor(overall).opacity(0.12), in: Capsule())
                }
            }

            Divider()
                .opacity(0.5)

            // 3 Provider Rows
            VStack(spacing: 6) {
                ForEach(displayProviders) { p in
                    providerRow(p)
                }

                // Fill placeholders if fewer than 3 providers
                if displayProviders.count < 3 {
                    ForEach(displayProviders.count..<3, id: \.self) { _ in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 15, height: 15)

                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 5.5)

                            Text("--")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 34, alignment: .trailing)
                        }
                        .frame(height: 19)
                    }
                }
            }

            Spacer(minLength: 0)

            // Footer
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(entry.snapshot.healthyAccounts > 0 ? ClipBarTheme.success : ClipBarTheme.warning)
                        .frame(width: 4.5, height: 4.5)
                    Text("\(entry.snapshot.healthyAccounts)/\(entry.snapshot.totalAccounts) 正常")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.snapshot.lastUpdated, style: .time)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(11)
    }

    private func providerRow(_ p: ProviderWidgetData) -> some View {
        let provider = p.provider
        let color = ClipBarTheme.progressColor(for: provider, remaining: p.remainingPercent)
        let percent = p.remainingPercent ?? 0

        return HStack(spacing: 6) {
            ProviderGlyph(provider: provider, size: 15)

            // Wide progress capsule bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5.5)

                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(min(100, max(0, percent)) / 100.0)), height: 5.5)
                }
            }
            .frame(height: 5.5)

            Text(ClipBarTheme.percentText(p.remainingPercent))
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 34, alignment: .trailing)
        }
        .frame(height: 19)
    }

    private func overallColor(_ value: Double) -> Color {
        if value <= 0.5 { return ClipBarTheme.danger }
        if value <= 15 { return ClipBarTheme.warning }
        return ClipBarTheme.success
    }

    private var unconfiguredView: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22))
                .foregroundStyle(ClipBarTheme.accent)

            Text("暂无数据")
                .font(.system(size: 12, weight: .bold))

            Text("请在 App 中刷新连接")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
    }
}

struct TripleProviderWidget: Widget {
    static let kind: String = "TripleProviderWidget"

    init() {}

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: TripleProviderTimelineProvider()
        ) { entry in
            TripleProviderWidgetView(entry: entry)
                .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("三渠道概览")
        .description("展示前三个主力 AI 渠道的额度与状态。")
        .supportedFamilies([.systemSmall])
    }
}
