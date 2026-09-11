#if os(iOS)
import SwiftUI

@main
struct AccessDeckIOSApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(model)
                .tint(AccessDeckTheme.accent)
                .preferredColorScheme(model.settings.appTheme.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // iOS may suspend the app while it is in the background, so the
                // polling task cannot keep the cached dashboard current there.
                Task { await model.refresh(force: true) }
            case .background:
                BackgroundRefreshScheduler.schedule()
            default:
                break
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}
#endif
