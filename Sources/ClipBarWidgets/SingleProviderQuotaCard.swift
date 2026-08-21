import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SingleProviderQuotaCard: View {
    let entry: SingleProviderEntry
    let provider: ProviderWidgetData

    private var displayWindow: QuotaWindowSummary? {
        guard let target = provider.remainingPercent else {
            return provider.windows.first
        }
        return provider.windows.min { lhs, rhs in
            let lhsDiff = abs((lhs.remainingPercent ?? target) - target)
            let rhsDiff = abs((rhs.remainingPercent ?? target) - target)
            return lhsDiff < rhsDiff
        }
    }

    private var remainingPercent: Double {
        min(100, max(0, displayWindow?.remainingPercent ?? provider.remainingPercent ?? 0))
    }

    private var freshnessText: String {
        WidgetFormatter.freshnessText(from: entry.snapshot.lastUpdated)
    }

    var body: some View {
        let percent = remainingPercent
        let barColor = ClipBarTheme.widgetBarColor(for: provider.provider, remaining: percent)
        let reset = WidgetFormatter.formatResetText(displayWindow?.resetText ?? provider.nearestResetText)
        let label = displayWindow?.label ?? (WidgetFormatter.isChinese ? "可用配额" : "Quota")

        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Header Row: [Provider Icon] [Provider Name] <--- Spacer ---> [↻ 8分钟前]
            HStack(alignment: .center, spacing: 5) {
                ProviderGlyph(provider: provider.provider, size: 16, tint: .primary)
                    .frame(width: 16, height: 16)

                Text(provider.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                HStack(spacing: 2.5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                    Text(freshnessText)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
            .padding(.top, 1)

            Spacer(minLength: 3)

            // 2. Subtitle / Window Label
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)

            // 3. Hero Metric Big Percentage
            Text("\(Int(percent.rounded()))%")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)
                .padding(.top, -2)

            Spacer(minLength: 2)

            // 4. Chunky Micro-Rounded Rectangle Progress Bar (加粗厚实进度条)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 12.5)

                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(barColor)
                        .frame(
                            width: percent <= 0 ? 0 : max(2.5, geo.size.width * CGFloat(percent / 100.0)),
                            height: 12.5
                        )
                }
            }
            .frame(height: 12.5)

            Spacer(minLength: 4)

            // 5. Bottom Info Row: [Reset Time] <--- Spacer ---> [Account Count]
            HStack(alignment: .center, spacing: 4) {
                if reset != "--" {
                    HStack(spacing: 2.5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 7.5, weight: .medium))
                        Text(reset)
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 4)

                if provider.accountCount > 0 {
                    HStack(spacing: 2.5) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 7.5, weight: .medium))
                        Text(WidgetFormatter.isChinese ? "\(provider.accountCount)个账号" : "\(provider.accountCount) accts")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.secondary)
                }
            }
            .padding(.bottom, 1)
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
}

#Preview {
    SingleProviderQuotaCard(
        entry: SingleProviderEntry(date: Date(), snapshot: .preview, selectedChoice: .auto),
        provider: ClipBarWidgetSnapshot.preview.providers.first ?? ProviderWidgetData(
            providerRawValue: "codex",
            displayName: "Codex",
            remainingPercent: 51,
            accountCount: 1,
            healthyCount: 1,
            statusText: "51%",
            windows: [QuotaWindowSummary(label: "周额度", remainingPercent: 51, resetText: "3d 14:27")]
        )
    )
    .frame(width: 155, height: 155)
}
