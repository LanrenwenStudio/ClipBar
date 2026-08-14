import Foundation
import Testing
@testable import ClipBar

struct QuotaParserTests {
    @Test("Codex WHAM payload maps 5h and 7d remaining percent")
    func parseCodexWindows() throws {
        let snapshot = QuotaParser.parseCodex([
            "plan_type": "plus",
            "rate_limit": [
                "primary_window": [
                    "used_percent": 25.0,
                    "reset_after_seconds": 3600,
                    "limit_window_seconds": 18_000
                ],
                "secondary_window": [
                    "used_percent": 10.0,
                    "reset_after_seconds": 172_800,
                    "limit_window_seconds": 604_800
                ]
            ]
        ])

        #expect(snapshot.planType == "plus")
        #expect(snapshot.windows.count == 2)
        #expect(snapshot.windows[0].id == "5h")
        #expect(snapshot.windows[0].remainingPercent == 75)
        #expect(snapshot.windows[0].resetText == "1h 0m")
        #expect(snapshot.windows[1].id == "7d")
        #expect(snapshot.windows[1].label == "7d")
        #expect(snapshot.windows[1].remainingPercent == 90)
    }

    @Test("Claude OAuth usage maps utilization to remaining percent")
    func parseClaudeWindows() {
        let snapshot = QuotaParser.parseClaude([
            "five_hour": [
                "utilization": 40.0,
                "resets_at": "2099-01-01T00:00:00Z"
            ],
            "seven_day": [
                "utilization": 15.0,
                "resets_at": "2099-01-07T00:00:00Z"
            ]
        ])

        #expect(snapshot.planType == "claude")
        #expect(snapshot.windows.map(\.id) == ["5h", "7d"])
        #expect(snapshot.windows[0].remainingPercent == 60)
        #expect(snapshot.windows[1].remainingPercent == 85)
        #expect(snapshot.windows[0].resetText != nil)
    }

    @Test("Gemini buckets keep remainingFraction as percent")
    func parseGeminiBuckets() {
        let snapshot = QuotaParser.parseGemini([
            "buckets": [
                [
                    "modelId": "gemini-2.5-flash",
                    "remainingFraction": 0.4,
                    "resetTime": "2099-01-01T00:00:00Z"
                ]
            ]
        ])

        #expect(snapshot.windows.count == 1)
        #expect(snapshot.windows[0].remainingPercent == 40)
        #expect(snapshot.windows[0].label.contains("2.5-flash"))
    }

    @Test("Antigravity keeps only the 5-hour remaining window")
    func parseAntigravityFiveHourOnly() {
        let snapshot = QuotaParser.parseAntigravity([
            "groups": [
                [
                    "displayName": "Gemini",
                    "buckets": [
                        [
                            "window": "5h",
                            "remainingFraction": 0.4,
                            "resetTime": "2099-01-01T00:00:00Z"
                        ],
                        [
                            "window": "weekly",
                            "remainingFraction": 0.9
                        ]
                    ]
                ]
            ]
        ])

        #expect(snapshot.windows.map(\.id) == ["5h"])
        #expect(snapshot.windows[0].label == "5h")
        #expect(snapshot.windows[0].remainingPercent == 40)
    }

    @Test("Antigravity model fallback still collapses to one 5h bar")
    func parseAntigravityModels() {
        let snapshot = QuotaParser.parseAntigravity([
            "models": [
                "gemini-3-flash": [
                    "displayName": "Gemini 3 Flash",
                    "quotaInfo": [
                        "remainingFraction": 0.2,
                        "resetTime": "2099-01-01T00:00:00Z"
                    ]
                ]
            ]
        ])

        #expect(snapshot.windows.count == 1)
        #expect(snapshot.windows[0].id == "5h")
        #expect(snapshot.windows[0].remainingPercent == 20)
        #expect(snapshot.windows[0].isLow)
    }

    @Test("JWT payload exposes chatgpt_account_id")
    func parseChatGPTAccountID() {
        let payload = Data("{\"chatgpt_account_id\":\"acc-123\"}".utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let jwt = "aaa.\(payload).sig"
        #expect(QuotaParser.chatgptAccountID(fromJWT: jwt) == "acc-123")
    }

    @Test("Auth file map prefers account_id then JWT")
    func parseAuthAccountIDs() {
        let fromField = QuotaService.codexAccountID(from: ["account_id": "field-id"])
        #expect(fromField == "field-id")

        let payload = Data("{\"chatgpt_account_id\":\"jwt-id\"}".utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let fromJWT = QuotaService.codexAccountID(from: ["id_token": "h.\(payload).s"])
        #expect(fromJWT == "jwt-id")
    }

    @Test("Auth file provider aliases collapse to known channels")
    func parseAuthAccountProvider() {
        let account = QuotaService.account(from: [
            "name": "codex-user.json",
            "auth_index": "abc",
            "email": "user@example.com",
            "provider": "openai",
            "account_id": "acc-1",
            "status": "ready"
        ])
        #expect(account.provider == .codex)
        #expect(account.displayName == "user@example.com")
        #expect(account.accountID == "acc-1")
    }

    @Test("xAI weekly and monthly billing map remaining percent")
    func parseXaiBilling() {
        let weekly = QuotaParser.parseXai([
            "config": [
                "creditUsagePercent": 30.0,
                "currentPeriod": [
                    "type": "WEEKLY",
                    "end": "2099-01-08T00:00:00Z"
                ],
                "productUsage": [
                    ["product": "grok-4", "usagePercent": 10.0]
                ]
            ]
        ])
        let monthly = QuotaParser.parseXai([
            "config": [
                "monthlyLimit": ["val": 15000],
                "used": 3000,
                "billingPeriodEnd": "2099-02-01T00:00:00Z"
            ]
        ])
        let merged = QuotaParser.mergeXai(weekly: weekly, monthly: monthly)

        #expect(weekly.windows.contains { $0.id == "week" && $0.remainingPercent == 70 })
        #expect(weekly.windows.contains { $0.id == "product-grok-4" && $0.remainingPercent == 90 })
        #expect(monthly.planType == "SuperGrok")
        #expect(merged.planType == "SuperGrok")
        #expect(monthly.windows.contains { $0.id == "month" && $0.remainingPercent == 80 })
        #expect(merged.windows.map(\.id) == ["week", "product-grok-4", "month"])
    }

    @Test("Antigravity loadCodeAssist exposes current tier")
    func parseAntigravityTier() {
        let snapshot = QuotaParser.parseAntigravity([
            "currentTier": ["id": "ULTRA", "name": "Ultra"],
            "models": [
                "gemini-3-flash": [
                    "displayName": "Gemini 3 Flash",
                    "quotaInfo": ["remainingFraction": 0.5]
                ]
            ]
        ])
        #expect(snapshot.planType == "Ultra")
        #expect(snapshot.windows.first?.remainingPercent == 50)
    }

    @Test("xAI auth aliases resolve to grok user id")
    func parseXaiAccount() {
        let account = QuotaService.account(from: [
            "name": "grok-user.json",
            "auth_index": "x1",
            "provider": "grok",
            "sub": "user-42",
            "status": "ready"
        ])
        #expect(account.provider == .xai)
        #expect(account.accountID == "user-42")
    }
}
