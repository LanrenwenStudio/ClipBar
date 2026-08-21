#if os(macOS)
import AppKit
import SwiftUI

struct PopoverFooterBar: View {
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: openSettings) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text(L10n.t("设置", "Settings"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: quit) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                    Text(L10n.t("退出", "Quit"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
#endif
