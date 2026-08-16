#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = AppSettings.default
    @State private var revealsKey = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case url
        case key
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ClipBarTheme.spacingM) {
                    SettingsSection(
                        title: L10n.t("连接", "Connection")
                    ) {
                        connectionFields
                    }

                    SettingsSection(
                        title: L10n.t("显示与偏好", "Display & Preferences"),
                        subtitle: L10n.t(
                            "控制启动方式、额度汇总与账号排序规则。",
                            "Control startup, quota summary, and account sorting behavior."
                        )
                    ) {
                        launchAtLoginRow
                        Divider()
                        statusQuotaWindowRow
                        Divider()
                        sortByRemainingRow
                    }

                    SettingsSection(
                        title: L10n.t("告警与通知", "Alerts & Notifications"),
                        subtitle: L10n.t(
                            "当订阅额度过低或耗尽时接收 macOS 系统通知提醒。",
                            "Receive macOS system notifications when subscription quota is low or exhausted."
                        )
                    ) {
                        notificationsRow
                        if model.settings.enableNotifications {
                            Divider()
                            lowQuotaAlertRow
                        }
                    }

                    SettingsSection(
                        title: L10n.t("状态栏", "Menu bar"),
                        subtitle: L10n.t(
                            "选择渠道、调整顺序，并控制哪些内容显示在菜单栏。",
                            "Choose providers, reorder them, and control what appears in the menu bar."
                        )
                    ) {
                        hideEmptyRow
                        Divider()
                        providerContent
                    }
                }
                .padding(ClipBarTheme.spacingL)
            }
            .scrollIndicators(.hidden)

            footer
        }
        .background(.regularMaterial)
        .tint(ClipBarTheme.accent)
        .frame(width: ClipBarTheme.settingsWidth, height: ClipBarTheme.settingsHeight)
        .onAppear(perform: prepareDraft)
    }

    private var connectionFields: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.spacingM) {
            HStack {
                Text(L10n.t("连接状态", "Connection status"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                ConnectionBadge(title: settingsConnectionText, color: settingsConnectionColor)
            }

            SettingsField(title: L10n.t("管理地址", "Management URL")) {
                TextField("http://127.0.0.1:8317", text: $draft.baseURL)
                    .modifier(ClipBarFieldStyle(isFocused: focusedField == .url))
                    .focused($focusedField, equals: .url)
            }

            SettingsField(title: L10n.t("管理密钥", "Management key")) {
                HStack(spacing: ClipBarTheme.spacingS) {
                    Group {
                        if revealsKey {
                            TextField(L10n.t("粘贴 secret-key", "Paste secret-key"), text: $draft.managementKey)
                        } else {
                            SecureField(L10n.t("粘贴 secret-key", "Paste secret-key"), text: $draft.managementKey)
                        }
                    }
                    .modifier(ClipBarFieldStyle(isFocused: focusedField == .key))
                    .focused($focusedField, equals: .key)

                    Button(revealKeyTitle, systemImage: revealsKey ? "eye.slash" : "eye", action: toggleKeyVisibility)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help(L10n.t("显示或隐藏密钥", "Show or hide the key"))
                }
            }

            RefreshIntervalPicker(seconds: $draft.refreshSeconds)
        }
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: ClipBarTheme.spacingM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("登录时启动", "Launch at login"))
                        .font(.body.weight(.medium))

                    Text(launchAtLoginDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let error = model.launchAtLoginError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(ClipBarTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } icon: {
                Image(systemName: "power.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ClipBarTheme.accent)
            }

            Spacer(minLength: ClipBarTheme.spacingM)

            Toggle(
                L10n.t("登录时启动", "Launch at login"),
                isOn: Binding(
                    get: { model.launchAtLoginStatus.isRegistered },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .frame(minHeight: 46)
    }

    private var statusQuotaWindowRow: some View {
        HStack(spacing: ClipBarTheme.spacingM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("汇总窗口", "Summary window"))
                        .font(.body.weight(.medium))
                    Text(statusQuotaWindowDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundStyle(ClipBarTheme.accent)
            }

            Spacer(minLength: ClipBarTheme.spacingM)

            Picker(L10n.t("汇总窗口", "Summary window"), selection: statusQuotaWindowBinding) {
                Text(L10n.t("5 小时", "5 hours"))
                    .tag(StatusQuotaWindow.fiveHour)
                Text(L10n.t("周额度", "Weekly"))
                    .tag(StatusQuotaWindow.weekly)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 154)
        }
        .frame(minHeight: 46)
    }
    private var sortByRemainingRow: some View {
        HStack(spacing: ClipBarTheme.spacingM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("按剩余额度优先排序", "Sort by remaining quota"))
                        .font(.body.weight(.medium))
                    Text(L10n.t("在账号列表中，剩余额度更高的账号排在前面（置顶账号始终优先）。", "Display accounts with higher remaining quota first (pinned accounts remain on top)."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.title2)
                    .foregroundStyle(ClipBarTheme.accent)
            }

            Spacer(minLength: ClipBarTheme.spacingM)

            Toggle(
                L10n.t("按剩余额度优先排序", "Sort by remaining quota"),
                isOn: Binding(
                    get: { model.settings.sortByRemainingQuota },
                    set: { model.setSortByRemainingQuota($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .frame(minHeight: 46)
    }

    private var notificationsRow: some View {
        HStack(spacing: ClipBarTheme.spacingM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("启用额度告警通知", "Enable quota notifications"))
                        .font(.body.weight(.medium))
                    Text(L10n.t("后台检测到账号额度过低或耗尽时发送系统横幅通知。", "Send banner alerts when an account is low on quota or completely exhausted."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(ClipBarTheme.accent)
            }

            Spacer(minLength: ClipBarTheme.spacingM)

            Toggle(
                L10n.t("启用额度告警通知", "Enable quota notifications"),
                isOn: Binding(
                    get: { model.settings.enableNotifications },
                    set: { model.setEnableNotifications($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .frame(minHeight: 46)
    }

    private var lowQuotaAlertRow: some View {
        HStack(spacing: ClipBarTheme.spacingM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("低额度提醒阈值", "Low quota threshold"))
                        .font(.body.weight(.medium))
                    Text(L10n.t("当任意额度窗口剩余百分比低于该值时触发提醒。", "Trigger alert when any quota window drops below this percentage."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(ClipBarTheme.warning)
            }

            Spacer(minLength: ClipBarTheme.spacingM)

            Picker(
                L10n.t("低额度提醒阈值", "Low quota threshold"),
                selection: Binding(
                    get: { model.settings.lowQuotaAlertThreshold },
                    set: { model.setLowQuotaAlertThreshold($0) }
                )
            ) {
                Text("15%").tag(15)
                Text("10%").tag(10)
                Text("5%").tag(5)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 154)
        }
        .frame(minHeight: 46)
    }

    private var hideEmptyRow: some View {
        HStack(spacing: ClipBarTheme.spacingM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("隐藏空额度渠道", "Hide empty providers"))
                        .font(.body.weight(.medium))
                    Text(L10n.t("剩余额度为 0 时，不在菜单栏显示该渠道。", "Hide providers from the menu bar when their remaining quota is 0."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "eye.slash.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ClipBarTheme.accent)
            }

            Spacer(minLength: ClipBarTheme.spacingM)

            Toggle(
                L10n.t("隐藏空额度渠道", "Hide empty providers"),
                isOn: Binding(
                    get: { model.settings.hideEmptyStatusItems },
                    set: { model.setHideEmptyStatusItems($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .frame(minHeight: 46)
    }

    @ViewBuilder
    private var providerContent: some View {
        if model.orderedPreferenceProviders.isEmpty {
            Text(L10n.t("还没有账号，先保存连接并刷新。", "No accounts yet. Save the connection and refresh."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, ClipBarTheme.spacingS)
        } else {
            List {
                ForEach(model.orderedPreferenceProviders, id: \.self) { provider in
                    SettingsProviderRow(
                        provider: provider,
                        accountCount: accounts(for: provider).count,
                        remaining: StatusBarSummary.pooledRemaining(
                            in: accounts(for: provider),
                            preferredWindow: model.settings.statusQuotaWindow
                        ),
                        isVisible: Binding(
                            get: { model.isStatusItemVisible(provider) },
                            set: { model.setStatusItemVisible(provider, visible: $0) }
                        )
                    )
                    .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: model.moveStatusItems)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .frame(height: providerListHeight)
        }
    }

    private var footer: some View {
        HStack(spacing: ClipBarTheme.spacingS) {
            Button(L10n.t("取消", "Cancel"), action: model.closeSettings)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderless)

            Spacer()

            Button(L10n.t("保存", "Save"), action: save)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(ClipBarTheme.accent)
                .foregroundStyle(.white)
                .controlSize(.large)
                .disabled(!draft.isConfigured)
        }
        .padding(.horizontal, ClipBarTheme.spacingL)
        .padding(.vertical, ClipBarTheme.spacingM)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var providerListHeight: CGFloat {
        CGFloat(max(model.orderedPreferenceProviders.count, 1)) * 46 + 8
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
            L10n.t("未配置", "Not configured")
        case .refreshing:
            L10n.t("刷新中", "Refreshing")
        case .failed:
            L10n.t("连接失败", "Error")
        case .idle, .online:
            L10n.t("已连接", "Connected")
        }
    }

    private var settingsConnectionColor: Color {
        switch model.connection {
        case .unconfigured:
            .secondary
        case .refreshing:
            ClipBarTheme.accent
        case .failed:
            ClipBarTheme.danger
        case .idle, .online:
            ClipBarTheme.success
        }
    }

    private var revealKeyTitle: String {
        L10n.t("显示或隐藏密钥", "Show or hide the key")
    }

    private var launchAtLoginDescription: String {
        switch model.launchAtLoginStatus {
        case .requiresApproval:
            L10n.t(
                "已注册，请在系统设置 > 通用 > 登录项中允许 ClipBar。",
                "Registered. Allow ClipBar in System Settings > General > Login Items."
            )
        case .notFound:
            L10n.t("当前应用无法注册为登录项。", "This app cannot be registered as a login item.")
        case .enabled:
            L10n.t("已开启，登录 macOS 后自动显示。", "On. Show ClipBar automatically when you log in to macOS.")
        case .notRegistered:
            L10n.t("登录 macOS 后自动显示 ClipBar。", "Show ClipBar automatically when you log in to macOS.")
        }
    }

    private var statusQuotaWindowDescription: String {
        L10n.t(
            "影响状态栏和渠道汇总；没有对应窗口时自动回退。",
            "Used by the menu bar and provider summaries, with automatic fallback."
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

    private func save() {
        model.saveSettings(draft)
    }
}
#endif
