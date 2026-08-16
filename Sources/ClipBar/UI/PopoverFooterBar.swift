#if os(macOS)
import AppKit
import SwiftUI

struct PopoverFooterBar: View {
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: ClipBarTheme.spacingS) {
            Button(action: openSettings) {
                Label(L10n.t("设置", "Settings"), systemImage: "gearshape")
            }

            Spacer()

            Button(action: quit) {
                Label(L10n.t("退出", "Quit"), systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .font(.callout)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, ClipBarTheme.horizontalPadding)
        .padding(.vertical, 10)
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
#endif
