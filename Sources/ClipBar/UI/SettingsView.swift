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
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSection(title: L10n.t("服务与连接", "Service & Connection")) {
                        connectionFields
                    }

                    SettingsSection(title: L10n.t("菜单栏与显示", "Menu Bar & Display")) {
                        VStack(spacing: 10) {
                            launchAtLoginRow
                            Divider().opacity(0.6)
                            statusQuotaDisplayRow
                            Divider().opacity(0.6)
                            statusQuotaWindowRow
                            Divider().opacity(0.6)
                            sortByRemainingRow
                            Divider().opacity(0.6)
                            hideEmptyRow
                        }
                    }

                    SettingsSection(title: L10n.t("渠道排序与外观", "Providers & Appearance")) {
                        providerContent
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)

            Divider()

            footer
        }
        .background(.regularMaterial)
        .tint(ClipBarTheme.accent)
        .frame(width: ClipBarTheme.settingsWidth, height: ClipBarTheme.settingsHeight)
        .onAppear(perform: prepareDraft)
    }

    private var connectionFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("服务状态", "Status"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                ConnectionBadge(title: settingsConnectionText, color: settingsConnectionColor)
            }

            SettingsField(title: L10n.t("后端地址", "Backend URL")) {
                TextField(AppSettings.backendURL, text: $draft.backendURL)
                    .modifier(ClipBarFieldStyle(isFocused: false))
            }

            SettingsField(title: L10n.t("访问令牌", "Token")) {
                HStack(spacing: ClipBarTheme.spacingS) {
                    Group {
                        if revealsKey {
                            TextField(L10n.t("后端 Token", "Token"), text: $draft.backendAccessToken)
                        } else {
                            SecureField(L10n.t("后端 Token", "Token"), text: $draft.backendAccessToken)
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
                .overlay(alignment: .bottomLeading) {
                    if let error = model.backendSettingsSyncError, draft.usesBackend {
                        Text(L10n.t("同步失败：\(error)", "Sync failed: \(error)"))
                            .font(.system(size: 9))
                            .foregroundStyle(ClipBarTheme.danger)
                            .offset(y: 16)
                    }
                }
        }
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 12))
                .foregroundStyle(model.launchAtLoginStatus.isRegistered ? Color.blue : Color.secondary.opacity(0.7))

            Text(L10n.t("开机自启", "Launch at login"))
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 8)

            Toggle(
                L10n.t("开机自启", "Launch at login"),
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

    private var statusQuotaDisplayRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "menubar.arrow.down.rectangle")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            Text(L10n.t("状态栏显示", "Status bar"))
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 8)

            Picker(L10n.t("状态栏显示", "Status bar"), selection: statusQuotaDisplayBinding) {
                Text(L10n.t("5小时", "5h")).tag(StatusQuotaDisplay.fiveHour)
                Text(L10n.t("周额度", "Week")).tag(StatusQuotaDisplay.weekly)
                Text(L10n.t("双额度", "Both")).tag(StatusQuotaDisplay.both)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 150)
        }
    }

    private var statusQuotaWindowRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            Text(L10n.t("汇总基准", "Summary base"))
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 8)

            Picker(L10n.t("汇总基准", "Summary base"), selection: statusQuotaWindowBinding) {
                Text(L10n.t("5小时", "5h")).tag(StatusQuotaWindow.fiveHour)
                Text(L10n.t("周额度", "Week")).tag(StatusQuotaWindow.weekly)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 120)
        }
    }

    private var sortByRemainingRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            Text(L10n.t("按剩余额度从高到低排序", "Sort accounts by remaining"))
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 8)

            Toggle(
                L10n.t("按剩余额度从高到低排序", "Sort accounts by remaining"),
                isOn: Binding(
                    get: { model.settings.sortByRemainingQuota },
                    set: { model.setSortByRemainingQuota($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private var hideEmptyRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            Text(L10n.t("耗尽时自动隐藏渠道", "Hide provider when empty"))
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 8)

            Toggle(
                L10n.t("耗尽时自动隐藏渠道", "Hide provider when empty"),
                isOn: Binding(
                    get: { model.settings.hideEmptyStatusItems },
                    set: { model.setHideEmptyStatusItems($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
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
        if draft.usesBackend {
            draft.baseURL = model.settings.baseURL
            draft.managementKey = model.settings.managementKey
        }
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
