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
        HStack(spacing: 8) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 13))
                .foregroundStyle(model.launchAtLoginStatus.isRegistered ? Color.blue : Color.secondary.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("登录时启动", "Launch at login"))
                    .font(.system(size: 11.5, weight: .medium))

                Text(launchAtLoginDescription)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let error = model.launchAtLoginError {
                    Text(error)
                        .font(.system(size: 9.5))
                        .foregroundStyle(ClipBarTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

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
        .padding(.vertical, 2)
    }

    private var statusQuotaWindowRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("汇总窗口", "Summary window"))
                    .font(.system(size: 11.5, weight: .medium))
                Text(statusQuotaWindowDescription)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Picker(L10n.t("汇总窗口", "Summary window"), selection: statusQuotaWindowBinding) {
                Text(L10n.t("5 小时", "5 hours"))
                    .tag(StatusQuotaWindow.fiveHour)
                Text(L10n.t("周额度", "Weekly"))
                    .tag(StatusQuotaWindow.weekly)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 130)
        }
        .padding(.vertical, 2)
    }
    private var sortByRemainingRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("按剩余额度优先排序", "Sort by remaining quota"))
                    .font(.system(size: 11.5, weight: .medium))
                Text(L10n.t("在账号列表中，剩余额度更高的账号排在前面（置顶账号始终优先）。", "Display accounts with higher remaining quota first (pinned accounts remain on top)."))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

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
        .padding(.vertical, 2)
    }


    private var hideEmptyRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("隐藏空额度渠道", "Hide empty providers"))
                    .font(.system(size: 11.5, weight: .medium))
                Text(L10n.t("剩余额度为 0 时，不在菜单栏显示该渠道。", "Hide providers from the menu bar when their remaining quota is 0."))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

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
        .padding(.vertical, 2)
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
        HStack(spacing: 8) {
            Button(L10n.t("取消", "Cancel"), action: model.closeSettings)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderless)
                .controlSize(.small)

            Spacer()

            Button(L10n.t("保存", "Save"), action: save)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!draft.isConfigured)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var providerListHeight: CGFloat {
        CGFloat(max(model.orderedPreferenceProviders.count, 1)) * 32 + 6
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
