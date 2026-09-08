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

    private var hasFiveHour: Bool {
        provider.windows.contains { w in
            let text = (w.label + " " + w.id).lowercased()
            return text.contains("5h") || text.contains("rate_limit") || text.contains("5小时") || text.contains("five-hour") || text.contains("five hour")
        }
    }

    var body: some View {
        Gauge(value: percent, in: 0...100) {
            ProviderGlyph(provider: provider.provider, size: 10)
        } currentValueLabel: {
            if hasFiveHour {
                VStack(spacing: -1.5) {
                    Text("\(Int(percent.rounded()))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("5h")
                        .font(.system(size: 7, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("\(Int(percent.rounded()))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
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
        provider.windows.first { w in
            let text = (w.label + " " + w.id).lowercased()
            return text.contains("5h") || text.contains("rate_limit") || text.contains("5小时") || text.contains("five-hour") || text.contains("five hour")
        }
    }

    private var weeklyWindow: QuotaWindowSummary? {
        provider.windows.first { w in
            let text = (w.label + " " + w.id).lowercased()
            return text.contains("week") || text.contains("周") || text.contains("7d") || text.contains("seven-day")
        }
    }

    private var splitWindows: (fiveHour: Double, weekly: Double)? {
        if let fiveHour = fiveHourWindow?.remainingPercent,
           let weekly = weeklyWindow?.remainingPercent {
            return (min(100, max(0, fiveHour)), min(100, max(0, weekly)))
        }
        // 兜底：若有至少两个窗口，且第1个不是周额度，则取前两个窗口
        if provider.windows.count >= 2,
           let first = provider.windows[0].remainingPercent,
           let second = provider.windows[1].remainingPercent {
            return (min(100, max(0, first)), min(100, max(0, second)))
        }
        return nil
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: snapshot.lastUpdated)
    }

    var body: some View {
        if let split = splitWindows {
            let fiveHour = split.fiveHour
            let weekly = split.weekly
            // 双窗口布局：5h 与周额度各有一条独立进度条
            VStack(alignment: .leading, spacing: 3) {
                // 顶栏：左侧[图标 + 渠道名 + 账号数] ... 右侧[刷新时间]
                HStack(alignment: .center, spacing: 3) {
                    ProviderGlyph(provider: provider.provider, size: 10.5)
                    Text(displayName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))

                    if provider.accountCount > 0 {
                        Text("\(provider.healthyCount)/\(provider.accountCount)")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 2)

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 6.5, weight: .semibold))
                        Text(freshnessText)
                            .font(.system(size: 8.0, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }

                // 第 1 栏：5 小时额度条
                HStack(spacing: 4) {
                    Text("5h")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .leading)

                    SegmentedPillBar(
                        percent: min(100, max(0, fiveHour)),
                        totalSegments: 24,
                        barHeight: 5.5,
                        segmentSpacing: 1.0,
                        cornerRadius: 0.5,
                        activeColor: .primary,
                        inactiveColor: Color.primary.opacity(0.18)
                    )

                    Spacer(minLength: 0)

                    Text("\(Int(fiveHour.rounded()))%")
                        .font(.system(size: 9.0, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                // 第 2 栏：周额度条
                HStack(spacing: 4) {
                    Text("周")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .leading)

                    SegmentedPillBar(
                        percent: min(100, max(0, weekly)),
                        totalSegments: 24,
                        barHeight: 5.5,
                        segmentSpacing: 1.0,
                        cornerRadius: 0.5,
                        activeColor: .primary,
                        inactiveColor: Color.primary.opacity(0.18)
                    )

                    Spacer(minLength: 0)

                    Text("\(Int(weekly.rounded()))%")
                        .font(.system(size: 9.0, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
        } else {
            // 单窗口布局：单一大进度条 + 重置倒计时
            VStack(alignment: .leading, spacing: 2) {
                // 顶行：左侧[图标 + 渠道名 + 账号数] ... 右侧[刷新时间 + 主百分比]
                HStack(alignment: .center, spacing: 3) {
                    ProviderGlyph(provider: provider.provider, size: 11)
                    Text(displayName)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))

                    if provider.accountCount > 0 {
                        Text("\(provider.healthyCount)/\(provider.accountCount)")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 2)

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 7, weight: .semibold))
                        Text(freshnessText)
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)

                    Spacer(minLength: 2)

                    Text("\(Int(percent.rounded()))%")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                }

                // 中间行：分段胶囊进度条（细密条纹风格）
                SegmentedPillBar(
                    percent: percent,
                    totalSegments: 28,
                    barHeight: 5.5,
                    segmentSpacing: 1.1,
                    cornerRadius: 0.5,
                    activeColor: .primary,
                    inactiveColor: Color.primary.opacity(0.18)
                )

                // 底行：重置时间
                HStack(spacing: 4) {
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

    private var hasFiveHour: Bool {
        provider.windows.contains { w in
            let text = (w.label + " " + w.id).lowercased()
            return text.contains("5h") || text.contains("rate_limit") || text.contains("5小时") || text.contains("five-hour") || text.contains("five hour")
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "gauge.with.needle")
            if hasFiveHour {
                Text("\(displayName) \(Int(percent.rounded()))% 5h")
            } else {
                Text("\(displayName) \(Int(percent.rounded()))%")
            }
        }
    }
}
