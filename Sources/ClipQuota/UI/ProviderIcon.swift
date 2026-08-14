import AppKit

enum ProviderIcon {
    static func image(for provider: QuotaProvider, size: CGFloat = 13) -> NSImage? {
        let name: String
        switch provider {
        case .codex: name = "ProviderIcon-codex"
        case .claude: name = "ProviderIcon-claude"
        case .geminiCLI: name = "ProviderIcon-gemini"
        case .antigravity: name = "ProviderIcon-antigravity"
        case .xai: name = "ProviderIcon-grok"
        case .kimi: name = "ProviderIcon-kimi"
        case .unknown: return nil
        }

        let url = Bundle.main.url(forResource: name, withExtension: "svg")
            ?? Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Icons")
        guard let url, let source = NSImage(contentsOf: url) else {
            return nil
        }

        let canvas = NSSize(width: size, height: size)
        let rendered = NSImage(size: canvas, flipped: false) { rect in
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        rendered.isTemplate = true
        return rendered
    }
}
