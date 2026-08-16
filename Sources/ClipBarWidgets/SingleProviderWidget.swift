import SwiftUI
import WidgetKit
import AppIntents

struct SingleProviderEntry: TimelineEntry {
    let date: Date
    let snapshot: ClipBarWidgetSnapshot
    let selectedChoice: WidgetProviderChoice
}

struct SingleProviderTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = SingleProviderEntry
    typealias Intent = SelectProviderIntent

    func placeholder(in context: Context) -> SingleProviderEntry {
        SingleProviderEntry(date: Date(), snapshot: .preview, selectedChoice: .auto)
    }

    func snapshot(for configuration: SelectProviderIntent, in context: Context) async -> SingleProviderEntry {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        return SingleProviderEntry(
            date: Date(),
            snapshot: snapshot.providers.isEmpty ? .preview : snapshot,
            selectedChoice: configuration.provider
        )
    }

    func timeline(for configuration: SelectProviderIntent, in context: Context) async -> Timeline<SingleProviderEntry> {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        let entry = SingleProviderEntry(
            date: Date(),
            snapshot: snapshot,
            selectedChoice: configuration.provider
        )
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct SingleProviderWidgetView: View {
    let entry: SingleProviderEntry

    private var targetProvider: ProviderWidgetData? {
        let providers = entry.snapshot.providers
        guard !providers.isEmpty else { return nil }

        switch entry.selectedChoice {
        case .auto:
            return providers.first
        case .claude:
            return providers.first(where: { $0.providerRawValue == "claude" })
        case .codex:
            return providers.first(where: { $0.providerRawValue == "codex" })
        case .gemini:
            return providers.first(where: { $0.providerRawValue == "geminiCLI" })
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
            providerCard(provider)
        } else {
            noDataForSelectedProviderView
        }
    }

    @ViewBuilder
    private func providerCard(_ p: ProviderWidgetData) -> some View {
        let quotaProvider = p.provider
        let percent = p.remainingPercent ?? 0
        let progressColor = ClipBarTheme.progressColor(for: quotaProvider, remaining: p.remainingPercent)

        VStack(alignment: .leading, spacing: 6) {
            // 1. Header: Provider Icon on left + Status Tag on right (no text name to prevent truncation)
            HStack {
                ProviderGlyph(provider: quotaProvider, size: 20)

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    Circle()
                        .fill(progressColor)
                        .frame(width: 5, height: 5)
                    Text(p.statusText)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(progressColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(progressColor.opacity(0.12), in: Capsule())
            }
            // 2. Core Quota Percentage & Main Progress Bar
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(ClipBarTheme.percentText(p.remainingPercent))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(progressColor)

                    Text("剩余")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Main Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)

                        Capsule()
                            .fill(progressColor)
                            .frame(width: max(4, geo.size.width * CGFloat(min(100, max(0, percent)) / 100.0)), height: 6)
                    }
                }
                .frame(height: 6)
            }

            // 3. Multi-window breakdown
            if !p.windows.isEmpty {
                VStack(spacing: 3) {
                    ForEach(p.windows) { win in
                        HStack(spacing: 4) {
                            Text(win.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer(minLength: 2)

                            if let winPercent = win.remainingPercent {
                                Text("\(Int(winPercent.rounded()))%")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.85))
                            } else if let reset = win.resetText {
                                Text(reset)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            } else {
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            // 4. Footer: Account count & Updated time
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 8))
                    Text("\(p.accountCount) 个账号")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.secondary)

                Spacer()

                Text(entry.snapshot.lastUpdated, style: .time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
    }

    private var unconfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 24))
                .foregroundStyle(ClipBarTheme.accent)

            Text("暂无数据")
                .font(.system(size: 13, weight: .bold))

            Text("请在 App 中刷新连接")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }

    private var noDataForSelectedProviderView: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)

            Text("该渠道暂无数据")
                .font(.system(size: 11, weight: .bold))

            Text("长按可切换其他渠道")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
    }
}

struct SingleProviderWidget: Widget {
    static let kind: String = "SingleProviderWidget"

    init() {}
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectProviderIntent.self,
            provider: SingleProviderTimelineProvider()
        ) { entry in
            SingleProviderWidgetView(entry: entry)
                .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("单渠道额度")
        .description("展示单个 AI 渠道的额度与账号状态。")
        .supportedFamilies([.systemSmall])
    }
}
