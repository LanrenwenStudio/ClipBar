#if os(macOS)
import AppKit

enum ProviderIcon {
    static func resourceName(for provider: QuotaProvider) -> String? {
        switch provider {
        case .codex: "ProviderIcon-codex"
        case .claude: "ProviderIcon-claude"
        case .geminiCLI: "ProviderIcon-gemini"
        case .antigravity: "ProviderIcon-antigravity"
        case .xai: "ProviderIcon-grok"
        case .kimi: "ProviderIcon-kimi"
        case .workbuddy: "ProviderIcon-workbuddy"
        case .qoder: "ProviderIcon-qoder"
        case .trae: "ProviderIcon-trae"
        case .minimax: "ProviderIcon-minimax"
        case .copilot: "ProviderIcon-copilot"
        case .deepseek: "ProviderIcon-deepseek"
        case .zcode: "ProviderIcon-zcode"
        case .stepfun: "ProviderIcon-stepfun"
        case .qwen: "ProviderIcon-qwen"
        case .doubao: "ProviderIcon-doubao"
        case .zhipu: "ProviderIcon-zhipu"
        case .hunyuan: "ProviderIcon-hunyuan"
        case .openrouter: "ProviderIcon-openrouter"
        case .ollama: "ProviderIcon-ollama"
        default: nil
        }
    }

    static func image(for provider: QuotaProvider, size: CGFloat = 13) -> NSImage? {
        guard let name = resourceName(for: provider) else { return nil }

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

    static func systemFallbackName(for provider: QuotaProvider) -> String {
        switch provider {
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .claude: "sparkles"
        case .geminiCLI: "sparkle"
        case .antigravity: "atom"
        case .xai: "bolt.fill"
        case .kimi: "moon.stars.fill"
        case .workbuddy: "briefcase.fill"
        case .qoder: "chevron.left.forwardslash.chevron.right"
        case .trae: "cursorarrow.rays"
        case .minimax: "waveform.path.ecg"
        case .copilot: "airplane.departure"
        case .deepseek: "magnifyingglass.circle.fill"
        case .zcode: "z.square.fill"
        case .stepfun: "star.fill"
        case .qwen: "cloud.sun.fill"
        case .doubao: "flame.fill"
        case .zhipu: "brain.head.profile"
        case .hunyuan: "water.waves"
        case .openrouter: "network"
        case .ollama: "laptopcomputer"
        case .zen: "leaf.fill"
        case .unknown: "server.rack"
        }
    }
}
#elseif os(iOS)
import UIKit

enum ProviderIcon {
    static func resourceName(for provider: QuotaProvider) -> String? {
        switch provider {
        case .codex: "ProviderIcon-codex"
        case .claude: "ProviderIcon-claude"
        case .geminiCLI: "ProviderIcon-gemini"
        case .antigravity: "ProviderIcon-antigravity"
        case .xai: "ProviderIcon-grok"
        case .kimi: "ProviderIcon-kimi"
        case .workbuddy: "ProviderIcon-workbuddy"
        case .qoder: "ProviderIcon-qoder"
        case .trae: "ProviderIcon-trae"
        case .minimax: "ProviderIcon-minimax"
        case .copilot: "ProviderIcon-copilot"
        case .deepseek: "ProviderIcon-deepseek"
        case .zcode: "ProviderIcon-zcode"
        case .stepfun: "ProviderIcon-stepfun"
        case .qwen: "ProviderIcon-qwen"
        case .doubao: "ProviderIcon-doubao"
        case .zhipu: "ProviderIcon-zhipu"
        case .hunyuan: "ProviderIcon-hunyuan"
        case .openrouter: "ProviderIcon-openrouter"
        case .ollama: "ProviderIcon-ollama"
        default: nil
        }
    }

    static func image(for provider: QuotaProvider, size: CGFloat = 16) -> UIImage? {
        guard let name = resourceName(for: provider) else { return nil }

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
        case .workbuddy: "briefcase.fill"
        case .qoder: "chevron.left.forwardslash.chevron.right"
        case .trae: "cursorarrow.rays"
        case .minimax: "waveform.path.ecg"
        case .copilot: "airplane.departure"
        case .deepseek: "magnifyingglass.circle.fill"
        case .zcode: "z.square.fill"
        case .stepfun: "star.fill"
        case .qwen: "cloud.sun.fill"
        case .doubao: "flame.fill"
        case .zhipu: "brain.head.profile"
        case .hunyuan: "water.waves"
        case .openrouter: "network"
        case .ollama: "laptopcomputer"
        case .zen: "leaf.fill"
        case .unknown: "server.rack"
        }
    }
}
#endif
