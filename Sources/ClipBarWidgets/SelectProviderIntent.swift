import AppIntents
import WidgetKit

@available(iOS 17.0, macOS 14.0, *)
enum WidgetProviderChoice: String, AppEnum, Sendable {
    case auto = "auto"
    case claude = "claude"
    case codex = "codex"
    case gemini = "geminiCLI"
    case antigravity = "antigravity"
    case grok = "xai"
    case kimi = "kimi"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "渠道"

    static let caseDisplayRepresentations: [WidgetProviderChoice: DisplayRepresentation] = [
        .auto: DisplayRepresentation(title: "自动推荐", subtitle: "按使用情况推荐"),
        .claude: DisplayRepresentation(title: "Claude", subtitle: "Anthropic Claude 额度"),
        .codex: DisplayRepresentation(title: "Codex", subtitle: "OpenAI Codex 额度"),
        .gemini: DisplayRepresentation(title: "Gemini", subtitle: "Google Gemini 额度"),
        .antigravity: DisplayRepresentation(title: "Antigravity", subtitle: "Google Antigravity 额度"),
        .grok: DisplayRepresentation(title: "Grok", subtitle: "xAI Grok 额度"),
        .kimi: DisplayRepresentation(title: "Kimi", subtitle: "Moonshot Kimi 额度")
    ]
}

@available(iOS 17.0, macOS 14.0, *)
struct SelectProviderIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "选择监控渠道"
    static let description = IntentDescription("选择要展示的 AI 渠道。")

    @Parameter(title: "渠道", default: .auto)
    var provider: WidgetProviderChoice

    init() {
        self.provider = .auto
    }

    init(provider: WidgetProviderChoice) {
        self.provider = provider
    }
}
