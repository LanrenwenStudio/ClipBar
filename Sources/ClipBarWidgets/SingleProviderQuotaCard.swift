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
    private var quotaColor: Color {
        let threshold = Double(entry.snapshot.lowQuotaThreshold)
        if remainingPercent <= 0.5 {
            return Color(uiColor: .systemRed)
        }
        if remainingPercent <= threshold {
            return Color(uiColor: .systemOrange)
        }
        return Color.primary
    }
    private var statusDotColor: Color {
        let snapshot = entry.snapshot
        if snapshot.connectionStatus == "failed" {
            return Color.red
        }
        if snapshot.connectionStatus == "refreshing" {
            return Color.blue
        }
        return Color.green
    }
    private var remainingPercent: Double {
        min(100, max(0, displayWindow?.remainingPercent ?? provider.remainingPercent ?? 0))
    }

    private var usedPercent: Double {
        100 - remainingPercent
    }
    private var quotaTitle: String {
        L10n.t("剩余", "Remaining")
    }
    private var freshnessText: String {
        let elapsed = max(0, entry.date.timeIntervalSince(entry.snapshot.lastUpdated))
        if elapsed < 60 {
            return L10n.t("刚刚", "Just now")
        }
        if elapsed < 3_600 {
            let minutes = max(1, Int(elapsed / 60))
            return L10n.t("\(minutes) 分钟前", "\(minutes)m ago")
        }
        let hours = max(1, Int(elapsed / 3_600))
        return L10n.t("\(hours) 小时前", "\(hours)h ago")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Header Row: [Provider Icon] [Provider Name] <--- Spacer ---> [🟢 刚刚]
            HStack(alignment: .center, spacing: 5.5) {
                ProviderGlyph(provider: provider.provider, size: 15)
                    .frame(width: 16, height: 16)

                Text(provider.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                HStack(spacing: 3.5) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 5, height: 5)
                    Text(freshnessText)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 1)

            // Top Elastic Spacer
            Spacer(minLength: 0)

            // 2. Middle Hero Quota Row: [每周] vs [51%]
            HStack(alignment: .firstTextBaseline) {
                Text(quotaTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                Spacer(minLength: 4)

                Text("\(Int(remainingPercent.rounded()))%")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(quotaColor)
            }
            .padding(.horizontal, 2)

            // 3. Custom full-width progress pill bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 7)

                    Capsule()
                        .fill(quotaColor)
                        .frame(
                            width: max(7, geo.size.width * CGFloat(min(100, max(0, remainingPercent)) / 100.0)),
                            height: 7
                        )
                }
            }
            .frame(height: 7)
            .padding(.top, 4)
            .padding(.horizontal, 2)

            // Bottom Elastic Spacer
            Spacer(minLength: 0)

            // 4. Subtle Hairline Divider
            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.top, 2)
                .padding(.bottom, 6)

            // 5. Bottom Metadata List
            VStack(spacing: 5.5) {
                statusRow(
                    systemImage: "clock.arrow.circlepath",
                    title: L10n.t("下次重置", "Next reset"),
                    value: displayWindow?.resetText ?? "--"
                )

                statusRow(
                    systemImage: "person.2.fill",
                    title: L10n.t("账号数量", "Accounts"),
                    value: L10n.t("\(provider.accountCount) 个", "\(provider.accountCount)")
                )
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
    }

    private func statusRow(systemImage: String, title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9.5, weight: .medium))
                .frame(width: 13)
                .foregroundStyle(Color.secondary)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
            windows: [QuotaWindowSummary(label: "7d", remainingPercent: 51, resetText: "3d 14:27")]
        )
    )
    .frame(width: 155, height: 155)
}
