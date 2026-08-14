import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = AppSettings.default
    @State private var revealsKey = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case url
        case key
        case refresh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("连接 CLIProxyAPI", "Connect CLIProxyAPI"))
                .font(.title3.weight(.semibold))

            connectionFields
            accountList

            HStack {
                Button(L10n.t("取消", "Cancel")) {
                    model.closeSettings()
                }
                Spacer()
                Button(L10n.t("保存并刷新", "Save & Refresh")) {
                    model.saveSettings(draft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isConfigured)
            }
        }
        .padding(20)
        .frame(width: 480, height: 620)
        .onAppear {
            draft = model.settings
            focusedField = draft.managementKey.isEmpty ? .key : .url
        }
    }

    private var connectionFields: some View {
        Group {
            Text(L10n.t(
                "默认读本机 8317 端口的 Management API。密钥对应 config 里的 remote-management.secret-key。",
                "Reads the local management API on port 8317. The key is remote-management.secret-key from your config."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            labeledField(L10n.t("管理地址", "Management URL")) {
                TextField("http://127.0.0.1:8317", text: $draft.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .url)
            }

            labeledField(L10n.t("管理密钥", "Management key")) {
                HStack(spacing: 8) {
                    Group {
                        if revealsKey {
                            TextField(L10n.t("粘贴 secret-key", "Paste secret-key"), text: $draft.managementKey)
                        } else {
                            SecureField(L10n.t("粘贴 secret-key", "Paste secret-key"), text: $draft.managementKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .key)

                    Button {
                        revealsKey.toggle()
                        focusedField = .key
                    } label: {
                        Image(systemName: revealsKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.t("显示或隐藏密钥", "Show or hide the key"))
                }
            }

            labeledField(L10n.t("刷新间隔（秒）", "Refresh interval (seconds)")) {
                TextField("60", value: $draft.refreshSeconds, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .refresh)
            }
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("状态栏渠道", "Menu bar providers"))
                .font(.caption.weight(.semibold))
            Text(L10n.t(
                "同一渠道的多个账号会汇总成一格，百分比按总量计算。勾选要显示的渠道，拖动排序。",
                "Accounts in the same provider are pooled into one cell. Check providers to show, then drag to reorder."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            Toggle(
                L10n.t("总额度为 0 时从状态栏隐藏", "Hide from menu bar when remaining is 0"),
                isOn: Binding(
                    get: { model.settings.hideEmptyStatusItems },
                    set: { model.setHideEmptyStatusItems($0) }
                )
            )
            .font(.caption)
            if model.orderedPreferenceProviders.isEmpty {
                Text(L10n.t("还没有账号。先保存连接并刷新。", "No accounts yet. Save the connection and refresh first."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(model.orderedPreferenceProviders, id: \.self) { provider in
                        providerRow(provider)
                    }
                    .onMove(perform: model.moveStatusItems)
                }
                .listStyle(.inset)
                .frame(minHeight: 140, maxHeight: 240)
            }
        }
    }

    private func providerRow(_ provider: QuotaProvider) -> some View {
        let rows = model.accounts.filter { $0.account.provider == provider }
        let remaining = StatusBarSummary.pooledRemaining(in: rows)
        return HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Toggle("", isOn: Binding(
                get: { model.isStatusItemVisible(provider) },
                set: { model.setStatusItemVisible(provider, visible: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            if let image = ProviderIcon.image(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 14, height: 14)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(provider.displayName)
                Text(L10n.t("\(rows.count) 个账号", "\(rows.count) accounts"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(remaining.map { "\(Int($0.rounded()))%" } ?? "--")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            content()
        }
    }
}
