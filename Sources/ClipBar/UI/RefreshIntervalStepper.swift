import SwiftUI

struct RefreshIntervalStepper: View {
    @Binding var seconds: Int

    private let step = 10
    private let range = 15...600

    var body: some View {
        HStack(spacing: ClipBarTheme.spacingS) {
            Text(L10n.t("刷新间隔", "Refresh interval"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: decrement) {
                Image(systemName: "minus")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(seconds <= range.lowerBound)
            .accessibilityLabel(L10n.t("减少 10 秒", "Decrease 10 seconds"))

            Text(label)
                .font(.body.monospacedDigit().weight(.medium))
                .frame(minWidth: 72)
                .multilineTextAlignment(.center)

            Button(action: increment) {
                Image(systemName: "plus")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(seconds >= range.upperBound)
            .accessibilityLabel(L10n.t("增加 10 秒", "Increase 10 seconds"))
        }
    }

    private var label: String {
        if seconds >= 60, seconds.isMultiple(of: 60) {
            let minutes = seconds / 60
            return L10n.t("\(minutes) 分钟", "\(minutes) min")
        }
        return L10n.t("\(seconds) 秒", "\(seconds) sec")
    }

    private func increment() {
        seconds = min(range.upperBound, seconds + step)
    }

    private func decrement() {
        seconds = max(range.lowerBound, seconds - step)
    }
}
