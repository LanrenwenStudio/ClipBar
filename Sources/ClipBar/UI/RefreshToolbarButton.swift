import SwiftUI

struct RefreshToolbarButton: View {
    let isRefreshing: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(isRefreshing ? 0 : 1)
                ProgressView()
                    .controlSize(.small)
                    .opacity(isRefreshing ? 1 : 0)
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(!isEnabled || isRefreshing)
        .accessibilityLabel(L10n.t("刷新额度", "Refresh quotas"))
    }
}
