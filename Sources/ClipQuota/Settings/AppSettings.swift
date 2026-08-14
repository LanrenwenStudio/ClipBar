import Foundation

struct AppSettings: Equatable, Sendable {
    var baseURL: String
    var managementKey: String
    var refreshSeconds: Int
    var statusItemOrder: [String]
    var hiddenStatusItemIDs: [String]
    var hideEmptyStatusItems: Bool

    static let `default` = AppSettings(
        baseURL: "http://127.0.0.1:8317",
        managementKey: "",
        refreshSeconds: 60,
        statusItemOrder: [],
        hiddenStatusItemIDs: [],
        hideEmptyStatusItems: false
    )

    var isConfigured: Bool {
        !normalizedBaseURL.isEmpty && !normalizedManagementKey.isEmpty
    }

    var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedManagementKey: String {
        managementKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var clampedRefreshSeconds: Int {
        min(max(refreshSeconds, 15), 600)
    }

    var hiddenStatusItemIDSet: Set<String> {
        Set(hiddenStatusItemIDs)
    }
}
