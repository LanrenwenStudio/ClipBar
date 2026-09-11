import Foundation
import Testing
@testable import ClipBar

struct StatusBarSummaryTests {
    @Test("Same-provider enabled accounts pool remaining over total capacity")
    func poolsAccountsByProvider() {
        let antigravity = (0..<8).map { index in
            row(
                id: "ag\(index)",
                provider: .antigravity,
                remaining: index < 4 ? [100] : [0]
            )
        }
        let codex = row(id: "c1", provider: .codex, remaining: [80, 40])
        var settings = AppSettings.default
        settings.statusItemOrder = ["antigravity", "codex"]

        let segments = StatusBarSummary.segments(from: antigravity + [codex], settings: settings)
        #expect(segments.map(\.provider) == [.antigravity, .codex])
        #expect(segments.map(\.accountCount) == [8, 1])
        #expect(segments[0].percent == 50)
        #expect(segments[1].percent == 60)
    }

    @Test("Menu bar can show exact 5h and weekly quota together")
    func showsBothQuotaWindows() {
        let rows = [
            row(id: "c1", provider: .codex, remaining: [20, 80], windowIDs: ["5h", "7d"])
        ]
        var settings = AppSettings.default
        settings.statusQuotaDisplay = .both

        let segment = StatusBarSummary.segments(from: rows, settings: settings).first
        #expect(segment?.displayTitle == "20% / 80%")
        #expect(segment?.fiveHourRemaining == 20)
        #expect(segment?.weeklyRemaining == 80)
    }

    @Test("Status bar uses the nearest five-hour reset across accounts")
    func usesNearestFiveHourReset() {
        let rows = [
            row(id: "c1", provider: .codex, remaining: [80], windowIDs: ["5h"], resetTexts: ["3h 12m"]),
            row(id: "c2", provider: .codex, remaining: [70], windowIDs: ["5h"], resetTexts: ["1h 48m"])
        ]

        let segment = StatusBarSummary.segments(from: rows, settings: .default).first
        #expect(segment?.fiveHourResetText == "1h")

        let shortReset = row(
            id: "c3",
            provider: .codex,
            remaining: [60],
            windowIDs: ["5h"],
            resetTexts: ["56m"]
        )
        let shortSegment = StatusBarSummary.segments(from: [shortReset], settings: .default).first
        #expect(shortSegment?.fiveHourResetText == "1h")
    }

    @Test("Provider quota display override selects its own menu bar value")
    func selectsProviderQuotaDisplayOverride() {
        let rows = [
            row(id: "c1", provider: .codex, remaining: [20, 80], windowIDs: ["5h", "7d"]),
            row(id: "cl1", provider: .claude, remaining: [40, 60], windowIDs: ["5h", "7d"])
        ]
        var settings = AppSettings.default
        settings.statusQuotaDisplay = .weekly
        settings.statusQuotaDisplayOverrides[QuotaProvider.codex.rawValue] = .both

        let segments = StatusBarSummary.segments(from: rows, settings: settings)
        #expect(segments.first { $0.provider == .codex }?.displayTitle == "20% / 80%")
        #expect(segments.first { $0.provider == .claude }?.displayTitle == "60%")
    }

    @Test("Menu bar display setting selects one quota window")
    func selectsSingleQuotaWindowForDisplay() {
        let rows = [
            row(id: "c1", provider: .codex, remaining: [20, 80], windowIDs: ["5h", "7d"])
        ]
        var settings = AppSettings.default
        settings.statusQuotaDisplay = .weekly

        let segment = StatusBarSummary.segments(from: rows, settings: settings).first
        #expect(segment?.displayTitle == "80%")
        #expect(segment?.fiveHourRemaining == nil)
        #expect(segment?.weeklyRemaining == 80)
    }

    @Test("Disabled accounts are excluded from the remaining total")
    func ignoresDisabledAccounts() {
        let rows = [
            row(id: "ag1", provider: .antigravity, remaining: [100], disabled: false),
            row(id: "ag2", provider: .antigravity, remaining: [0], disabled: true),
            row(id: "ag3", provider: .antigravity, remaining: [0], disabled: false)
        ]
        let remaining = StatusBarSummary.pooledRemaining(in: rows)
        #expect(remaining == 50)

        let segments = StatusBarSummary.segments(from: rows, settings: .default)
        #expect(segments.first?.accountCount == 2)
        #expect(segments.first?.percent == 50)
    }

