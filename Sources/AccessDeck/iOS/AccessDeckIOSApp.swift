#if os(iOS)
import SwiftUI

@main
struct AccessDeckIOSApp: App {
    @State private var model: AppModel

    init() {
        let store = SettingsStore()
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let url = environment["ACCESSDECK_SETUP_URL"],
           let key = environment["ACCESSDECK_SETUP_WEB_KEY"] {
            var settings = store.load()
            print("AccessDeck setup: saved URL matches:", settings.normalizedBaseURL == url)
            print("AccessDeck setup: saved key matches:", settings.normalizedManagementKey == key)
            settings.baseURL = url
            settings.managementKey = key
            store.save(settings)
            print("AccessDeck setup: key persisted:", store.load().normalizedManagementKey == key)
        }
        #endif
        _model = State(initialValue: AppModel(store: store))
    }

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
