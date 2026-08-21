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
        #expect(snapshot.windows[1].label == "周额度" || snapshot.windows[1].label == "Week")
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

    @Test("Antigravity maps 5-hour and weekly remaining windows")
    func parseAntigravityWindows() {
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

        #expect(snapshot.windows.map(\.id) == ["5h", "7d"])
        #expect(snapshot.windows[0].label == "5h")
        #expect(snapshot.windows[0].remainingPercent == 40)
        #expect(snapshot.windows[1].label == "周额度" || snapshot.windows[1].label == "Week")
        #expect(snapshot.windows[1].remainingPercent == 90)
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
        #expect(QuotaProvider.kimi.supportsLiveQuota)
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

    @Test("xAI omitted used percent after reset is full remaining")
    func parseXaiResetOmitsUsedPercent() {
        let weekly = QuotaParser.parseXai([
            "config": [
                "currentPeriod": [
                    "type": "USAGE_PERIOD_TYPE_WEEKLY",
                    "start": "2026-08-18T18:14:30.145601+00:00",
                    "end": "2026-08-25T18:14:30.145601+00:00"
                ],
                "onDemandCap": ["val": 0],
                "onDemandUsed": ["val": 0]
            ]
        ])
        let explicitZero = QuotaParser.parseXai([
            "config": [
                "creditUsagePercent": 0,
                "currentPeriod": [
                    "type": "USAGE_PERIOD_TYPE_WEEKLY",
                    "end": "2099-01-08T00:00:00Z"
                ]
            ]
        ])
        let onePercentUsed = QuotaParser.parseXai([
            "config": [
                "creditUsagePercent": 1.0,
                "currentPeriod": [
                    "type": "USAGE_PERIOD_TYPE_WEEKLY",
                    "end": "2099-01-08T00:00:00Z"
                ],
                "productUsage": [
                    ["product": "GrokBuild", "usagePercent": 1.0]
                ]
            ]
        ])

        #expect(weekly.windows.contains { $0.id == "week" && $0.remainingPercent == 100 })
        #expect(weekly.error == nil)
        #expect(explicitZero.windows.contains { $0.id == "week" && $0.remainingPercent == 100 })
        #expect(onePercentUsed.windows.contains { $0.id == "week" && $0.remainingPercent == 99 })
        #expect(!onePercentUsed.windows.contains { $0.id == "product-GrokBuild" })
    }

    @Test("xAI monthly payload without currentPeriod does not invent a week window")
    func parseXaiMonthlyDoesNotInventWeek() {
        let monthly = QuotaParser.parseXai([
            "config": [
                "monthlyLimit": ["val": 0],
                "used": ["val": 16],
                "billingPeriodEnd": "2026-09-01T00:00:00+00:00"
            ]
        ])
        #expect(!monthly.windows.contains { $0.id == "week" })
        #expect(monthly.windows.isEmpty)
    }

    @Test("Kimi coding usage maps weekly and rate-limit windows")
    func parseKimiWindows() {
        let snapshot = QuotaParser.parseKimi([
            "user": [
                "membership": ["level": "LEVEL_MODERATO"]
            ],
            "usage": [
                "limit": "2048",
                "used": "214",
                "remaining": "1834",
                "resetTime": "2099-01-09T15:23:13.716839300Z"
            ],
            "limits": [
                [
                    "window": ["duration": 300, "timeUnit": "TIME_UNIT_MINUTE"],
                    "detail": [
                        "limit": 200,
                        "used": 50,
                        "remaining": 150,
                        "reset_at": "2099-01-06T13:33:02Z"
                    ]
                ]
            ]
        ])

        #expect(snapshot.planType == "Moderato")
        #expect(snapshot.windows.map(\.id) == ["7d", "5h"])
        #expect(abs((snapshot.windows[0].remainingPercent ?? 0) - 89.55078125) < 0.001)
        #expect(snapshot.windows[1].remainingPercent == 75)
        #expect(snapshot.windows[0].resetText != nil)
    }

    @Test("Kimi usages array selects the coding scope")
    func parseKimiUsagesArray() {
        let snapshot = QuotaParser.parseKimi([
            "usages": [
                [
                    "scope": "FEATURE_OMNI",
                    "detail": ["limit": 100, "remaining": 10]
                ],
                [
                    "scope": "FEATURE_CODING",
                    "detail": ["limit": 100, "used": 25]
                ]
            ]
        ])

        #expect(snapshot.windows.map(\.id) == ["7d"])
        #expect(snapshot.windows[0].remainingPercent == 75)
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
