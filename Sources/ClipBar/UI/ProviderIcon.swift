#if os(macOS)
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
            ?? Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Icons")
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
#elseif os(iOS)
import UIKit

enum ProviderIcon {
    static func image(for provider: QuotaProvider, size: CGFloat = 16) -> UIImage? {
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

        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Icons")
            ?? Bundle.main.url(forResource: name, withExtension: "svg")
            ?? Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Icons")

        guard let url, let img = UIImage(contentsOfFile: url.path) ?? (try? Data(contentsOf: url)).flatMap(UIImage.init(data:)) else {
            return nil
        }
        return img.withRenderingMode(.alwaysTemplate)
    }
    static func systemFallbackName(for provider: QuotaProvider) -> String {
        switch provider {
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .claude: "sparkles"
        case .geminiCLI: "sparkle"
        case .antigravity: "atom"
        case .xai: "bolt.fill"
        case .kimi: "moon.stars.fill"
        case .unknown: "server.rack"
        }
    }
}
#endif
