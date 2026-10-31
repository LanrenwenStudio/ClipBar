import Foundation

enum QuotaProvider: String, CaseIterable, Identifiable, Sendable, Codable {
    var id: String { rawValue }
    case codex
    case claude
    case geminiCLI = "gemini-cli"
    case antigravity
    case kimi
    case xai
    case workbuddy
    case qoder
    case trae
    case minimax
    case copilot
    case deepseek
    case zcode
    case stepfun
    case qwen
    case doubao
    case zhipu
    case hunyuan
    case openrouter
    case ollama
    case zen
    case unknown

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .geminiCLI: "Gemini"
        case .antigravity: "Agy"
        case .kimi: "Kimi"
        case .xai: "Grok"
        case .workbuddy: "WorkBuddy"
        case .qoder: "Qoder"
        case .trae: "Trae"
        case .minimax: "MiniMax"
        case .copilot: "Copilot"
        case .deepseek: "DeepSeek"
        case .zcode: "ZCode"
        case .stepfun: "StepFun"
        case .qwen: "Qwen"
        case .doubao: "Doubao"
        case .zhipu: "GLM"
        case .hunyuan: "Hunyuan"
        case .openrouter: "OpenRouter"
        case .ollama: "Ollama"
        case .zen: "Zen"
        case .unknown: "Other"
        }
    }

    var statusName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .geminiCLI: "Gem"
        case .antigravity: "Agy"
        case .kimi: "Kimi"
        case .xai: "Grok"
        case .workbuddy: "WB"
        case .qoder: "Qoder"
        case .trae: "Trae"
        case .minimax: "MM"
        case .copilot: "Copilot"
        case .deepseek: "DS"
        case .zcode: "ZCode"
        case .stepfun: "Step"
        case .qwen: "Qwen"
        case .doubao: "Doubao"
        case .zhipu: "GLM"
        case .hunyuan: "HY"
        case .openrouter: "OR"
        case .ollama: "Ollama"
        case .zen: "Zen"
        case .unknown: "?"
        }
    }

    var supportsLiveQuota: Bool {
        self != .unknown
    }

    static func parse(_ raw: String?) -> QuotaProvider {
        let normalized = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "codex", "openai", "chatgpt":
            return .codex
        case "claude", "anthropic":
            return .claude
        case "gemini", "gemini-cli", "aistudio", "google":
            return .geminiCLI
        case "antigravity", "agy":
            return .antigravity
        case "kimi", "kimi-ai", "moonshot":
            return .kimi
        case "xai", "x-ai", "grok":
            return .xai
        case "workbuddy", "work-buddy", "wb", "workbuddy-ai", "workbuddyai":
            return .workbuddy
        case "qoder", "qoder-cn", "qfmodel", "dfmodel":
            return .qoder
        case "trae", "trae-cn":
            return .trae
        case "minimax", "minimax-code", "hailuo":
            return .minimax
        case "copilot", "github-copilot", "gh-copilot":
            return .copilot
        case "deepseek", "deepseek-chat", "deepseek-coder":
            return .deepseek
        case "zcode", "z-code":
            return .zcode
        case "stepfun", "step", "jieyue":
            return .stepfun
        case "qwen", "bailian", "aliyun", "qwenwork", "qwenwork-enterprise":
            return .qwen
        case "doubao", "volcengine", "volces", "bytedance":
            return .doubao
        case "zhipu", "glm", "codegeex":
            return .zhipu
        case "hunyuan", "tencent":
            return .hunyuan
        case "openrouter":
            return .openrouter
        case "ollama":
            return .ollama
        case "zen", "zen-free", "opencode-zen-free":
            return .zen
        default:
            return QuotaProvider(rawValue: normalized) ?? .unknown
        }
    }
}

enum QuotaDisplayScale {
    static let exhausted = 0.5
    static let step = 5.0
    static let warningCeiling = 30.0

    static func isExhausted(_ remaining: Double?) -> Bool {
        (remaining ?? 100) <= exhausted
    }

    static func isLow(_ remaining: Double?) -> Bool {
        (remaining ?? 100) <= warningCeiling
    }
}

struct QuotaWindow: Identifiable, Hashable, Sendable, Codable {
    var id: String
    var label: String
    var remainingPercent: Double?
    var resetText: String?

    var usedPercent: Double? {
        remainingPercent.map { 100 - $0 }
    }

    var isExhausted: Bool {
        QuotaDisplayScale.isExhausted(remainingPercent)
    }

    var isLow: Bool {
        QuotaDisplayScale.isLow(remainingPercent)
    }
}

struct QuotaSnapshot: Hashable, Sendable, Codable {
    var planType: String?
    var windows: [QuotaWindow]
    var error: String?
    var resetCreditCount: Int? = nil
    var resetCreditExpiresAt: Date? = nil

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

struct AuthAccount: Identifiable, Hashable, Sendable, Codable {
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

struct AccountQuota: Identifiable, Hashable, Sendable, Codable {
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
