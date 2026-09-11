import Foundation

enum StatusQuotaWindow: String, CaseIterable, Sendable, Codable {
    case fiveHour = "5h"
    case weekly = "7d"
}
