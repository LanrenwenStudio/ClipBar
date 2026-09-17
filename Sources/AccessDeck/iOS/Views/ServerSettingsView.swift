#if os(iOS)
import SwiftUI

struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    @State private var draft = AppSettings.default
    @State private var revealsKey = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    private enum TestResult {
        case success(accountsCount: Int, latencyMs: Int)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                diagnosisSection
                behaviorSection
                providerColorsSection
                aboutSection
            }
            .navigationTitle(L10n.t("服务设置", "Server Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("取消", "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("保存", "Save")) {
                        save()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .tint(AccessDeckTheme.accent)
                    .disabled(!draft.isConfigured)
                }
            }
            .onAppear {
                draft = model.settings
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("CLIProxyAPI 地址", "CLIProxyAPI URL"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("http://127.0.0.1:8317", text: $draft.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PresetPill(title: "Localhost (127.0.0.1:8317)") {
                            draft.baseURL = "http://127.0.0.1:8317"
                        }
                        PresetPill(title: "CPA LAN · 8317") {
                            draft.baseURL = AppSettings.defaultBaseURL
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("连接方式", "Connection Mode"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker(L10n.t("连接方式", "Connection Mode"), selection: $draft.connectionMode) {
                    Text(L10n.t("直连", "Direct"))
                        .tag(QuotaConnectionMode.direct)
                    Text(L10n.t("插件", "Plugin"))
                        .tag(QuotaConnectionMode.plugin)
                }
                .pickerStyle(.segmented)

                Text(draft.connectionMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("管理密钥", "Management Key"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    if revealsKey {
                        TextField(L10n.t("输入 CPA 管理密钥", "Enter CPA management key"), text: $draft.managementKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(L10n.t("输入 CPA 管理密钥", "Enter CPA management key"), text: $draft.managementKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Button {
                        revealsKey.toggle()
                    } label: {
                        Image(systemName: revealsKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(L10n.t("CLIProxyAPI 连接", "CLIProxyAPI Connection"))
        } footer: {
            Text(L10n.t("直连模式由 AccessDeck 探测额度；插件模式读取 CPA 中已安装并启用的 clipbar-quota 插件。", "Direct mode probes quotas from AccessDeck; plugin mode reads the installed and enabled clipbar-quota plugin in CPA."))
        }
    }

    private var currentConnectionMethodRow: some View {
        HStack(spacing: 8) {
            Image(systemName: model.settings.isConfigured ? model.settings.connectionMode.systemImage : "questionmark.circle")
                .foregroundStyle(model.settings.isConfigured ? AccessDeckTheme.accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("当前连接方式", "Current Connection Method"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(connectionMethodTitle)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
    }

    private var connectionMethodTitle: String {
        guard model.settings.isConfigured else {
            return L10n.t("尚未配置", "Not configured")
        }
        return model.settings.connectionMode.displayName
    }

    // MARK: - Diagnosis Section

    private var diagnosisSection: some View {
        Section {
            currentConnectionMethodRow

            Button {
                testConnection()
            } label: {
                HStack {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.t("正在测试连接...", "Testing connection..."))
                            .padding(.leading, 6)
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .foregroundStyle(AccessDeckTheme.accent)
                        Text(L10n.t("测试连接与鉴权", "Test Connection & Auth"))
                            .foregroundStyle(AccessDeckTheme.accent)
                            .fontWeight(.medium)
                    }
                }
            }
            .disabled(isTesting || !draft.isConfigured)

            if let result = testResult {
                switch result {
                case .success(let count, let latency):
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AccessDeckTheme.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("连接成功", "Connection Successful"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AccessDeckTheme.success)
                            Text(L10n.t("检测到 \(count) 个账号，耗时 \(latency) ms", "Found \(count) accounts (\(latency) ms)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                case .error(let message):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AccessDeckTheme.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("连接失败", "Connection Failed"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AccessDeckTheme.danger)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text(L10n.t("诊断与测试", "Diagnostics & Testing"))
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        Section {
            Picker(L10n.t("外观主题", "Theme"), selection: $draft.appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }

            Picker(L10n.t("自动刷新间隔", "Refresh Interval"), selection: $draft.refreshSeconds) {
                ForEach(AppSettings.refreshIntervalPresets, id: \.self) { preset in
                    let minutes = preset / 60
                    Text(L10n.t("\(minutes) 分钟", "\(minutes) Minutes")).tag(preset)
                }
            }
            Picker(L10n.t("优先额度窗口", "Preferred Window"), selection: $draft.statusQuotaWindow) {
                Text(L10n.t("5 小时 / 速率限制", "5 Hours / Rate Limit")).tag(StatusQuotaWindow.fiveHour)
                Text(L10n.t("周额度", "Weekly")).tag(StatusQuotaWindow.weekly)
            }
            Toggle(L10n.t("按剩余额度优先排序", "Sort by Remaining Quota"), isOn: $draft.sortByRemainingQuota)

        } header: {
            Text(L10n.t("偏好", "Preferences"))
        }
    }

    // MARK: - Provider Colors Section

    private var providerColorsSection: some View {
        Section {
            ForEach(model.orderedPreferenceProviders, id: \.self) { provider in
                HStack(spacing: 8) {
                    ProviderGlyph(provider: provider, size: 14)
                    Text(provider.displayName)
                        .font(.body)

                    Spacer()

                    ColorPicker("", selection: Binding(
                        get: {
                            if let hex = draft.customColorHex(for: provider), let col = Color(hex: hex) {
                                return col
                            }
                            return AccessDeckTheme.brandColor(for: provider)
                        },
                        set: { newColor in
                            draft.providerCustomColors[provider.rawValue] = newColor.hexString
                        }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
            }
        } header: {
            Text(L10n.t("渠道进度条颜色", "Provider Bar Colors"))
        } footer: {
            Text(L10n.t("为各个渠道自定义额度条颜色，不设置则使用默认颜色。", "Customize the bar color for each provider."))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text(L10n.t("软件版本", "Version"))
                Spacer()
                Text("v0.1.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(L10n.t("出品工作室", "Studio"))
                Spacer()
                Text("烂人文工作室 (Lanrenwen)")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://accessdeck.lanrenwen.com")!) {
                HStack {
                    Text(L10n.t("AccessDeck 官方主页", "AccessDeck Website"))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(L10n.t("关于", "About"))
        }
    }

    // MARK: - Actions

    private func save() {
        model.saveSettings(draft)
    }

    private func testConnection() {
        let testSettings = draft
        isTesting = true
        testResult = nil

        Task {
            let start = DispatchTime.now()
            do {
                let result = try await QuotaConnectionFactory().make(settings: testSettings).refresh(force: true)
                let rows = result.accounts
                if let error = result.error {
                    throw QuotaConnectionError.plugin(error)
                }
                let end = DispatchTime.now()
                let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
                let latencyMs = Int(nanoTime / 1_000_000)
                await MainActor.run {
                    testResult = .success(accountsCount: rows.count, latencyMs: latencyMs)
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .error(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }
}

private struct PresetPill: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.primary.opacity(0.85))
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }
}
#endif
