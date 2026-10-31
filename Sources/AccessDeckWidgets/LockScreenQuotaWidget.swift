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
        if entry.selectedChoice == .auto {
            return providers.first
        }
        return providers.first(where: { entry.selectedChoice.matches(provider: $0) })
    }

    var body: some View {
        if let provider = targetProvider {
            switch family {
            case .accessoryCircular:
                LockScreenCircularView(provider: provider, showResetCredits: entry.showResetCredits)
            case .accessoryRectangular:
                LockScreenRectangularView(provider: provider, snapshot: entry.snapshot, entryDate: entry.date, showResetCredits: entry.showResetCredits, style: entry.style)
            case .accessoryInline:
                LockScreenInlineView(provider: provider, showResetCredits: entry.showResetCredits)
            default:
                LockScreenCircularView(provider: provider, showResetCredits: entry.showResetCredits)
            }
        } else {
            // 无数据时的紧凑占位
            switch family {
            case .accessoryInline:
                Text("AccessDeck: 暂无数据")
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
    var showResetCredits: Bool = false

    private var percent: Double {
        if let weekly = provider.windows.first(where: {
            let text = ($0.label + " " + $0.id).lowercased()
            return text.contains("week") || text.contains("周") || text.contains("7d")
        })?.remainingPercent {
            return min(100, max(0, weekly))
        }
        return min(100, max(0, provider.remainingPercent ?? 0))
    }

    private var shortName: String {
        switch provider.provider {
        case .antigravity: return "Agy"
        case .workbuddy: return "Buddy"
        case .geminiCLI: return "Gemini"
        case .xai: return "Grok"
        case .openrouter: return "Router"
        case .deepseek: return "DeepSeek"
        case .copilot: return "Copilot"
        case .zcode: return "ZCode"
        case .minimax: return "MiniMax"
        case .stepfun: return "Step"
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .kimi: return "Kimi"
        default:
            let lower = provider.displayName.lowercased()
            if lower.contains("antigravity") { return "Agy" }
            if lower.contains("workbuddy") { return "Buddy" }
            return provider.displayName
        }
    }

    var body: some View {
        Gauge(value: percent, in: 0...100) {
            ProviderGlyph(provider: provider.provider, size: 10)
        } currentValueLabel: {
            VStack(spacing: -1.5) {
                Text("\(Int(percent.rounded()))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(shortName)
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - 2. 矩形小组件 (accessoryRectangular) - 纯直角分段矩形只显示总量

private struct LockScreenRectangularView: View {
    let provider: ProviderWidgetData
    let snapshot: AccessDeckWidgetSnapshot
    let entryDate: Date
    var showResetCredits: Bool = false
    var style: WidgetProgressBarStyle = .segmented

    private var percent: Double {
        if let weekly = provider.windows.first(where: {
            let text = ($0.label + " " + $0.id).lowercased()
            return text.contains("week") || text.contains("周") || text.contains("7d")
        })?.remainingPercent {
            return min(100, max(0, weekly))
        }
        return min(100, max(0, provider.remainingPercent ?? 0))
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: snapshot.lastUpdated)
    }

    private var shortName: String {
        switch provider.provider {
        case .antigravity: return "Agy"
        case .workbuddy: return "Buddy"
        case .geminiCLI: return "Gemini"
        case .xai: return "Grok"
        case .openrouter: return "Router"
        case .deepseek: return "DeepSeek"
        case .copilot: return "Copilot"
        case .zcode: return "ZCode"
        case .minimax: return "MiniMax"
        case .stepfun: return "Step"
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .kimi: return "Kimi"
        default:
            let lower = provider.displayName.lowercased()
            if lower.contains("antigravity") { return "Agy" }
            if lower.contains("workbuddy") { return "Buddy" }
            if lower.contains("openrouter") { return "Router" }
            return provider.displayName
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 顶行：图标、精简名称、账号数、刷新时间与主百分比
            HStack(alignment: .center, spacing: 3) {
                ProviderGlyph(provider: provider.provider, size: 11)
                Text(shortName)
                    .font(.system(size: 11.0, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

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
                    .monospacedDigit()
            }

            // 中间行：纤细直角矩形分段进度条（严格使用分段条，不要实线）
            SegmentedPillBar(
                percent: percent,
                totalSegments: 32,
                barHeight: 7.5,
                segmentSpacing: 1.6,
                cornerRadius: 0,
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

// MARK: - 3. 时间上方文字 (accessoryInline)

private struct LockScreenInlineView: View {
    let provider: ProviderWidgetData
    var showResetCredits: Bool = false

    private var percent: Double {
        if let weekly = provider.windows.first(where: {
            let text = ($0.label + " " + $0.id).lowercased()
            return text.contains("week") || text.contains("周") || text.contains("7d")
        })?.remainingPercent {
            return min(100, max(0, weekly))
        }
        return min(100, max(0, provider.remainingPercent ?? 0))
    }

    private var shortName: String {
        switch provider.provider {
        case .antigravity: return "Agy"
        case .workbuddy: return "Buddy"
        case .geminiCLI: return "Gemini"
        case .xai: return "Grok"
        default:
            return provider.widgetTitle
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "gauge.with.needle")
            Text("\(shortName): \(Int(percent.rounded()))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
    }
}
