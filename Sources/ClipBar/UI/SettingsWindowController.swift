#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(model: AppModel, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let hostingController = NSHostingController(
            rootView: SettingsView().environment(model)
        )
        // Keep the panel at an explicit size. On macOS 26, feeding the
        // hosting controller's preferred content size back into this panel
        // can trigger an AppKit update-constraints loop.
        hostingController.sizingOptions = []

        let window = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ClipBarTheme.settingsWidth,
                height: ClipBarTheme.settingsHeight
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.t("ClipBar 设置", "ClipBar Settings")
        window.isFloatingPanel = false
        window.becomesKeyOnlyIfNeeded = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.contentViewController = hostingController
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(window?.contentView)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        onClose()
    }
}
#endif
