import ServiceManagement

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
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
