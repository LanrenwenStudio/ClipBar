import AppIntents
import WidgetKit

@available(iOS 17.0, macOS 14.0, *)
enum WidgetChannelCount: Int, AppEnum, Sendable {
    case one = 1
    case two = 2
    case three = 3
    case four = 4

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "展示数量"

    static let caseDisplayRepresentations: [WidgetChannelCount: DisplayRepresentation] = [
        .one: DisplayRepresentation(title: "1 个渠道", subtitle: "大单卡聚焦"),
        .two: DisplayRepresentation(title: "2 个渠道", subtitle: "双指标对比"),
        .three: DisplayRepresentation(title: "3 个渠道", subtitle: "经典三渠道"),
        .four: DisplayRepresentation(title: "4 个渠道", subtitle: "四渠道高密度监控")
    ]
}

@available(iOS 17.0, macOS 14.0, *)
enum WidgetProviderChoice: String, AppEnum, Sendable {
    case auto = "auto"
    case none = "none"
    case codex = "codex"
    case antigravity = "antigravity"
    case claude = "claude"
    case gemini = "geminiCLI"
    case grok = "xai"
    case kimi = "kimi"
    case workbuddy = "workbuddy"
    case qoder = "qoder"
    case trae = "trae"
    case minimax = "minimax"
    case copilot = "copilot"
    case deepseek = "deepseek"
    case zcode = "zcode"
    case stepfun = "stepfun"
    case qwen = "qwen"
    case doubao = "doubao"
    case zhipu = "zhipu"
    case hunyuan = "hunyuan"
    case openrouter = "openrouter"
    case ollama = "ollama"
    case zen = "zen"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "渠道"

    static let caseDisplayRepresentations: [WidgetProviderChoice: DisplayRepresentation] = [
        .auto: DisplayRepresentation(title: "自动推荐", subtitle: "按使用情况推荐"),
        .none: DisplayRepresentation(title: "无 / 留空", subtitle: "不展示此槽位"),
        .codex: DisplayRepresentation(title: "Codex", subtitle: "OpenAI Codex 额度"),
        .antigravity: DisplayRepresentation(title: "Agy", subtitle: "Antigravity 额度"),
        .claude: DisplayRepresentation(title: "Claude", subtitle: "Anthropic Claude 额度"),
        .gemini: DisplayRepresentation(title: "Gemini", subtitle: "Google Gemini 额度"),
        .grok: DisplayRepresentation(title: "Grok", subtitle: "xAI Grok 额度"),
        .kimi: DisplayRepresentation(title: "Kimi", subtitle: "Moonshot Kimi 额度"),
        .workbuddy: DisplayRepresentation(title: "WorkBuddy", subtitle: "WorkBuddy 额度"),
        .qoder: DisplayRepresentation(title: "Qoder", subtitle: "Qoder 额度"),
        .trae: DisplayRepresentation(title: "Trae", subtitle: "ByteDance Trae 额度"),
        .minimax: DisplayRepresentation(title: "MiniMax", subtitle: "MiniMax 额度"),
        .copilot: DisplayRepresentation(title: "Copilot", subtitle: "GitHub Copilot 额度"),
        .deepseek: DisplayRepresentation(title: "DeepSeek", subtitle: "DeepSeek 额度"),
        .zcode: DisplayRepresentation(title: "ZCode", subtitle: "ZCode 额度"),
        .stepfun: DisplayRepresentation(title: "StepFun", subtitle: "阶跃星辰 额度"),
        .qwen: DisplayRepresentation(title: "Qwen", subtitle: "通义千问 额度"),
        .doubao: DisplayRepresentation(title: "Doubao", subtitle: "豆包 额度"),
        .zhipu: DisplayRepresentation(title: "GLM", subtitle: "智谱清言 额度"),
        .hunyuan: DisplayRepresentation(title: "Hunyuan", subtitle: "腾讯混元 额度"),
        .openrouter: DisplayRepresentation(title: "OpenRouter", subtitle: "OpenRouter 额度"),
        .ollama: DisplayRepresentation(title: "Ollama", subtitle: "Ollama 额度"),
        .zen: DisplayRepresentation(title: "Zen", subtitle: "OpenCode Zen 额度")
    ]

    var quotaProvider: QuotaProvider? {
        switch self {
        case .auto, .none: return nil
        case .codex: return .codex
        case .antigravity: return .antigravity
        case .claude: return .claude
        case .gemini: return .geminiCLI
        case .grok: return .xai
        case .kimi: return .kimi
        case .workbuddy: return .workbuddy
        case .qoder: return .qoder
        case .trae: return .trae
        case .minimax: return .minimax
        case .copilot: return .copilot
        case .deepseek: return .deepseek
        case .zcode: return .zcode
        case .stepfun: return .stepfun
        case .qwen: return .qwen
        case .doubao: return .doubao
        case .zhipu: return .zhipu
        case .hunyuan: return .hunyuan
        case .openrouter: return .openrouter
        case .ollama: return .ollama
        case .zen: return .zen
        }
    }

    func matches(provider: ProviderWidgetData) -> Bool {
        if self == .auto { return true }
        if self == .none { return false }
        return quotaProvider == provider.provider
    }
}

@available(iOS 17.0, macOS 14.0, *)
enum WidgetProgressBarStyle: String, AppEnum, Sendable {
    case segmented = "segmented"
    case continuous = "continuous"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "进度条样式"

