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
        VStack(alignment: .leading, spacing: 0) {
            connectionFields
            Divider()
            providerFields
            Divider()
            footer
        }
        .background(ClipBarTheme.windowBackground)
        .tint(ClipBarTheme.accent)
        .frame(width: ClipBarTheme.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: prepareDraft)
    }

    private var connectionFields: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.spacingM) {
            HStack {
                Text(L10n.t("连接", "Connection"))
                    .font(.subheadline.weight(.semibold))
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

            RefreshIntervalStepper(seconds: $draft.refreshSeconds)
        }
        .padding(ClipBarTheme.spacingL)
    }

    private var providerFields: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.spacingM) {
            HStack(spacing: ClipBarTheme.spacingS) {
                Text(L10n.t("状态栏", "Menu bar"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle(
                    L10n.t("额度用尽时隐藏", "Hide when empty"),
                    isOn: Binding(
                        get: { model.settings.hideEmptyStatusItems },
                        set: { model.setHideEmptyStatusItems($0) }
                    )
                )
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            if model.orderedPreferenceProviders.isEmpty {
                Text(L10n.t("还没有账号，先保存连接并刷新。", "No accounts yet. Save the connection and refresh."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List {
                    ForEach(model.orderedPreferenceProviders, id: \.self) { provider in
                        SettingsProviderRow(
                            provider: provider,
                            accountCount: accounts(for: provider).count,
                            remaining: StatusBarSummary.pooledRemaining(in: accounts(for: provider)),
                            isVisible: Binding(
                                get: { model.isStatusItemVisible(provider) },
                                set: { model.setStatusItemVisible(provider, visible: $0) }
                            )
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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
        .padding(ClipBarTheme.spacingL)
    }

    private var footer: some View {
        HStack(spacing: ClipBarTheme.spacingS) {
            Button(L10n.t("取消", "Cancel"), action: model.closeSettings)
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button(L10n.t("保存并刷新", "Save & Refresh"), action: save)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isConfigured)
        }
        .padding(.horizontal, ClipBarTheme.spacingL)
        .padding(.vertical, ClipBarTheme.spacingM)
    }

    private var providerListHeight: CGFloat {
        CGFloat(max(model.orderedPreferenceProviders.count, 1)) * 36
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

    private func accounts(for provider: QuotaProvider) -> [AccountQuota] {
        model.accounts.filter { $0.account.provider == provider }
    }

    private func prepareDraft() {
        draft = model.settings
        focusedField = draft.managementKey.isEmpty ? .key : .url
    }

    private func toggleKeyVisibility() {
        revealsKey.toggle()
        focusedField = .key
    }

    private func save() {
        model.saveSettings(draft)
    }
}
