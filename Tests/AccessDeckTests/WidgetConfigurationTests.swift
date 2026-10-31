import Foundation
import Testing
@testable import AccessDeck

struct WidgetConfigurationTests {
    private func makeSampleProviders() -> [ProviderWidgetData] {
        [
            ProviderWidgetData(
                providerRawValue: "codex",
                displayName: "Codex",
                remainingPercent: 88,
                accountCount: 1,
                healthyCount: 1,
                statusText: "正常",
                windows: [
                    QuotaWindowSummary(label: "5h", remainingPercent: 88, resetText: "2h")
                ]
            ),
            ProviderWidgetData(
                providerRawValue: "antigravity",
                displayName: "Agy",
                remainingPercent: 95,
                accountCount: 1,
                healthyCount: 1,
                statusText: "正常",
                windows: [
                    QuotaWindowSummary(label: "5h", remainingPercent: 95, resetText: "3h")
                ]
            ),
            ProviderWidgetData(
                providerRawValue: "claude",
                displayName: "Claude",
                remainingPercent: 70,
                accountCount: 1,
                healthyCount: 1,
                statusText: "正常",
                windows: [
                    QuotaWindowSummary(label: "5h", remainingPercent: 70, resetText: "1h")
                ]
            ),
            ProviderWidgetData(
                providerRawValue: "workbuddy",
                displayName: "WorkBuddy",
                remainingPercent: 100,
                accountCount: 1,
                healthyCount: 1,
                statusText: "正常",
                windows: [
                    QuotaWindowSummary(label: "Credits", remainingPercent: 100, resetText: "--")
                ]
            )
        ]
    }

    @Test("Widget resolves 1 channel configuration")
    func resolveOneChannel() {
        let providers = makeSampleProviders()
        let result = resolveDisplayProviders(
            allProviders: providers,
            choices: [.antigravity],
            targetCount: 1
        )
        #expect(result.count == 1)
        #expect(result[0].provider == .antigravity)
    }

    @Test("Widget resolves 2 channels configuration")
    func resolveTwoChannels() {
        let providers = makeSampleProviders()
        let result = resolveDisplayProviders(
            allProviders: providers,
            choices: [.workbuddy, .codex],
            targetCount: 2
        )
        #expect(result.count == 2)
        #expect(result[0].provider == .workbuddy)
        #expect(result[1].provider == .codex)
    }

    @Test("Widget resolves 4 channels with explicit choices")
    func resolveFourChannels() {
        let providers = makeSampleProviders()
        let result = resolveDisplayProviders(
            allProviders: providers,
            choices: [.workbuddy, .antigravity, .claude, .codex],
            targetCount: 4
        )
        #expect(result.count == 4)
        #expect(result[0].provider == .workbuddy)
        #expect(result[1].provider == .antigravity)
        #expect(result[2].provider == .claude)
        #expect(result[3].provider == .codex)
    }

    @Test("Widget auto-fills unspecified slots without duplicating")
    func resolveAutoFill() {
        let providers = makeSampleProviders()
        let result = resolveDisplayProviders(
            allProviders: providers,
            choices: [.workbuddy, .auto, .auto],
            targetCount: 3
        )
        #expect(result.count == 3)
        #expect(result[0].provider == .workbuddy)
        #expect(result[1].provider == .codex)
        #expect(result[2].provider == .antigravity)
    }

    @Test("Widget respects .none slot selection")
    func resolveNoneChoice() {
        let providers = makeSampleProviders()
        let result = resolveDisplayProviders(
            allProviders: providers,
            choices: [.codex, .none, .workbuddy],
            targetCount: 3
        )
        #expect(result.count == 2)
        #expect(result[0].provider == .codex)
        #expect(result[1].provider == .workbuddy)
    }

    @Test("Widget creates placeholder for unconfigured provider choice")
    func resolveMissingProviderPlaceholder() {
        let providers = makeSampleProviders()
        let result = resolveDisplayProviders(
            allProviders: providers,
            choices: [.deepseek],
            targetCount: 1
        )
        #expect(result.count == 1)
        #expect(result[0].provider == .deepseek)
        #expect(result[0].displayName == "DeepSeek")
    }
}
