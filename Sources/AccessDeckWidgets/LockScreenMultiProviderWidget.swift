import SwiftUI
import WidgetKit

/// 锁屏多渠道矩形小组件（支持 1~4 渠道紧凑监控：精简名称、仅显示总量配额、纯矩形进度条）
struct LockScreenMultiProviderWidget: Widget {
    static let kind: String = "LockScreenMultiProviderWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: MultiProviderIntent.self,
            provider: MultiProviderTimelineProvider()
        ) { entry in
            LockScreenMultiProviderView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("多渠道锁屏额度")
        .description("在锁屏矩形区域同时展示最多 4 个渠道的总量额度与进度。")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockScreenMultiProviderView: View {
    let entry: MultiProviderEntry

    private var providers: [ProviderWidgetData] {
        let all = entry.snapshot.providers.isEmpty
            ? AccessDeckWidgetSnapshot.preview.providers
            : entry.snapshot.providers
        return resolveDisplayProviders(
            allProviders: all,
            choices: entry.selectedProviders,
            targetCount: 4
        )
    }

    private var count: Int {
        max(1, providers.count)
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: entry.snapshot.lastUpdated)
    }

    // 针对 1~4 个渠道自适应尺寸
    private var iconSize: CGFloat {
        count >= 4 ? 7.5 : (count == 3 ? 8.5 : 9.5)
    }

    private var nameFontSize: CGFloat {
        count >= 4 ? 7.2 : (count == 3 ? 8.0 : 8.8)
    }

    private var nameColumnWidth: CGFloat {
        count >= 4 ? 35.0 : 38.0
    }

    private var barHeight: CGFloat {
        count >= 4 ? 5.0 : (count == 3 ? 6.0 : 7.0)
    }

    private var segmentCount: Int {
        count >= 4 ? 20 : 22
    }

    private var segmentSpacing: CGFloat {
        1.6
    }

    private var percentFontSize: CGFloat {
        count >= 4 ? 7.5 : (count == 3 ? 8.2 : 9.0)
    }

    private var rowSpacing: CGFloat {
        count >= 4 ? 1.5 : (count == 3 ? 3.0 : 5.0)
    }

    var body: some View {
        if providers.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                Text("暂无数据")
                    .font(.caption2)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部紧凑状态栏：健康账号数/总数 + 更新时间
                HStack(alignment: .center, spacing: 3) {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 7))
                        Text("\(entry.snapshot.healthyAccounts)/\(entry.snapshot.totalAccounts)")
                            .font(.system(size: 8.0, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.primary)

                    Spacer(minLength: 4)

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 6.5, weight: .semibold))
                        Text(freshnessText)
                            .font(.system(size: 8.0, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.primary)
                }
                .padding(.bottom, count >= 4 ? 1.5 : 2.5)

                // 各渠道行（最多展示 4 个渠道）
                VStack(spacing: rowSpacing) {
                    ForEach(providers) { p in
                        providerRow(p)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func providerRow(_ p: ProviderWidgetData) -> some View {
        // 只取总量配额（优先取周额度，其次取 remainingPercent）
        let totalPercent = resolveTotalPercent(for: p)

        return HStack(alignment: .center, spacing: 3.5) {
            // 1. 图标 + 精简渠道名（不再显示重置卡数量）
            HStack(spacing: 2.0) {
                ProviderGlyph(provider: p.provider, size: iconSize)
                    .frame(width: iconSize, height: iconSize)
                Text(shortName(for: p))
                    .font(.system(size: nameFontSize, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(width: nameColumnWidth, alignment: .leading)

            // 2. 中间：直角矩形分段竖条进度条（充满剩余空间，严格使用分段条，不要实线）
            SegmentedPillBar(
                percent: totalPercent,
                totalSegments: segmentCount,
                barHeight: barHeight,
                segmentSpacing: segmentSpacing,
                cornerRadius: 0,
                activeColor: .primary,
                inactiveColor: Color.primary.opacity(0.18)
            )
            .frame(maxWidth: .infinity)

            // 3. 右侧：只显示总量百分比
            Text("\(Int(totalPercent.rounded()))%")
                .font(.system(size: percentFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 25, alignment: .trailing)
        }
    }

    /// 提取该渠道的总量配额百分比
    private func resolveTotalPercent(for provider: ProviderWidgetData) -> Double {
        if let weekly = provider.windows.first(where: {
            let text = ($0.label + " " + $0.id).lowercased()
            return text.contains("week") || text.contains("周") || text.contains("7d")
        })?.remainingPercent {
            return min(100, max(0, weekly))
        }
        if let rem = provider.remainingPercent {
            return min(100, max(0, rem))
        }
        return 100.0
    }

    /// 精简渠道名称（确保在锁屏有限空间下不换行、不截断）
    private func shortName(for p: ProviderWidgetData) -> String {
        switch p.provider {
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
            let lower = p.displayName.lowercased()
            if lower.contains("antigravity") { return "Agy" }
            if lower.contains("workbuddy") { return "Buddy" }
            if lower.contains("openrouter") { return "Router" }
            return p.displayName
        }
    }
}
