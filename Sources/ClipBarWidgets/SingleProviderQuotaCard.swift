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
        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Header Row: [Provider Icon] <--- Spacer ---> [↻ 8分钟前]
            HStack(alignment: .center, spacing: 6) {
                ProviderGlyph(provider: provider.provider, size: 18, tint: .primary)
                    .frame(width: 18, height: 18)

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8.5, weight: .semibold))
                    Text(freshnessText)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
            .padding(.top, 2)

            Spacer(minLength: 3)

            // 2. Main Quota Rows
            if provider.windows.count >= 2 {
                let firstTwo = Array(provider.windows.prefix(2))
                VStack(spacing: 6) {
                    ForEach(firstTwo) { window in
                        quotaWindowSection(window)
                    }
                }
            } else {
                singleQuotaHeroSection
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Two-Window Layout (e.g. Claude 5h + Weekly)
    private func quotaWindowSection(_ window: QuotaWindowSummary) -> some View {
        let percent = min(100, max(0, window.remainingPercent ?? 0))
        let barColor = ClipBarTheme.widgetBarColor(for: provider.provider, remaining: percent)
        let reset = WidgetFormatter.formatResetText(window.resetText)

        return VStack(alignment: .leading, spacing: 1.5) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }

            // Subtle slightly-rounded rectangle progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.0, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 11)

                    RoundedRectangle(cornerRadius: 2.0, style: .continuous)
                        .fill(barColor)
                        .frame(
                            width: percent <= 0 ? 0 : max(2.0, geo.size.width * CGFloat(percent / 100.0)),
                            height: 11
                        )
                }
            }
            .frame(height: 11)

            if reset != "--" {
                HStack(spacing: 2.5) {
                    Spacer(minLength: 0)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 7.5, weight: .medium))
                    Text(reset)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
        }
    }

    // MARK: - Single Hero Window Layout
    private var singleQuotaHeroSection: some View {
        let percent = remainingPercent
        let barColor = ClipBarTheme.widgetBarColor(for: provider.provider, remaining: percent)
        let reset = WidgetFormatter.formatResetText(displayWindow?.resetText ?? provider.nearestResetText)
        let label = displayWindow?.label ?? (WidgetFormatter.isChinese ? "剩余额度" : "Remaining")

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.0, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 15)

                    RoundedRectangle(cornerRadius: 2.0, style: .continuous)
                        .fill(barColor)
                        .frame(
                            width: percent <= 0 ? 0 : max(2.0, geo.size.width * CGFloat(percent / 100.0)),
                            height: 15
                        )
                }
            }
            .frame(height: 15)

            if reset != "--" {
                HStack(spacing: 2.5) {
                    Spacer(minLength: 0)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 8, weight: .medium))
                    Text(reset)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.secondary)
            }
        }
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
