import SwiftUI

struct RefreshIntervalPicker: View {
    @Binding var seconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.t("刷新频率", "Refresh interval"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentLabel)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Picker(L10n.t("刷新频率", "Refresh interval"), selection: selection) {
                ForEach(AppSettings.refreshIntervalPresets, id: \.self) { preset in
                    Text(shortLabel(for: preset))
                        .tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
        }
    }

    private var selection: Binding<Int> {
        Binding(
            get: { AppSettings.nearestRefreshInterval(to: seconds) },
            set: { seconds = $0 }
        )
    }

    private var currentLabel: String {
        let nearest = AppSettings.nearestRefreshInterval(to: seconds)
        let mins = nearest / 60
        return L10n.t("每 \(mins) 分钟", "Every \(mins)m")
    }

    private func shortLabel(for seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes)m"
    }
}
