#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

enum ClipBarTheme {
    static let popoverWidth: CGFloat = 360
#if os(macOS)
    static var popoverMaxListHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        return max(420, visible - 220)
    }
    static let settingsWidth: CGFloat = 440
    static var settingsHeight: CGFloat {
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 900
        return min(980, max(840, visibleHeight - 20))
    }
#endif

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
        light: NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.97, alpha: 1),
        dark: NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
    )

    static let cardBackground = adaptiveColor(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.92),
        dark: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.20, alpha: 0.85)
    )

    static let inputBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1),
        dark: NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 0.9)
    )

    static let progressTrack = adaptiveColor(
        light: NSColor(calibratedWhite: 0, alpha: 0.08),
        dark: NSColor(calibratedWhite: 1, alpha: 0.12)
    )
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

    static let hairline = Color.primary.opacity(0.10)
    static let divider = Color.primary.opacity(0.08)

    static func brandColor(for provider: QuotaProvider) -> Color {
        charcoal
    }

    static func progressColor(for provider: QuotaProvider, remaining: Double?) -> Color {
        guard let remaining else { return .secondary }
        if remaining <= 0.5 { return danger }
        if remaining <= 20 { return warning }
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
