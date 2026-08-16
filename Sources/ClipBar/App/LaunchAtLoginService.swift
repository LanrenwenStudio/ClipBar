#if os(macOS)
import ServiceManagement
#endif

enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case requiresApproval
    case notRegistered
    case notFound

    var isRegistered: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .notFound:
            false
        }
    }
}

@MainActor
final class LaunchAtLoginService {
    var status: LaunchAtLoginStatus {
#if os(macOS)
        switch SMAppService.mainApp.status {
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notRegistered:
            .notRegistered
        case .notFound:
            .notFound
        @unknown default:
            .notRegistered
        }
#else
        .notRegistered
#endif
    }

    func setEnabled(_ enabled: Bool) throws {
#if os(macOS)
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
#endif
    }
}
