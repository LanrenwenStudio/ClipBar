import Foundation

enum QuotaProvider: String, CaseIterable, Identifiable, Sendable {
    var id: String { rawValue }
    case codex
    case claude
    case geminiCLI = "gemini-cli"
    case antigravity
    case kimi
    case xai
    case unknown

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .geminiCLI: "Gemini CLI"
        case .antigravity: "Antigravity"
        case .kimi: "Kimi"
        case .xai: "Grok"
        case .unknown: "Other"
        }
    }

    var statusName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .geminiCLI: "Gem"
        case .antigravity: "AG"
        case .kimi: "Kimi"
        case .xai: "Grok"
        case .unknown: "?"
        }
    }

    var supportsLiveQuota: Bool {
        switch self {
        case .codex, .claude, .geminiCLI, .antigravity, .kimi, .xai:
            true
        case .unknown:
            false
        }
    }

    static func parse(_ raw: String?) -> QuotaProvider {
        switch (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "codex", "openai", "chatgpt":
            .codex
        case "claude", "anthropic":
            .claude
        case "gemini", "gemini-cli", "aistudio":
            .geminiCLI
        case "antigravity":
            .antigravity
        case "kimi", "kimi-ai", "moonshot":
            .kimi
        case "xai", "x-ai", "grok":
            .xai
        default:
            .unknown
        }
    }
}

struct QuotaWindow: Identifiable, Hashable, Sendable {
    var id: String
    var label: String
    var remainingPercent: Double?
    var resetText: String?

    var usedPercent: Double? {
        remainingPercent.map { 100 - $0 }
    }

    var isExhausted: Bool {
        (remainingPercent ?? 100) <= 0.5
    }

    var isLow: Bool {
        (remainingPercent ?? 100) <= 20
    }
}

struct QuotaSnapshot: Hashable, Sendable {
    var planType: String?
    var windows: [QuotaWindow]
    var error: String?

    var primaryRemaining: Double? {
        windows.first?.remainingPercent
    }

    var lowestRemaining: Double? {
        windows.compactMap(\.remainingPercent).min()
    }

    var hasLiveData: Bool {
        error == nil && windows.contains { $0.remainingPercent != nil }
    }
}

struct AuthAccount: Identifiable, Hashable, Sendable {
    var id: String
    var authIndex: String
    var name: String
    var email: String?
    var provider: QuotaProvider
    var providerRaw: String
    var status: String
    var statusMessage: String?
    var disabled: Bool
    var unavailable: Bool
    var accountID: String?
    var projectID: String?
    var fileName: String?

    var displayName: String {
        if let email, !email.isEmpty { return email }
        if !name.isEmpty { return name }
        return authIndex
    }

    var statusKey: String {
        if let fileName, !fileName.isEmpty { return fileName }
        if !authIndex.isEmpty { return authIndex }
        return id
    }

    var isRoutable: Bool {
        !disabled && !unavailable && status.lowercased() != "error"
    }
}

struct AccountQuota: Identifiable, Hashable, Sendable {
    var account: AuthAccount
    var snapshot: QuotaSnapshot

    var id: String { account.id }

    var sortKey: (String, Double, String) {
        (
            account.provider.displayName,
            snapshot.lowestRemaining ?? 999,
            account.displayName.lowercased()
        )
    }
}

enum ConnectionState: Equatable, Sendable {
    case unconfigured
    case idle
    case refreshing
    case online
    case failed(String)

    var isRefreshing: Bool {
        self == .refreshing
    }
}

enum L10n {
    static var isChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }

    static func t(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }
}