    @Test("ChatGPT and Antigravity summaries prefer 5h while other providers follow settings")
    func selectsProviderPreferredWindow() {
        let rows = [
            row(id: "c1", provider: .codex, remaining: [20, 80], windowIDs: ["5h", "7d"]),
            row(id: "ag1", provider: .antigravity, remaining: [40, 90], windowIDs: ["5h", "7d"]),
            row(id: "cl1", provider: .claude, remaining: [60, 70], windowIDs: ["5h", "7d"])
        ]
        var settings = AppSettings.default
        settings.statusQuotaWindow = .weekly

        let segments = StatusBarSummary.segments(from: rows, settings: settings)

        #expect(segments.first { $0.provider == .codex }?.percent == 20)
        #expect(segments.first { $0.provider == .antigravity }?.percent == 40)
        #expect(segments.first { $0.provider == .claude }?.percent == 70)
    }

    @Test("Five-hour summaries fall back when the provider has no 5h window")
    func fallsBackWhenFiveHourWindowIsAbsent() {
        let rows = [
            row(id: "c1", provider: .codex, remaining: [80], windowIDs: ["7d"]),
            row(id: "ag1", provider: .antigravity, remaining: [90], windowIDs: ["7d"])
        ]

        #expect(abs((StatusBarSummary.pooledRemaining(in: rows, preferredWindow: .weekly) ?? 0) - 85) < 0.001)
    }

    @Test("Hidden providers are omitted")
    func hiddenProviders() {
        let rows = [
            row(id: "ag1", provider: .antigravity, remaining: [100]),
            row(id: "x1", provider: .xai, remaining: [40])
        ]
        var settings = AppSettings.default
        settings.hiddenStatusItemIDs = ["xai"]
        let segments = StatusBarSummary.segments(from: rows, settings: settings)
        #expect(segments.map(\.provider) == [.antigravity])
    }

    @Test("Zero remaining providers hide when the setting is on")
    func hidesEmptyWhenEnabled() {
        let rows = [
            row(id: "g1", provider: .xai, remaining: [0]),
            row(id: "c1", provider: .codex, remaining: [40])
        ]
        var settings = AppSettings.default
        settings.hideEmptyStatusItems = true
        let segments = StatusBarSummary.segments(from: rows, settings: settings)
        #expect(segments.map(\.provider) == [.codex])
        #expect(QuotaProvider.xai.displayName == "Grok")
    }

    @Test("Empty accounts fall back to CPA")
    func emptyFallback() {
        #expect(StatusBarSummary.title(from: [], fallback: "CPA") == "CPA")
    }

    @Test("Live quota data distinguishes channels with no token data")
    func detectsLiveQuotaData() {
        let live = row(id: "live", provider: .codex, remaining: [40], windowIDs: ["5h"])
        let empty = row(id: "empty", provider: .claude, remaining: [])

        #expect(StatusBarSummary.enabledAccounts(in: [live]).contains { $0.snapshot.hasLiveData })
        #expect(!StatusBarSummary.enabledAccounts(in: [empty]).contains { $0.snapshot.hasLiveData })
    }

    private func row(
        id: String,
        provider: QuotaProvider,
        remaining: [Double],
        disabled: Bool = false,
        windowIDs: [String] = [],
        resetTexts: [String?] = []
    ) -> AccountQuota {
        AccountQuota(
            account: AuthAccount(
                id: id,
                authIndex: id,
                name: id,
                email: "\(id)@x.com",
                provider: provider,
                providerRaw: provider.rawValue,
                status: "ready",
                statusMessage: nil,
                disabled: disabled,
                unavailable: false,
                accountID: nil,
                projectID: nil,
                fileName: "\(id).json"
            ),
            snapshot: QuotaSnapshot(
                planType: nil,
                windows: remaining.enumerated().map { index, value in
                    let id = windowIDs.indices.contains(index) ? windowIDs[index] : "w\(index)"
                    let resetText = resetTexts.indices.contains(index) ? resetTexts[index] : nil
                    return QuotaWindow(id: id, label: id, remainingPercent: value, resetText: resetText)
                },
                error: remaining.isEmpty ? "none" : nil
            )
        )
    }
}
