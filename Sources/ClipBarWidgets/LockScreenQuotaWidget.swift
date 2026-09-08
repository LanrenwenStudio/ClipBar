import SwiftUI
import WidgetKit
import AppIntents

/// 锁屏专属小组件（支持圆形 accessoryCircular、矩形 accessoryRectangular、时间上方 accessoryInline）
struct LockScreenQuotaWidget: Widget {
    static let kind: String = "LockScreenQuotaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectProviderIntent.self,
            provider: SingleProviderTimelineProvider()
        ) { entry in
            LockScreenQuotaView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("锁屏额度")
        .description("在锁屏界面或待机显示中查看 AI 渠道额度。")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - 主视图分发

struct LockScreenQuotaView: View {
    @Environment(\.widgetFamily) private var family
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
        if let provider = targetProvider {
            switch family {
            case .accessoryCircular:
                LockScreenCircularView(provider: provider)
            case .accessoryRectangular:
                LockScreenRectangularView(provider: provider, snapshot: entry.snapshot, entryDate: entry.date)
            case .accessoryInline:
                LockScreenInlineView(provider: provider)
            default:
                LockScreenCircularView(provider: provider)
            }
        } else {
            // 无数据时的紧凑占位
            switch family {
            case .accessoryInline:
                Text("ClipBar: 暂无数据")
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 14))
                    Text("--%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            default:
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                    Text("请在 App 中刷新额度")
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - 1. 圆形小组件 (accessoryCircular) - Gauge 仪表盘风格

private struct LockScreenCircularView: View {
    let provider: ProviderWidgetData

    private var percent: Double {
        min(100, max(0, provider.remainingPercent ?? 0))
    }

    var body: some View {
        Gauge(value: percent, in: 0...100) {
            ProviderGlyph(provider: provider.provider, size: 10)
        } currentValueLabel: {
            Text("\(Int(percent.rounded()))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - 2. 矩形小组件 (accessoryRectangular) - 渠道 + 额度 + 双窗口/进度条

private struct LockScreenRectangularView: View {
    let provider: ProviderWidgetData
    let snapshot: ClipBarWidgetSnapshot
    let entryDate: Date

    private var percent: Double {
        min(100, max(0, provider.remainingPercent ?? 0))
    }

    private var displayName: String {
        provider.provider == .antigravity ? "Agy" : provider.displayName
    }

    private var fiveHourWindow: QuotaWindowSummary? {
        provider.windows.first { $0.id.contains("5h") || $0.id.contains("rate_limit") }
    }

    private var weeklyWindow: QuotaWindowSummary? {
        provider.windows.first { $0.id.contains("week") }
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: snapshot.lastUpdated)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 顶行：图标 + 渠道名 + 账号数 + 刷新时间 + 主百分比
            HStack(alignment: .center, spacing: 3) {
                ProviderGlyph(provider: provider.provider, size: 11)
                Text(displayName)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))

                Spacer(minLength: 2)

                // 账号数 + 更新时间（保持清晰的主前景色）
                HStack(spacing: 3) {
                    Text("\(snapshot.healthyAccounts)/\(snapshot.totalAccounts)")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    Text("·")
                    Text(freshnessText)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.primary)

                Spacer(minLength: 2)

                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
            }

            // 中间行：紧凑进度条
            Gauge(value: percent, in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)

            // 底行：双窗口明细或重置时间
            HStack(spacing: 4) {
                if let fiveHour = fiveHourWindow?.remainingPercent,
                   let weekly = weeklyWindow?.remainingPercent {
                    Text("5h: \(Int(fiveHour.rounded()))%")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("周: \(Int(weekly.rounded()))%")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let reset = provider.nearestResetText, reset != "--" {
                    HStack(spacing: 1.5) {
                        Image(systemName: "clock")
                            .font(.system(size: 7.5))
                        Text(reset)
                            .font(.system(size: 9.0, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 3. 时间上方文字 (accessoryInline)

private struct LockScreenInlineView: View {
    let provider: ProviderWidgetData

    private var percent: Double {
        min(100, max(0, provider.remainingPercent ?? 0))
    }

    private var displayName: String {
        provider.provider == .antigravity ? "Agy" : provider.displayName
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "gauge.with.needle")
            Text("\(displayName) \(Int(percent.rounded()))%")
        }
    }
}
