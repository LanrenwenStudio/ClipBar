import Foundation
import Testing
@testable import ClipQuota

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

    private func row(
        id: String,
        provider: QuotaProvider,
        remaining: [Double],
        disabled: Bool = false
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
                    QuotaWindow(id: "w\(index)", label: "w\(index)", remainingPercent: value, resetText: nil)
                },
                error: remaining.isEmpty ? "none" : nil
            )
        )
    }
}
