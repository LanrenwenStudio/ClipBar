import SwiftUI

struct RefreshIntervalPicker: View {
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: ClipBarTheme.spacingS) {
            Text(L10n.t("刷新间隔", "Refresh interval"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Picker(L10n.t("刷新间隔", "Refresh interval"), selection: selection) {
                ForEach(AppSettings.refreshIntervalPresets, id: \.self) { preset in
                    Text(label(for: preset))
                        .tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(minWidth: 180)
        }
    }

    private var selection: Binding<Int> {
        Binding(
            get: { AppSettings.nearestRefreshInterval(to: seconds) },
            set: { seconds = $0 }
        )
    }

    private func label(for seconds: Int) -> String {
        let minutes = seconds / 60
        return L10n.t("\(minutes) 分钟", "\(minutes) min")
    }
}
