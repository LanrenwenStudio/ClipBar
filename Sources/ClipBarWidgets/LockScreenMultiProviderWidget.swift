import SwiftUI
import WidgetKit

/// 锁屏多渠道矩形小组件（2×4 紧凑条目样式：支持同时清晰展示 5 小时与周额度）
struct LockScreenMultiProviderWidget: Widget {
    static let kind: String = "LockScreenMultiProviderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: MultiProviderTimelineProvider()
        ) { entry in
            LockScreenMultiProviderView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("多渠道锁屏额度")
        .description("在锁屏矩形区域同时展示各渠道的 5 小时与周额度。")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockScreenMultiProviderView: View {
    let entry: MultiProviderEntry

    private var providers: [ProviderWidgetData] {
        let list = entry.snapshot.providers.isEmpty
            ? entry.snapshot.topThreeProviders
            : entry.snapshot.providers
        return Array(list.prefix(3))
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: entry.snapshot.lastUpdated)
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
                // 顶部紧凑状态栏：账号总数 + 更新时间（保持清晰的主前景色）
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
                .padding(.bottom, 2)

                // 各渠道行（紧凑纵向排列）
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, p in
                    if index > 0 {
                        Spacer(minLength: 1)
                    }
                    providerRow(p)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func providerRow(_ p: ProviderWidgetData) -> some View {
        let displayName = p.provider == .antigravity ? "Agy" : p.displayName
        let split = splitQuotaWindows(for: p)
        let primaryPercent = min(100, max(0, p.remainingPercent ?? 0))

        let barPercent = split?.weekly ?? primaryPercent

        return HStack(alignment: .center, spacing: 4) {
            // 1. 左侧：图标 + 渠道名
            HStack(spacing: 2.0) {
                ProviderGlyph(provider: p.provider, size: 9.5)
                    .frame(width: 9.5, height: 9.5)
                Text(displayName)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 44, alignment: .leading)

            // 2. 中间：分段胶囊进度条
            SegmentedPillBar(
                percent: barPercent,
                totalSegments: 12,
                barHeight: 7.5,
                segmentSpacing: 1.4,
                cornerRadius: 0.8,
                activeColor: .primary,
                inactiveColor: Color.primary.opacity(0.18)
            )
            .frame(width: 46)

            Spacer(minLength: 0)

            // 3. 右侧数值
            Group {
                if let split {
                    HStack(spacing: 1.0) {
                        Text("\(Int(split.fiveHour.rounded()))%")
                            .font(.system(size: 8.0, weight: .bold, design: .rounded))
                        Text("/")
                            .font(.system(size: 6.5, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("\(Int(split.weekly.rounded()))%")
                            .font(.system(size: 8.0, weight: .bold, design: .rounded))
                    }
                } else {
                    Text("\(Int(primaryPercent.rounded()))%")
                        .font(.system(size: 9.0, weight: .bold, design: .rounded))
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
    }

    private func splitQuotaWindows(for provider: ProviderWidgetData) -> (fiveHour: Double, weekly: Double)? {
        let windows = provider.windows
        guard windows.count >= 2 else { return nil }

        // 查找 5 小时窗口
        let fiveHourWindow = windows.first { w in
            let text = (w.label + " " + w.id).lowercased()
            return text.contains("5h") || text.contains("rate_limit") || text.contains("5小时")
        }

        // 查找 周 窗口
        let weeklyWindow = windows.first { w in
            let text = (w.label + " " + w.id).lowercased()
            return text.contains("week") || text.contains("周") || text.contains("7d")
        }

        if let fiveHour = fiveHourWindow?.remainingPercent,
           let weekly = weeklyWindow?.remainingPercent {
            return (min(100, max(0, fiveHour)), min(100, max(0, weekly)))
        }

        // 兜底：如果正好有 2 个窗口，第 1 个作为短期/5h，第 2 个作为周/长期
        if let first = windows[0].remainingPercent, let second = windows[1].remainingPercent {
            return (min(100, max(0, first)), min(100, max(0, second)))
        }

        return nil
    }
}
