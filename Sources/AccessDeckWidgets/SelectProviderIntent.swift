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
enum WidgetProgressBarStyle: String, AppEnum, Sendable {
    case segmented = "segmented"
    case continuous = "continuous"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "进度条样式"

    static let caseDisplayRepresentations: [WidgetProgressBarStyle: DisplayRepresentation] = [
        .segmented: DisplayRepresentation(title: "分段微胶囊", subtitle: "高密度竖条阵列风格"),
        .continuous: DisplayRepresentation(title: "连续平滑", subtitle: "微圆角实心长条风格")
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
    static let description = IntentDescription("设置多渠道监控的显示选项。")
    @Parameter(title: "进度条样式", default: .segmented)
    var style: WidgetProgressBarStyle

    @Parameter(title: "显示重置卡数量", default: true)
    var showResetCredits: Bool

    init() {
        self.style = .segmented
        self.showResetCredits = true
    }

    init(style: WidgetProgressBarStyle = .segmented, showResetCredits: Bool = true) {
        self.style = style
        self.showResetCredits = showResetCredits
    }
}
