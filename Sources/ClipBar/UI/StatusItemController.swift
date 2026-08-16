import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let popover = NSPopover()
    private let statusItem: NSStatusItem
    private let host: PassthroughHostingView<AnyView>
    private var wasSettingsPresented = false
    private var lastPopoverDismissalRequest = 0

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "clipbar.combined"
        host = PassthroughHostingView(rootView: AnyView(MenuBarStatusLabel().environment(model)))
        super.init()
        configurePopover()
        configureStatusItem()
        observe()
        refreshLabel()
    }

    private func configurePopover() {
        let hostingController = NSHostingController(
            rootView: PopoverRootView().environment(model)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        host.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
            host.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
            host.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    private func observe() {
        withObservationTracking {
            _ = model.accounts
            _ = model.statusSegments
            _ = model.settings.statusItemOrder
            _ = model.settings.hiddenStatusItemIDs
            _ = model.settings.hideEmptyStatusItems
            _ = model.settings.statusQuotaWindow
            _ = model.connection
            _ = model.statusTitle
            _ = model.isSettingsPresented
            _ = model.popoverDismissalRequest
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                let enteredSettings = self?.model.isSettingsPresented == true && self?.wasSettingsPresented == false
                let shouldDismissPopover = self?.model.popoverDismissalRequest != self?.lastPopoverDismissalRequest
                self?.wasSettingsPresented = self?.model.isSettingsPresented == true
                self?.lastPopoverDismissalRequest = self?.model.popoverDismissalRequest ?? 0
                self?.refreshLabel()
                self?.observe()
                self?.presentSettingsIfNeeded()
                if enteredSettings {
                    self?.restorePopoverFocus()
                }
                if shouldDismissPopover {
                    if self?.popover.isShown == true {
                        self?.popover.performClose(nil)
                    } else {
                        self?.model.closeSettings()
                    }
                }
            }
        }
    }

    private func refreshLabel() {
        host.rootView = AnyView(MenuBarStatusLabel().environment(model))
        host.invalidateIntrinsicContentSize()
        statusItem.length = max(ceil(host.fittingSize.width) + 10, 28)
        statusItem.button?.toolTip = model.statusAccessibilityLabel
        statusItem.button?.setAccessibilityLabel(model.statusAccessibilityLabel)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            if popover.isShown {
                if !model.isSettingsPresented {
                    model.openSettings()
                } else {
                    popover.performClose(nil)
                }
                return
            }
            presentSettings(relativeTo: sender)
            return
        }
        togglePopover(relativeTo: sender)
    }

    func presentSettings() {
        guard let button = statusItem.button else { return }
        presentSettings(relativeTo: button)
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        model.closeSettings()
        showPopover(relativeTo: button)
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        restorePopoverFocus()
    }

    private func presentSettings(relativeTo button: NSStatusBarButton) {
        model.openSettings()
        if popover.isShown {
            restorePopoverFocus()
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func presentSettingsIfNeeded() {
        guard model.isSettingsPresented,
              !popover.isShown,
              let button = statusItem.button else { return }
        showPopover(relativeTo: button)
    }

    private func restorePopoverFocus() {
        guard let window = popover.contentViewController?.view.window,
              let contentView = popover.contentViewController?.view else { return }
        window.makeKey()
        window.makeFirstResponder(contentView)
    }

    func popoverDidClose(_ notification: Notification) {
        model.closeSettings()
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
