#if os(iOS)
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false
    @State private var showingReorderSheet = false
    @State private var selectedProvider: QuotaProvider?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !model.settings.isConfigured {
                        unconfiguredBanner
                    } else {
                        serverStatusHeader
                        overallMetricsGrid
                        providersSection
                        analyticsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("AccessDeck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        triggerHaptic(.light)
                        Task { await model.refresh(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.85))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        triggerHaptic(.light)
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.85))
                    }
                }
            }
            .refreshable {
                triggerHaptic(.medium)
                await model.refresh(force: true)
            }
            .sheet(isPresented: $showingSettings) {
                ServerSettingsView()
            }
            .sheet(item: $selectedProvider) { provider in
                ProviderDetailView(provider: provider)
            }
            .sheet(isPresented: $showingReorderSheet) {
                ProviderReorderSheet()
            }
            .onAppear {
                if !model.settings.isConfigured {
                    showingSettings = true
                }
            }
            .task {
                await model.refresh(force: true)
            }
        }
    }

    // MARK: - Server Status Header

    private var serverStatusHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectionIndicatorColor)
                        .frame(width: 8, height: 8)
                    Text(connectionStatusTitle)
                        .font(.subheadline.weight(.semibold))
                }
                HStack(spacing: 4) {
                    Image(systemName: connectionMethodIcon)
                        .font(.caption2)
                    Text(connectionMethodTitle)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(Color.primary.opacity(0.58))
                Text(model.settings.activeURL)
                    .font(.caption2)
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(L10n.t("最后更新", "Last Updated"))
                    .font(.caption2)
                    .foregroundStyle(Color.primary.opacity(0.55))
                Text(model.lastRefreshText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.primary.opacity(0.75))
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Overall Metrics Grid

    private var overallMetricsGrid: some View {
        HStack(spacing: 12) {
            MetricBox(
                title: L10n.t("最低剩余额度", "Lowest Quota"),
                value: lowestQuotaText,
                subtitle: L10n.t("5h / 周额度最小窗口", "5h / weekly window"),
                accentColor: lowestQuotaColor
            )

            MetricBox(
                title: L10n.t("可用账号", "Active Accounts"),
                value: "\(model.healthyCount) / \(model.accounts.count)",
                subtitle: L10n.t("可路由账号", "Routable accounts"),
                accentColor: AccessDeckTheme.accent
            )
        }
    }

    // MARK: - Providers Section

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("多渠道", "Multi-Provider"))
                    .font(.headline)
                Spacer()
                if dashboardProviderGroups.count > 1 {
                    Button {
                        triggerHaptic(.light)
                        showingReorderSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(L10n.t("调整排序", "Reorder"))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AccessDeckTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AccessDeckTheme.accent.opacity(0.12), in: Capsule())
                    }
                } else {
                    Text("\(dashboardProviderGroups.count) " + L10n.t("个渠道", "Providers"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if dashboardProviderGroups.isEmpty {
                if model.connection == .refreshing {
                    HStack {
                        Spacer()
                        ProgressView(L10n.t("正在拉取额度数据...", "Fetching quota data..."))
                            .foregroundStyle(Color.primary.opacity(0.75))
                            .padding(.vertical, 24)
                        Spacer()
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if model.groupedAccounts.isEmpty {
                    UnavailableStateView(
                        title: L10n.t("还没有渠道 Token", "No Channel Tokens"),
                        detail: L10n.t("添加至少一个渠道 Token 后，这里会显示 5 小时和周额度。", "Add at least one provider token to see 5-hour and weekly quotas here."),
                        systemImage: "key.slash"
                    )
                } else {
                    UnavailableStateView(
                        title: L10n.t("暂无可用渠道", "No Available Providers"),
                        detail: L10n.t("已配置的渠道暂时没有可用额度数据，请检查 Token 后重试。", "Configured providers have no available quota data. Check the tokens and try again."),
                        systemImage: "chart.bar.xaxis"
                    )
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(dashboardProviderGroups, id: \.provider) { group in
                        Button {
                            triggerHaptic(.light)
                            selectedProvider = group.provider
                        } label: {
                            ProviderGridCard(
                                provider: group.provider,
                                accounts: group.rows
                            )
                        }
                        .buttonStyle(.plain)
                        .draggable(group.provider.rawValue)
                        .dropDestination(for: String.self) { items, location in
                            guard let droppedID = items.first else { return false }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                model.reorderProvider(from: droppedID, to: group.provider.rawValue)
                            }
                            triggerHaptic(.medium)
                            return true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Analytics & Summary Charts Section

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !dashboardProviderGroups.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("账号健康度统计", "Account Status Health"))
                        .font(.headline)

                    HStack(spacing: 10) {
                        HealthMetricCard(
                            title: L10n.t("正常可用", "Healthy"),
                            count: model.healthyCount,
                            color: AccessDeckTheme.success,
                            icon: "checkmark.circle.fill"
                        )

                        HealthMetricCard(
                            title: L10n.t("额度紧张", "Low/Exhausted"),
                            count: lowOrExhaustedCount,
                            color: AccessDeckTheme.warning,
                            icon: "exclamationmark.triangle.fill"
                        )

                        HealthMetricCard(
                            title: L10n.t("已忽略", "Ignored"),
                            count: ignoredCount,
                            color: .secondary,
                            icon: "eye.slash.fill"
                        )
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.caption)
                    Text(L10n.t("点击渠道卡片可管理账号、置顶或忽略；长按卡片或点击右上角“调整排序”可拖拽排序。", "Tap any provider card to manage, pin or ignore accounts; long-press or tap Reorder to sort."))
                        .font(.caption)
                }
                .foregroundStyle(Color.secondary.opacity(0.85))
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
        }
    }

    private var dashboardProviderGroups: [(provider: QuotaProvider, rows: [AccountQuota])] {
        Array(model.groupedAccounts.compactMap { group in
            let rows = StatusBarSummary.enabledAccounts(in: group.rows, settings: model.settings)
            return rows.isEmpty ? nil : (group.provider, rows)
        }.prefix(3))
    }

    private var lowOrExhaustedCount: Int {
        model.accounts.filter { row in
            let isLocallyDisabled = model.isAccountDisabled(row)
            guard !isLocallyDisabled else { return false }
            let minRemaining = row.snapshot.windows.compactMap(\.remainingPercent).min()
            return QuotaDisplayScale.isLow(minRemaining)
        }.count
    }

    private var ignoredCount: Int {
        model.accounts.filter { model.isAccountDisabled($0) }.count
    }
    // MARK: - Unconfigured Banner

    private var unconfiguredBanner: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(AccessDeckTheme.accent)
                .padding(.top, 16)

            VStack(spacing: 6) {
                Text(L10n.t("连接到 CLIProxyAPI", "Connect to CLIProxyAPI"))
                    .font(.title2.weight(.bold))
                Text(L10n.t("输入你本机的 CLIProxyAPI 服务地址与管理密钥以同步各订阅账号额度。", "Enter your CLIProxyAPI management URL and secret key to track quotas."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button {
                showingSettings = true
            } label: {
                Text(L10n.t("打开服务设置", "Open Server Settings"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AccessDeckTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Computed Properties

    private var connectionIndicatorColor: Color {
        switch model.connection {
        case .online, .idle:
            AccessDeckTheme.success
        case .refreshing:
            AccessDeckTheme.warning
        case .failed:
            AccessDeckTheme.danger
        case .unconfigured:
            .secondary
        }
    }

    private var connectionStatusTitle: String {
        switch model.connection {
        case .online:
            L10n.t("已连接并同步", "Connected & Synced")
        case .idle:
            L10n.t("就绪", "Ready")
        case .refreshing:
            L10n.t("正在刷新额度...", "Refreshing quotas...")
        case .failed(let msg):
            L10n.t("连接失败: \(msg)", "Connection error: \(msg)")
        case .unconfigured:
            L10n.t("未配置服务", "Not configured")
        }
    }

    private var connectionMethodIcon: String {
        model.settings.isConfigured ? "arrow.left.arrow.right" : "questionmark.circle"
    }

    private var connectionMethodTitle: String {
        guard model.settings.isConfigured else {
            return L10n.t("尚未配置", "Not configured")
        }
        return L10n.t("CLIProxyAPI 直连", "Direct CLIProxyAPI")
    }

    private var lowestQuotaText: String {
        let lowest = model.accounts.flatMap(\.snapshot.windows).compactMap(\.remainingPercent).min()
        guard let lowest else { return "--" }
        return "\(Int(lowest.rounded()))%"
    }

    private var lowestQuotaColor: Color {
        let lowest = model.accounts.flatMap(\.snapshot.windows).compactMap(\.remainingPercent).min()
        return AccessDeckTheme.progressColor(for: .unknown, remaining: lowest)
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Subcomponents

private struct MetricBox: View {
    let title: String
    let value: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.primary.opacity(0.75))
            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(accentColor)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.primary.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProviderGridCard: View {
    @Environment(AppModel.self) private var model
    let provider: QuotaProvider
    let accounts: [AccountQuota]

    var body: some View {
        let isHidden = model.isProviderHidden(provider)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ProviderGlyph(provider: provider, size: 16)
                Text(provider.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if isHidden {
                    Image(systemName: "eye.slash")
                        .font(.caption2)
                        .foregroundStyle(AccessDeckTheme.warning)
                }
                Spacer()
                Text("\(accounts.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                quotaRow(label: L10n.t("5 小时", "5h"), remaining: fiveHourRemaining)
                quotaRow(label: L10n.t("周额度", "Weekly"), remaining: weeklyRemaining)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(isHidden ? 0.7 : 1.0)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var fiveHourRemaining: Double? {
        StatusBarSummary.exactPooledRemaining(in: accounts, window: .fiveHour, settings: model.settings)
    }

    private var weeklyRemaining: Double? {
        StatusBarSummary.exactPooledRemaining(in: accounts, window: .weekly, settings: model.settings)
    }

    @ViewBuilder
    private func quotaRow(label: String, remaining: Double?) -> some View {
        let customHex = model.settings.customColorHex(for: provider)
        let color = AccessDeckTheme.progressColor(for: provider, remaining: remaining, customHex: customHex)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(AccessDeckTheme.percentText(remaining))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(color)
            }

            SegmentedPillBar(
                percent: remaining ?? 0,
                totalSegments: 36,
                barHeight: 9.0,
                segmentSpacing: 2.2,
                cornerRadius: 1.0,
                activeColor: color,
                inactiveColor: Color.primary.opacity(0.08)
            )
            .opacity(remaining == nil ? 0.7 : 1.0)
        }
    }

}

private struct HealthMetricCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProviderReorderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.orderedPreferenceProviders, id: \.self) { provider in
                        let count = model.accounts.filter { $0.account.provider == provider }.count
                        let isHidden = model.isProviderHidden(provider)
                        HStack(spacing: 12) {
                            Button {
                                triggerHaptic(.light)
                                model.toggleProviderHidden(provider)
                            } label: {
                                Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isHidden ? AccessDeckTheme.warning : AccessDeckTheme.accent)
                                    .frame(width: 28, height: 28)
                                    .background(Color.primary.opacity(0.05), in: Circle())
                            }
                            .buttonStyle(.plain)

                            ProviderGlyph(provider: provider, size: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(provider.displayName)
                                        .font(.body.weight(.medium))
                                    if isHidden {
                                        Text(L10n.t("已在看板中隐藏", "Hidden in dashboard"))
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(AccessDeckTheme.warning)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(AccessDeckTheme.warning.opacity(0.12), in: Capsule())
                                    }
                                }
                                Text("\(count) " + L10n.t("个订阅账号", "accounts"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .opacity(isHidden ? 0.6 : 1.0)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { source, destination in
                        triggerHaptic(.light)
                        model.moveStatusItems(from: source, to: destination)
                    }
                } header: {
                    Text(L10n.t("拖动右侧手柄调整渠道在看板中的显示顺序；点击眼睛图标可隐藏或显示该渠道", "Drag handles to reorder channels in dashboard; tap eye to toggle visibility"))
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(L10n.t("调整渠道排序与可见性", "Reorder & Visibility"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("完成", "Done")) {
                        triggerHaptic(.light)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
#endif
