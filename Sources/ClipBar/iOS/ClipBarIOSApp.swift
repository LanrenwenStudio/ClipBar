#if os(iOS)
import SwiftUI

@main
struct ClipBarIOSApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(model)
                .tint(ClipBarTheme.accent)
                .preferredColorScheme(model.settings.appTheme.colorScheme)
        }
    }
}
#endif
