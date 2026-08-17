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
                    .tint(ClipBarTheme.accent)
                    .disabled(draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Text(L10n.t("管理接口地址 (Base URL)", "Management URL (Base URL)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("http://192.168.1.100:8317", text: $draft.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PresetPill(title: "Localhost (127.0.0.1:8317)") {
                            draft.baseURL = "http://127.0.0.1:8317"
                        }
                        PresetPill(title: "LAN Port 8317") {
                            if !draft.baseURL.contains(":8317") {
                                draft.baseURL = "http://192.168.1.:8317"
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("管理密钥 (Secret Key)", "Management Secret Key"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    if revealsKey {
                        TextField(L10n.t("输入远程管理密钥", "Enter secret key"), text: $draft.managementKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(L10n.t("输入远程管理密钥", "Enter secret key"), text: $draft.managementKey)
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
            Text(L10n.t("对应 CLIProxyAPI 配置文件中的 remote-management.secret-key。数据仅保存在本机，不会上传到任何外部服务器。", "Matches remote-management.secret-key in CLIProxyAPI config. Stored locally on this device only."))
        }
    }

    // MARK: - Diagnosis Section

    private var diagnosisSection: some View {
        Section {
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
                            .foregroundStyle(ClipBarTheme.accent)
                        Text(L10n.t("测试连接与鉴权", "Test Connection & Auth"))
                            .foregroundStyle(ClipBarTheme.accent)
                            .fontWeight(.medium)
                    }
                }
            }
            .disabled(isTesting || draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let result = testResult {
                switch result {
                case .success(let count, let latency):
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ClipBarTheme.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("连接成功", "Connection Successful"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ClipBarTheme.success)
                            Text(L10n.t("检测到 \(count) 个账号，耗时 \(latency) ms", "Found \(count) accounts (\(latency) ms)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                case .error(let message):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ClipBarTheme.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("连接失败", "Connection Failed"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ClipBarTheme.danger)
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
                Text(L10n.t("周额度 / 7 天", "Weekly / 7 Days")).tag(StatusQuotaWindow.weekly)
            }
            Toggle(L10n.t("按剩余额度优先排序", "Sort by Remaining Quota"), isOn: $draft.sortByRemainingQuota)

            Toggle(L10n.t("启用低额度告警通知", "Enable Quota Notifications"), isOn: $draft.enableNotifications)

            if draft.enableNotifications {
                Picker(L10n.t("低额度提醒阈值", "Alert Threshold"), selection: $draft.lowQuotaAlertThreshold) {
                    Text("15%").tag(15)
                    Text("10%").tag(10)
                    Text("5%").tag(5)
                }
            }
        } header: {
            Text(L10n.t("偏好与通知", "Preferences & Notifications"))
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

            Link(destination: URL(string: "https://clipbar.lanrenwen.com")!) {
                HStack {
                    Text(L10n.t("ClipBar 官方主页", "ClipBar Website"))
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
                let rows = try await QuotaService(client: ManagementClient(settings: testSettings)).refresh()
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
