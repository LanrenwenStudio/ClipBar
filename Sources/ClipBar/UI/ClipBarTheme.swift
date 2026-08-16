import AppKit
import SwiftUI

enum ClipBarTheme {
    static let popoverWidth: CGFloat = 360
    static var popoverMaxListHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        return max(420, visible - 220)
    }
    static let settingsWidth: CGFloat = 440
    static var settingsHeight: CGFloat {
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 900
        return min(980, max(840, visibleHeight - 20))
    }

    static let horizontalPadding: CGFloat = 20
    static let headerSpacing: CGFloat = 4
    static let sectionSpacing: CGFloat = 12
    static let metricSpacing: CGFloat = 6
    static let barHeight: CGFloat = 6

    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    static let spacingXS: CGFloat = 6
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20

    static let accent = brandColor(for: .codex)

    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
    static let danger = Color(nsColor: .systemRed)

    static let windowBackground = adaptiveColor(
        light: NSColor(calibratedWhite: 0.96, alpha: 1),
        dark: NSColor(calibratedWhite: 0.12, alpha: 1)
    )

    static let cardBackground = adaptiveColor(
        light: NSColor(calibratedWhite: 1, alpha: 0.72),
        dark: NSColor(calibratedWhite: 1, alpha: 0.06)
    )

    static let inputBackground = adaptiveColor(
        light: NSColor(calibratedWhite: 1, alpha: 0.92),
        dark: NSColor(calibratedWhite: 1, alpha: 0.08)
    )

    static let progressTrack = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.14)
    )

    static let hairline = Color.primary.opacity(0.08)
    static let divider = Color.primary.opacity(0.06)

    static func brandColor(for provider: QuotaProvider) -> Color {
        switch provider {
        case .codex:
            Color(red: 73 / 255, green: 163 / 255, blue: 176 / 255)
        case .claude:
            Color(red: 204 / 255, green: 124 / 255, blue: 94 / 255)
        case .geminiCLI:
            Color(red: 171 / 255, green: 135 / 255, blue: 234 / 255)
        case .antigravity:
            Color(red: 96 / 255, green: 186 / 255, blue: 126 / 255)
        case .kimi:
            Color(red: 254 / 255, green: 96 / 255, blue: 60 / 255)
        case .xai:
            Color(red: 16 / 255, green: 163 / 255, blue: 127 / 255)
        case .unknown:
            Color(nsColor: .secondaryLabelColor)
        }
    }

    static func progressColor(for provider: QuotaProvider, remaining: Double?) -> Color {
        guard let remaining else { return .secondary }
        if remaining <= 0.5 { return danger }
        if remaining <= 20 { return warning }
        return brandColor(for: provider)
    }

    static func percentText(_ remaining: Double?) -> String {
        guard let remaining else { return "--" }
        return "\(Int(remaining.rounded()))%"
    }

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}
