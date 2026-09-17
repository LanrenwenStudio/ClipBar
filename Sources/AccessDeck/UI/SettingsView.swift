#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = AppSettings.default
    @State private var selectedCategory: SettingsCategory = .connection
    @State private var revealsKey = false
    @FocusState private var focusedField: Field?

    private enum SettingsCategory: String, CaseIterable, Identifiable {
        case connection
        case display
        case providers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .connection: L10n.t("服务连接", "Service")
            case .display: L10n.t("菜单栏", "Menu Bar")
            case .providers: L10n.t("渠道外观", "Providers")
            }
        }

        var icon: String {
            switch self {
            case .connection: "network"
            case .display: "menubar.rectangle"
            case .providers: "slider.horizontal.3"
            }
        }
    }

    private enum Field: Hashable {
        case url
        case key
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            categoryTabs
            content
            footer
        }
        .padding(12)
        .frame(width: AccessDeckTheme.popoverWidth)
        .tint(AccessDeckTheme.accent)
        .onAppear(perform: prepareDraft)
        .onExitCommand(perform: model.closeSettings)
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: model.closeSettings) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.t("返回", "Back"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.t("返回额度面板", "Return to quota dashboard"))

            Spacer()

            Text(L10n.t("设置", "Settings"))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            ConnectionBadge(title: settingsConnectionBadgeTitle, color: settingsConnectionColor)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    // MARK: - Category Tabs
    private var categoryTabs: some View {
        HStack(spacing: 5) {
            ForEach(SettingsCategory.allCases) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 10))
                        Text(cat.title)
                            .font(.system(size: 11, weight: selectedCategory == cat ? .semibold : .medium))
                    }
                    .foregroundStyle(selectedCategory == cat ? Color.primary : Color.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(selectedCategory == cat ? Color.primary.opacity(0.09) : Color.primary.opacity(0.03))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(selectedCategory == cat ? Color.primary.opacity(0.15) : Color.clear, lineWidth: 0.5)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        switch selectedCategory {
        case .connection:
            connectionContent
        case .display:
            displayContent
        case .providers:
            providersContent
        }
    }

    // MARK: - Tab 1: Connection
    private var connectionContent: some View {
        VStack(spacing: 8) {
            SettingsSection(title: L10n.t("连接状态", "Connection Status"), icon: "network") {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(settingsConnectionText)
                                .font(.system(size: 11.5, weight: .semibold))
                            ConnectionBadge(title: settingsConnectionBadgeTitle, color: settingsConnectionColor)
                        }
                        Text(connectionSubtitle)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Button(action: refreshConnection) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(model.connection.isRefreshing ? 360 : 0))
                            .animation(
                                model.connection.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                value: model.connection.isRefreshing
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.settings.isConfigured || model.connection.isRefreshing)
                    .help(L10n.t("测试并刷新连接", "Test & Refresh"))
                }
            }

            SettingsSection(title: L10n.t("服务参数配置", "Service Configuration"), icon: "server.rack") {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsField(title: L10n.t("CLIProxyAPI 地址", "CLIProxyAPI URL")) {
                        TextField("http://127.0.0.1:8317", text: $draft.baseURL)
                            .modifier(AccessDeckFieldStyle(isFocused: focusedField == .url))
                            .focused($focusedField, equals: .url)
                    }

                    SettingsField(title: L10n.t("管理密钥", "Management Key")) {
                        HStack(spacing: 6) {
                            Group {
                                if revealsKey {
                                    TextField(L10n.t("输入 CPA 管理密钥", "Enter CPA key"), text: $draft.managementKey)
                                } else {
                                    SecureField(L10n.t("输入 CPA 管理密钥", "Enter CPA key"), text: $draft.managementKey)
                                }
                            }
                            .modifier(AccessDeckFieldStyle(isFocused: focusedField == .key))
                            .focused($focusedField, equals: .key)

                            Button(action: toggleKeyVisibility) {
                                Image(systemName: revealsKey ? "eye.slash" : "eye")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 26, height: 26)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.primary.opacity(0.04))
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(revealKeyTitle)
                        }
                    }

                    SettingsField(title: L10n.t("连接方式", "Connection Mode")) {
                        Picker(L10n.t("连接方式", "Connection Mode"), selection: $draft.connectionMode) {
                            ForEach(QuotaConnectionMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .controlSize(.small)

                        Text(draft.connectionMode.description)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }

                    RefreshIntervalPicker(seconds: $draft.refreshSeconds)
                }
            }
        }
    }

    // MARK: - Tab 2: Display & Menu Bar
    private var displayContent: some View {
        VStack(spacing: 8) {
            SettingsSection(title: L10n.t("系统集成", "System Integration"), icon: "macwindow.badge.plus") {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("开机自启", "Launch at Login"))
                            .font(.system(size: 11.5, weight: .medium))
                        Text(launchAtLoginDescription)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { model.launchAtLoginStatus.isRegistered },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }

            SettingsSection(title: L10n.t("状态栏显示", "Menu Bar Quota"), icon: "menubar.arrow.down.rectangle") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.t("显示模式", "Display Mode"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: statusQuotaDisplayBinding) {
                            Text(L10n.t("5小时", "5h")).tag(StatusQuotaDisplay.fiveHour)
                            Text(L10n.t("周额度", "Week")).tag(StatusQuotaDisplay.weekly)
                            Text(L10n.t("双额度", "Both")).tag(StatusQuotaDisplay.both)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 140)
                    }

                    Divider().opacity(0.3)

                    HStack {
                        Text(L10n.t("汇总基准", "Summary Base"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: statusQuotaWindowBinding) {
                            Text(L10n.t("5小时", "5h")).tag(StatusQuotaWindow.fiveHour)
                            Text(L10n.t("周额度", "Week")).tag(StatusQuotaWindow.weekly)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 110)
                    }

                    Text(statusQuotaWindowDescription)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }

            SettingsSection(title: L10n.t("行为与外观", "Preferences & Theme"), icon: "slider.horizontal.3") {
                VStack(spacing: 8) {
                    HStack {
                        Text(L10n.t("按剩余额度排序", "Sort by remaining quota"))
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { model.settings.sortByRemainingQuota },
                                set: { model.setSortByRemainingQuota($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    Divider().opacity(0.3)

                    HStack {
                        Text(L10n.t("外观主题", "Theme"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { model.settings.appTheme },
                            set: { model.setAppTheme($0) }
                        )) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 150)
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: Providers & Appearance
    private var providersContent: some View {
        VStack(spacing: 8) {
            if model.orderedPreferenceProviders.isEmpty {
                UnavailableStateView(
                    title: L10n.t("暂无渠道数据", "No Providers Yet"),
                    detail: L10n.t("请先在「服务连接」中正确填写 CPA 地址与密钥，拉取订阅数据。", "Configure CPA in Service tab first to load account quotas."),
                    systemImage: "tray"
                )
            } else {
                HStack {
                    Text(L10n.t("渠道排序与个性化", "Providers & Order"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(L10n.t("共 \(model.orderedPreferenceProviders.count) 个渠道", "\(model.orderedPreferenceProviders.count) providers"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)

                ViewThatFits(in: .vertical) {
                    VStack(spacing: 5) {
                        ForEach(Array(model.orderedPreferenceProviders.enumerated()), id: \.element) { index, provider in
                            providerRow(at: index, provider: provider)
                        }
                    }
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(Array(model.orderedPreferenceProviders.enumerated()), id: \.element) { index, provider in
                                providerRow(at: index, provider: provider)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: AccessDeckTheme.popoverMaxListHeight)
                }
            }
        }
    }

    @ViewBuilder
    private func providerRow(at index: Int, provider: QuotaProvider) -> some View {
        SettingsProviderRow(
            provider: provider,
            accountCount: accounts(for: provider).count,
            remaining: StatusBarSummary.pooledRemaining(
                in: accounts(for: provider),
                preferredWindow: model.settings.statusQuotaWindow
            ),
            canMoveUp: index > 0,
            canMoveDown: index < model.orderedPreferenceProviders.count - 1,
            onMoveUp: { model.swapProviderOrder(at: index, with: index - 1) },
            onMoveDown: { model.swapProviderOrder(at: index, with: index + 1) },
            isVisible: Binding(
                get: { model.isStatusItemVisible(provider) },
                set: { model.setStatusItemVisible(provider, visible: $0) }
            ),
            quotaDisplay: Binding(
                get: { model.settings.statusQuotaDisplayOverride(for: provider) },
                set: { model.setStatusQuotaDisplay($0, for: provider) }
            ),
            customColorHex: Binding(
                get: { model.settings.customColorHex(for: provider) },
                set: { model.setProviderCustomColor($0, for: provider) }
            )
        )
    }

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 9.5))
                Text("AccessDeck v\(appVersion)")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.tertiary)

            Spacer()

            if selectedCategory == .connection {
                Button(action: save) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L10n.t("保存连接", "Save & Apply"))
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!draft.isConfigured)
            } else {
                Button(action: model.closeSettings) {
                    Text(L10n.t("完成", "Done"))
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Helpers
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.1"
    }

    private var statusQuotaDisplayBinding: Binding<StatusQuotaDisplay> {
        Binding(
            get: { model.settings.statusQuotaDisplay },
            set: { model.setStatusQuotaDisplay($0) }
        )
    }

    private var statusQuotaWindowBinding: Binding<StatusQuotaWindow> {
        Binding(
            get: { model.settings.statusQuotaWindow },
            set: { model.setStatusQuotaWindow($0) }
        )
    }

    private var settingsConnectionText: String {
        switch model.connection {
        case .unconfigured:
            L10n.t("等待配置", "Not configured")
        case .refreshing:
            L10n.t("刷新中…", "Refreshing…")
        case .failed:
            L10n.t("连接失败", "Connection failed")
        case .idle, .online:
            L10n.t("CPA 运行在线", "CPA Online")
        }
    }

    private var settingsConnectionBadgeTitle: String {
        switch model.connection {
        case .unconfigured:
            L10n.t("未配置", "Unconfigured")
        case .refreshing:
            L10n.t("刷新中", "Refreshing")
        case .failed:
            L10n.t("异常", "Error")
        case .idle, .online:
            L10n.t("在线", "Online")
        }
    }

    private var connectionSubtitle: String {
        switch model.connection {
        case .unconfigured:
            L10n.t("请输入本地 CPA 管理接口与密钥", "Enter CPA management URL and key")
        case .refreshing:
            L10n.t("正在拉取最新订阅额度…", "Fetching subscription quotas…")
        case .failed(let msg):
            msg
        case .idle, .online:
            L10n.t(
                "\(model.healthyCount)/\(model.accounts.count) 账号可用 · 上次同步 \(model.lastRefreshText)",
                "\(model.healthyCount)/\(model.accounts.count) accounts ready · synced \(model.lastRefreshText)"
            )
        }
    }

    private var settingsConnectionColor: Color {
        switch model.connection {
        case .unconfigured:
            .secondary
        case .refreshing:
            AccessDeckTheme.accent
        case .failed:
            AccessDeckTheme.danger
        case .idle, .online:
            AccessDeckTheme.success
        }
    }

    private var revealKeyTitle: String {
        revealsKey ? L10n.t("隐藏密钥", "Hide key") : L10n.t("显示密钥", "Show key")
    }

    private var launchAtLoginDescription: String {
        switch model.launchAtLoginStatus {
        case .requiresApproval:
            L10n.t(
                "已注册，请在系统设置中允许 AccessDeck。",
                "Allow AccessDeck in System Settings > Login Items."
            )
        case .notFound:
            L10n.t("当前应用无法注册为登录项。", "Cannot register login item.")
        case .enabled:
            L10n.t("已开启，登录系统后常驻菜单栏。", "On. Runs in menu bar on system login.")
        case .notRegistered:
            L10n.t("登录 macOS 后自动在菜单栏运行。", "Runs in menu bar on macOS login.")
        }
    }

    private var statusQuotaWindowDescription: String {
        L10n.t(
            "基准窗口将影响状态栏汇总与展示，缺失时自动平滑回退。",
            "Affects menu bar summary quota, auto fallback if window missing."
        )
    }

    private func accounts(for provider: QuotaProvider) -> [AccountQuota] {
        model.accounts.filter { $0.account.provider == provider }
    }

    private func prepareDraft() {
        draft = model.settings
        draft.refreshSeconds = draft.clampedRefreshSeconds
        focusedField = nil
    }

    private func toggleKeyVisibility() {
        revealsKey.toggle()
        focusedField = .key
    }

    private func refreshConnection() {
        Task { await model.refresh(force: true) }
    }

    private func save() {
        model.saveSettings(draft)
    }
}
#endif
