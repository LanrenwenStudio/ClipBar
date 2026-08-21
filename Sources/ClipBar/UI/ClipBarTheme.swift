#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

enum ClipBarTheme {
    static let popoverWidth: CGFloat = 320
#if os(macOS)
    static var popoverMaxListHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        return max(380, visible - 240)
    }
    static let settingsWidth: CGFloat = 400
    static var settingsHeight: CGFloat {
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 900
        return min(920, max(780, visibleHeight - 40))
    }
#endif

    static let horizontalPadding: CGFloat = 12
    static let headerSpacing: CGFloat = 3
    static let sectionSpacing: CGFloat = 10
    static let metricSpacing: CGFloat = 5
    static let barHeight: CGFloat = 4.5

    static let cardRadius: CGFloat = 10
    static let controlRadius: CGFloat = 8

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 6
    static let spacingM: CGFloat = 10
    static let spacingL: CGFloat = 12
    static let spacingXL: CGFloat = 16
#if os(macOS)
    // Refined Warm Charcoal & Titanium Graphite (柔和深炭黑，不用死黑)
    static let charcoal = adaptiveColor(
        light: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1),
        dark: NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.96, alpha: 1)
    )
    static let accent = charcoal
    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
    static let danger = Color(nsColor: .systemRed)

    static let windowBackground = adaptiveColor(
        light: NSColor(calibratedWhite: 0.98, alpha: 1),
        dark: NSColor(calibratedWhite: 0.12, alpha: 1)
    )

    static let cardBackground = Color.primary.opacity(0.035)

    static let inputBackground = Color.primary.opacity(0.04)

    static let progressTrack = Color.primary.opacity(0.06)
#else
    // Refined Warm Charcoal & Titanium Graphite (柔和深炭黑，不用死黑)
    static let charcoal = adaptiveColor(
        light: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
    )
    static let accent = charcoal
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let danger = Color(uiColor: .systemRed)
    static let windowBackground = adaptiveColor(
        light: UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    )

    static let cardBackground = adaptiveColor(
        light: UIColor.white,
        dark: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1)
    )

    static let inputBackground = adaptiveColor(
        light: UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)
    )

    static let progressTrack = adaptiveColor(
        light: UIColor(white: 0, alpha: 0.07),
        dark: UIColor(white: 1, alpha: 0.12)
    )
#endif

    static let hairline = Color.primary.opacity(0.06)
    static let divider = Color.primary.opacity(0.06)

    static func brandColor(for provider: QuotaProvider) -> Color {
        switch provider {
        case .codex:
            // OpenAI / ChatGPT Electric Blue
            return Color(red: 0.0, green: 0.52, blue: 1.0)
        case .claude:
            // Anthropic Terracotta / Coral Orange
            return Color(red: 0.851, green: 0.467, blue: 0.341)
        case .geminiCLI:
            // Google Gemini Blue
            return Color(red: 0.259, green: 0.522, blue: 0.957)
        case .antigravity:
            // Cursor / Antigravity Vivid Blue
            return Color(red: 0.0, green: 0.439, blue: 1.0)
        case .kimi:
            // Kimi Blue
            return Color(red: 0.145, green: 0.388, blue: 0.922)
        case .xai:
            // Grok / xAI Sky Slate
            return Color(red: 0.22, green: 0.74, blue: 0.97)
        case .unknown:
            return charcoal
        }
    }

    static func widgetBarColor(for provider: QuotaProvider, remaining: Double?) -> Color {
        guard let remaining else { return charcoal }
        if remaining <= QuotaDisplayScale.exhausted || remaining <= 5.0 {
            return danger
        }
        if remaining <= 20.0 {
            return warning
        }
        return charcoal
    }
    static func progressColor(for provider: QuotaProvider, remaining: Double?) -> Color {
        guard let remaining else { return .secondary }
        if remaining <= QuotaDisplayScale.exhausted || remaining <= QuotaDisplayScale.step {
            return danger
        }
        if remaining <= QuotaDisplayScale.step * 2 {
            return Color(red: 0.93, green: 0.40, blue: 0.12)
        }
        if remaining <= QuotaDisplayScale.step * 3 {
            return warning
        }
        if remaining <= QuotaDisplayScale.step * 4 {
            return Color(red: 0.95, green: 0.68, blue: 0.10)
        }
        if remaining <= QuotaDisplayScale.step * 5 {
            return Color(red: 0.95, green: 0.80, blue: 0.12)
        }
        if remaining <= QuotaDisplayScale.warningCeiling {
            return Color(red: 0.86, green: 0.76, blue: 0.16)
        }
        return charcoal
    }
    static func percentText(_ remaining: Double?) -> String {
        guard let remaining else { return "--" }
        return "\(Int(remaining.rounded()))%"
    }

#if os(macOS)
    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
#else
    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
#endif
}
