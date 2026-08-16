import Foundation

struct AppSettings: Equatable, Sendable {
    static let refreshIntervalPresets = [60, 180, 300]

    var baseURL: String
    var managementKey: String
    var refreshSeconds: Int
    var statusItemOrder: [String]
    var hiddenStatusItemIDs: [String]
    var hideEmptyStatusItems: Bool
    var statusQuotaWindow: StatusQuotaWindow

    static let `default` = AppSettings(
        baseURL: "http://127.0.0.1:8317",
        managementKey: "",
        refreshSeconds: 60,
        statusItemOrder: [],
        hiddenStatusItemIDs: [],
        hideEmptyStatusItems: false,
        statusQuotaWindow: .fiveHour
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
        Self.nearestRefreshInterval(to: refreshSeconds)
    }

    static func nearestRefreshInterval(to seconds: Int) -> Int {
        switch seconds {
        case ..<120:
            refreshIntervalPresets[0]
        case ..<240:
            refreshIntervalPresets[1]
        default:
            refreshIntervalPresets[2]
        }
    }

    var hiddenStatusItemIDSet: Set<String> {
        Set(hiddenStatusItemIDs)
    }
}
