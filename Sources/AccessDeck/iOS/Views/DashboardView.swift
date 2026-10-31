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
                subtitle: L10n.t("所有渠道活跃窗口", "All active windows"),
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
                HStack(spacing: 6) {
                    Text(L10n.t("多渠道", "Multi-Provider"))
                        .font(.headline)
                    if hiddenProvidersCount > 0 {
                        Text(L10n.t("\(hiddenProvidersCount) 个已隐藏", "\(hiddenProvidersCount) hidden"))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AccessDeckTheme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AccessDeckTheme.warning.opacity(0.12), in: Capsule())
                    }
                }
                Spacer()
                if !model.groupedAccounts.isEmpty {
                    Button {
                        triggerHaptic(.light)
                        showingReorderSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.2")
                            Text(L10n.t("渠道管理", "Manage"))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AccessDeckTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AccessDeckTheme.accent.opacity(0.12), in: Capsule())
                    }
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
                        detail: L10n.t("添加至少一个渠道 Token 后，这里会显示各渠道实时额度与健康状态。", "Add at least one provider token to see real-time quotas and health here."),
                        systemImage: "key.slash"
                    )
                } else {
                    UnavailableStateView(
                        title: L10n.t("暂无可见渠道", "No Visible Channels"),
                        detail: L10n.t("所有渠道均已设为隐藏。点击右上角“渠道管理”可重新开启展示。", "All channels are hidden. Tap Manage above to show them again."),
                        systemImage: "eye.slash"
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
                        .contextMenu {
                            Button(role: .destructive) {
                                triggerHaptic(.medium)
                                model.toggleProviderHidden(group.provider)
                            } label: {
                                Label(L10n.t("在看板中隐藏此渠道", "Hide Channel"), systemImage: "eye.slash")
                            }
                        }
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
        model.groupedAccounts.compactMap { group in
            guard !model.isProviderHidden(group.provider) else { return nil }
            let rows = StatusBarSummary.enabledAccounts(in: group.rows, settings: model.settings)
            return rows.isEmpty ? nil : (group.provider, rows)
        }
    }

    private var hiddenProvidersCount: Int {
        model.groupedAccounts.filter { model.isProviderHidden($0.provider) }.count
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
                Text(L10n.t("连接到 Magpie", "Connect to Magpie"))
                    .font(.title2.weight(.bold))
                Text(L10n.t("输入 Magpie 管理地址与网页密钥以同步订阅账号额度。", "Enter your Magpie management URL and web key to track quotas."))
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
        return L10n.t("Magpie 直连", "Direct Magpie")
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

private struct QuotaMetricItem: Identifiable {
    let id: String
    let label: String
    let remaining: Double?
    let detail: String?
}

private struct ProviderGridCard: View {
    @Environment(AppModel.self) private var model
    let provider: QuotaProvider
    let accounts: [AccountQuota]

    var body: some View {
        let isHidden = model.isProviderHidden(provider)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 5) {
                ProviderGlyph(provider: provider, size: 14.5, tint: AccessDeckTheme.providerColor(for: provider))
                    .frame(width: 14.5, height: 14.5)
                Text(provider == .antigravity ? "Agy" : provider.displayName)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isFreePlanProvider && quotaItems.isEmpty {
                    Text(L10n.t("免费", "Free"))
                        .font(.system(size: 9.0, weight: .semibold))
                        .foregroundStyle(AccessDeckTheme.success)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.2)
                        .background(AccessDeckTheme.success.opacity(0.12), in: Capsule())
                }
                if isHidden {
                    Image(systemName: "eye.slash")
                        .font(.caption2)
                        .foregroundStyle(AccessDeckTheme.warning)
                }
                Spacer(minLength: 2)
                Text("\(accounts.count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            if !quotaItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(quotaItems) { item in
                        quotaRow(label: item.label, remaining: item.remaining, detail: item.detail)
                    }
                }
            } else if isFreePlanProvider {
                freePlanStatusView
            } else if let error = accounts.compactMap(\.snapshot.error).first {
                errorStatusView(error: error)
            } else {
                emptyStatusView
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .top)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(isHidden ? 0.7 : 1.0)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var quotaItems: [QuotaMetricItem] {
        var items: [QuotaMetricItem] = []

        if let fiveHour = fiveHourRemaining {
            items.append(QuotaMetricItem(
                id: "5h",
                label: L10n.t("5 小时", "5h"),
                remaining: fiveHour,
                detail: nil
            ))
        }

        if let weekly = weeklyRemaining {
            items.append(QuotaMetricItem(
                id: "7d",
                label: L10n.t("周额度", "Weekly"),
                remaining: weekly,
                detail: nil
            ))
        }

        if items.count < 2 {
            let customItems = extractCustomQuotaItems()
            for custom in customItems {
                if items.count < 2 && !items.contains(where: { $0.id == custom.id }) {
                    items.append(custom)
                }
            }
        }

        return items
    }

    private func extractCustomQuotaItems() -> [QuotaMetricItem] {
        let enabled = accounts.filter { !model.isAccountDisabled($0) }
        let activeAccounts = enabled.isEmpty ? accounts : enabled
        let allWindows = activeAccounts.flatMap(\.snapshot.windows)

        // 1. Antigravity (Agy) 专属精简：分别显示 Argon 和 Gemini
        if provider == .antigravity {
            var argonWindows: [QuotaWindow] = []
            var geminiWindows: [QuotaWindow] = []

            for window in allWindows {
                let combined = (window.label + " " + window.id).lowercased()
                if combined.contains("high") || (combined.contains("argon") && !combined.contains("low")) {
                    argonWindows.append(window)
                } else if combined.contains("low") || combined.contains("gemini") {
                    geminiWindows.append(window)
                }
            }

            if argonWindows.isEmpty && geminiWindows.isEmpty && allWindows.count >= 2 {
                argonWindows.append(allWindows[0])
                geminiWindows.append(allWindows[1])
            } else if argonWindows.isEmpty && geminiWindows.isEmpty, let first = allWindows.first {
                argonWindows.append(first)
            }

            var agyItems: [QuotaMetricItem] = []
            if !argonWindows.isEmpty {
                let percents = argonWindows.compactMap(\.remainingPercent)
                let avg = percents.isEmpty ? nil : (percents.reduce(0, +) / Double(percents.count))
                agyItems.append(QuotaMetricItem(
                    id: "agy_argon",
                    label: "Argon",
                    remaining: avg,
                    detail: nil
                ))
            }
            if !geminiWindows.isEmpty {
                let percents = geminiWindows.compactMap(\.remainingPercent)
                let avg = percents.isEmpty ? nil : (percents.reduce(0, +) / Double(percents.count))
                agyItems.append(QuotaMetricItem(
                    id: "agy_gemini",
                    label: "Gemini",
                    remaining: avg,
                    detail: nil
                ))
            }
            if !agyItems.isEmpty {
                return agyItems
            }
        }

        var seenKeys = Set<String>()
        var items: [QuotaMetricItem] = []

        for window in allWindows {
            let lowerID = window.id.lowercased()
            if ["5h", "five-hour", "5-hour", "7d", "week", "weekly", "seven-day"].contains(lowerID) {
                continue
            }

            let baseKey: String
            let displayLabel: String
            if lowerID.contains("credit") || lowerID.contains("积分") {
                baseKey = "credits"
                displayLabel = L10n.t("积分", "Credits")
            } else if lowerID.contains("token") || lowerID.contains("free model") {
                baseKey = "tokens"
                displayLabel = "Token"
            } else if provider == .zcode {
                let rawName = window.label.components(separatedBy: " (").first ?? window.label
                let lowerName = rawName.lowercased()
                if lowerName.contains("flash") {
                    baseKey = "zcode_flash"
                    displayLabel = "Flash"
                } else if lowerName.contains("5.3") || lowerName.contains("glm") {
                    baseKey = "zcode_53"
                    displayLabel = "GLM-5.3"
                } else {
                    baseKey = window.id
                    displayLabel = rawName
                }
            } else {
                baseKey = window.id.components(separatedBy: ":").first ?? window.id
                displayLabel = window.label.components(separatedBy: " (").first ?? window.label
            }

            guard seenKeys.insert(baseKey).inserted else { continue }

            let matchingWindows = activeAccounts.compactMap { acct in
                acct.snapshot.windows.first { w in
                    let wLower = w.id.lowercased()
                    let wLabel = w.label.lowercased()
                    if baseKey == "credits" { return wLower.contains("credit") || wLower.contains("积分") }
                    if baseKey == "tokens" { return wLower.contains("token") || wLower.contains("free model") }
                    if baseKey == "zcode_flash" { return wLower.contains("flash") || wLabel.contains("flash") }
                    if baseKey == "zcode_53" { return (wLower.contains("5.3") || wLabel.contains("5.3")) && !wLower.contains("flash") && !wLabel.contains("flash") }
                    let key = w.id.components(separatedBy: ":").first ?? w.id
                    return key == baseKey
                }
            }

            let percents = matchingWindows.compactMap(\.remainingPercent)
            let avgPercent: Double? = percents.isEmpty ? nil : (percents.reduce(0, +) / Double(percents.count))

            let detail = matchingWindows.compactMap { w -> String? in
                if let openParen = w.label.firstIndex(of: "("),
                   let closeParen = w.label.lastIndex(of: ")"),
                   openParen < closeParen {
                    let inside = String(w.label[w.label.index(after: openParen)..<closeParen])
                    return inside.isEmpty ? nil : inside
                }
                return nil
            }.first

            items.append(QuotaMetricItem(
                id: baseKey,
                label: displayLabel,
                remaining: avgPercent,
                detail: formatCompactDetail(detail)
            ))
        }

        return items
    }

    private var isFreePlanProvider: Bool {
        let hasFreePlan = accounts.contains { acct in
            let plan = acct.snapshot.planType?.lowercased() ?? ""
            return plan.contains("free") || plan == "free"
        }
        let allEmptyWithoutError = accounts.allSatisfy { $0.snapshot.windows.isEmpty && $0.snapshot.error == nil }
        return hasFreePlan || allEmptyWithoutError
    }

    private var freePlanStatusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(AccessDeckTheme.success)
                Text(L10n.t("免费套餐", "Free Tier"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AccessDeckTheme.success)
            }
            Text(L10n.t("无速率限制 · 即开即用", "No rate limits · Ready"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func errorStatusView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(AccessDeckTheme.warning)
                Text(L10n.t("连接异常", "Error"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AccessDeckTheme.warning)
            }
            Text(error)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var emptyStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t("暂无活跃额度", "No active quota"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L10n.t("未检测到额度窗口", "No windows found"))
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var fiveHourRemaining: Double? {
        StatusBarSummary.exactPooledRemaining(in: accounts, window: .fiveHour, settings: model.settings)
    }

    private var weeklyRemaining: Double? {
        StatusBarSummary.exactPooledRemaining(in: accounts, window: .weekly, settings: model.settings)
    }

    private func formatCompactNumberString(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let num = Double(cleaned) else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if num == 0 {
            return "0"
        }
        if abs(num) >= 1_000_000_000 {
            let val = num / 1_000_000_000.0
            return val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))B" : String(format: "%.1fB", val)
        }
        if abs(num) >= 1_000_000 {
            let val = num / 1_000_000.0
            return val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))M" : String(format: "%.1fM", val)
        }
        if abs(num) >= 10_000 {
            let val = num / 1_000.0
            return val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))K" : String(format: "%.1fK", val)
        }
        if num.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(num))"
        }
        return String(format: "%.1f", num)
    }

    private func formatCompactDetail(_ detail: String?) -> String? {
        guard let detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty else {
            return nil
        }
        if detail.contains("/") {
            let parts = detail.components(separatedBy: "/")
            if parts.count == 2 {
                let left = formatCompactNumberString(parts[0])
                let right = formatCompactNumberString(parts[1])
                return "\(left) / \(right)"
            }
        }
        return formatCompactNumberString(detail)
    }

    @ViewBuilder
    private func quotaRow(label: String, remaining: Double?, detail: String? = nil) -> some View {
        let barColor = AccessDeckTheme.widgetBarColor(for: provider, remaining: remaining)
        let formattedDetail = formatCompactDetail(detail)

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let formattedDetail, !formattedDetail.isEmpty {
                    Text(formattedDetail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                Text(AccessDeckTheme.percentText(remaining))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            SegmentedPillBar(
                percent: remaining ?? 0,
                totalSegments: 36,
                barHeight: 14.0,
                segmentSpacing: 1.8,
                cornerRadius: 0,
                activeColor: barColor,
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

                            ProviderGlyph(provider: provider, size: 20, tint: AccessDeckTheme.providerColor(for: provider))
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