    static let caseDisplayRepresentations: [WidgetProgressBarStyle: DisplayRepresentation] = [
        .segmented: DisplayRepresentation(title: "分段直角矩形", subtitle: "纤细高瘦矩形竖条风格"),
        .continuous: DisplayRepresentation(title: "连续平滑", subtitle: "极简直角矩形长条风格")
    ]
}

@available(iOS 17.0, macOS 14.0, *)
struct SelectProviderIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "单渠道小组件配置"
    static let description = IntentDescription("选择要展示的 AI 渠道及展示选项。")

    @Parameter(title: "渠道", default: .auto)
    var provider: WidgetProviderChoice

    @Parameter(title: "进度条样式", default: .segmented)
    var style: WidgetProgressBarStyle

    @Parameter(title: "显示重置卡数量", default: true)
    var showResetCredits: Bool

    init() {
        self.provider = .auto
        self.style = .segmented
        self.showResetCredits = true
    }

    init(provider: WidgetProviderChoice, style: WidgetProgressBarStyle = .segmented, showResetCredits: Bool = true) {
        self.provider = provider
        self.style = style
        self.showResetCredits = showResetCredits
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct MultiProviderIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "多渠道小组件配置"
    static let description = IntentDescription("设置多渠道监控的展示数量（1~4个）及展示的渠道。")

    @Parameter(title: "展示数量", default: .four)
    var count: WidgetChannelCount

    @Parameter(title: "第 1 渠道", default: .auto)
    var channel1: WidgetProviderChoice

    @Parameter(title: "第 2 渠道", default: .auto)
    var channel2: WidgetProviderChoice

    @Parameter(title: "第 3 渠道", default: .auto)
    var channel3: WidgetProviderChoice

    @Parameter(title: "第 4 渠道", default: .auto)
    var channel4: WidgetProviderChoice

    @Parameter(title: "进度条样式", default: .segmented)
    var style: WidgetProgressBarStyle

    @Parameter(title: "显示重置卡数量", default: true)
    var showResetCredits: Bool

    init() {
        self.count = .four
        self.channel1 = .auto
        self.channel2 = .auto
        self.channel3 = .auto
        self.channel4 = .auto
        self.style = .segmented
        self.showResetCredits = true
    }

    init(
        count: WidgetChannelCount = .four,
        channel1: WidgetProviderChoice = .auto,
        channel2: WidgetProviderChoice = .auto,
        channel3: WidgetProviderChoice = .auto,
        channel4: WidgetProviderChoice = .auto,
        style: WidgetProgressBarStyle = .segmented,
        showResetCredits: Bool = true
    ) {
        self.count = count
        self.channel1 = channel1
        self.channel2 = channel2
        self.channel3 = channel3
        self.channel4 = channel4
        self.style = style
        self.showResetCredits = showResetCredits
    }
}

/// 解析多渠道小组件中应展示的渠道列表（支持 1~4 个槽位与自选或自动填充）
@available(iOS 17.0, macOS 14.0, *)
func resolveDisplayProviders(
    allProviders: [ProviderWidgetData],
    choices: [WidgetProviderChoice],
    targetCount: Int
) -> [ProviderWidgetData] {
    let clampedCount = max(1, min(4, targetCount))
    let effectiveChoices: [WidgetProviderChoice] = {
        var list: [WidgetProviderChoice] = []
        for i in 0..<clampedCount {
            if i < choices.count {
                list.append(choices[i])
            } else {
                list.append(.auto)
            }
        }
        return list
    }()

    var resolved: [ProviderWidgetData] = []
    var usedProviders = Set<QuotaProvider>()
    var slotAssignments: [ProviderWidgetData?] = Array(repeating: nil, count: clampedCount)

    // 第一轮：按用户明确指定的渠道匹配数据
    for (index, choice) in effectiveChoices.enumerated() {
        if let target = choice.quotaProvider {
            if let found = allProviders.first(where: { $0.provider == target && !usedProviders.contains($0.provider) }) {
                slotAssignments[index] = found
                usedProviders.insert(target)
            } else if let found = allProviders.first(where: { $0.provider == target }) {
                slotAssignments[index] = found
            } else {
                // 如果当前数据中暂无该渠道，生成占位数据尊重用户偏好
                let placeholder = ProviderWidgetData(
                    providerRawValue: target.rawValue,
                    displayName: target == .antigravity ? "Agy" : target.displayName,
                    remainingPercent: nil,
                    accountCount: 0,
                    healthyCount: 0,
                    statusText: "--",
                    windows: []
                )
                slotAssignments[index] = placeholder
                usedProviders.insert(target)
            }
        }
    }

    // 第二轮：将 .auto 槽位从剩余可用活跃渠道中按顺序填充
    var availablePool = allProviders.filter { !usedProviders.contains($0.provider) }

    for index in 0..<clampedCount {
        if slotAssignments[index] == nil {
            let choice = effectiveChoices[index]
            if choice == .none {
                // 用户显式选择留空
                continue
            }
            if !availablePool.isEmpty {
                let candidate = availablePool.removeFirst()
                slotAssignments[index] = candidate
                usedProviders.insert(candidate.provider)
            }
        }
    }

    // 收集所有有效槽位
    for item in slotAssignments {
        if let item {
            resolved.append(item)
        }
    }

    if resolved.isEmpty {
        return Array(allProviders.prefix(clampedCount))
    }

    return resolved
}
