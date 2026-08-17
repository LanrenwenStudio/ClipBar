import SwiftUI
import WidgetKit
import AppIntents
#if canImport(UIKit)
import UIKit
#endif

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
            snapshot: snapshot.providers.isEmpty ? .preview : snapshot,
            selectedChoice: configuration.provider
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
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
            SingleProviderQuotaCard(entry: entry, provider: provider)
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
        .contentMarginsDisabled()
    }
}
