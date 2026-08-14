import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let popover = NSPopover()
    private let statusItem: NSStatusItem
    private let host: PassthroughHostingView<AnyView>

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "clipquota.combined"
        host = PassthroughHostingView(rootView: AnyView(MenuBarStatusLabel().environment(model)))
        super.init()
        configurePopover()
        configureStatusItem()
        observe()
        refreshLabel()
    }

    private func configurePopover() {
        let hostingController = NSHostingController(
            rootView: QuotaPopoverView().environment(model)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
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
            _ = model.connection
            _ = model.statusTitle
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshLabel()
                self?.observe()
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
                popover.performClose(nil)
            }
            model.openSettings()
            return
        }
        togglePopover(relativeTo: sender)
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
