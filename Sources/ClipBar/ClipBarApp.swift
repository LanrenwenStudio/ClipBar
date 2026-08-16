#if os(macOS)
import AppKit
import SwiftUI

@main
struct ClipBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItems: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItems = StatusItemController(model: model)
        if CommandLine.arguments.contains("--open-settings") {
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.statusItems?.presentSettings()
            }
        }
    }
}
#endif
