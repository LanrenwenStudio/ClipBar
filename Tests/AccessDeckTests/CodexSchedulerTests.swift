import Foundation
import Testing
@testable import AccessDeck

@MainActor
struct CodexSchedulerTests {
    @Test("CodexSchedulerStatus decodes valid status JSON and detects stale samples")
    func decodesSchedulerStatus() throws {
        let json = """
        {
          "time": "2026-10-20T10:39:14.468Z",
          "event": "status",
          "managedBy": "AccessDeck",
          "samplesCount": 10,
          "latestSamples": [
            {
              "time": 1792492201268,
              "account": "88a90c1be98d9deb",
              "quota": {
                "allowed": true,
                "primary": { "used": 55, "reset": 1792496620000, "seconds": 18000 },
                "weekly": { "used": 20, "reset": 1793083420000, "seconds": 604800 }
              }
            }
          ],
          "plan": {
            "date": "2026-10-20",
            "accounts": [
              {
                "account": "88a90c1be98d9deb",
                "times": ["07:00", "12:00", "17:00"],
                "reason": "保留基线07:00、12:00、17:00"
              }
            ],
            "createdAt": 1792487883269
          },
          "planning": [
            { "time": 1792487875636, "date": "2026-10-20", "status": "completed" }
          ],
          "attempts": [
            {
              "time": 1792487918140,
              "account": "88a90c1be98d9deb",
              "key": "2026-10-20/88a90c1be98d9deb/17:00",
              "status": "skipped",
              "reason": "window-already-active",
              "resetBefore": 1792496620000
            }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let status = try JSONDecoder().decode(CodexSchedulerStatus.self, from: data)

        #expect(status.managedBy == "AccessDeck")
        #expect(status.samplesCount == 10)
        #expect(status.latestSamples.count == 1)
        #expect(status.latestSamples[0].shortAccountID == "8d9deb")
        #expect(status.latestSamples[0].quota?.primary?.used == 55)

        #expect(status.plan?.accounts.count == 1)
        #expect(status.plan?.accounts[0].timesSummary == "07:00、12:00、17:00")
        #expect(status.planning.first?.localizedStatus == "规划成功")

        let attempt = try #require(status.attempts.first)
        #expect(attempt.status == "skipped")
        #expect(attempt.localizedStatus == "跳过")
        #expect(attempt.localizedReason == "已有活跃窗口，无需唤醒")
        #expect(attempt.shortAccountID == "8d9deb")
    }

    @Test("CodexSchedulerStatus decodes legacy router state.json containing samples array")
    func decodesLegacyRouterState() throws {
        let legacyJson = """
        {
          "samples": [
            { "time": 1000, "account": "acc1", "quota": { "allowed": true, "primary": { "used": 10, "reset": 2000, "seconds": 18000 } } },
            { "time": 2000, "account": "acc1", "quota": { "allowed": true, "primary": { "used": 20, "reset": 2000, "seconds": 18000 } } },
            { "time": 1500, "account": "acc2", "quota": { "allowed": true, "primary": { "used": 30, "reset": 3000, "seconds": 18000 } } }
          ],
          "planning": [],
          "attempts": []
        }
        """
        let data = legacyJson.data(using: .utf8)!
        let status = try JSONDecoder().decode(CodexSchedulerStatus.self, from: data)

        #expect(status.samplesCount == 3)
        #expect(status.latestSamples.count == 2)
        let acc1 = status.latestSamples.first { $0.account == "acc1" }
        #expect(acc1?.quota?.primary?.used == 20)
    }

    @Test("CodexSchedulerClient derives status endpoint URL on port 8318")
    func derivesStatusEndpointURL() {
        let client = CodexSchedulerClient(baseURL: "http://192.168.1.3:8317")
        #expect(client.statusEndpointURL?.absoluteString == "http://192.168.1.3:8318/status")

        let domainClient = CodexSchedulerClient(baseURL: "https://cpa.example.com:9000/api")
        #expect(domainClient.statusEndpointURL?.absoluteString == "https://cpa.example.com:8318/status")
    }

    @Test("CodexSchedulerEngine validatePlan strictly checks plan contract")
    func validatePlanInEngine() throws {
        let engine = CodexSchedulerEngine.shared
        let date = "2026-10-20"
        let accounts = ["acc-1", "acc-2"]

        let validRaw: [String: Any] = [
            "date": date,
            "accounts": [
                ["account": "acc-1", "times": ["07:00", "12:00", "17:00"], "reason": "测试理由1"],
                ["account": "acc-2", "times": ["08:30"], "reason": "测试理由2"]
            ]
        ]
        let plan = try engine.validatePlan(raw: validRaw, date: date, accountIDs: accounts)
        #expect(plan.accounts.count == 2)
        #expect(plan.accounts[0].times == ["07:00", "12:00", "17:00"])

        // 校验非法时点间隔 (<4h) 抛出异常
        let invalidTimesRaw: [String: Any] = [
            "date": date,
            "accounts": [
                ["account": "acc-1", "times": ["07:00", "09:00"], "reason": "过密"],
                ["account": "acc-2", "times": [], "reason": "无"]
            ]
        ]
        #expect(throws: Error.self) {
            try engine.validatePlan(raw: invalidTimesRaw, date: date, accountIDs: accounts)
        }
    }

    @Test("CodexSchedulerEngine decideActivation detects active windows, caps and intervals")
    func decideActivationInEngine() {
        let engine = CodexSchedulerEngine.shared
        let nowMs: Double = 1792492200000
        let account = "acc-test"

        // 1. 活跃窗口 (used > 0 且 reset > now) -> window-already-active
        let activeSample = SchedulerSample(
            time: nowMs - 1000,
            account: account,
            quota: SchedulerQuota(
                allowed: true,
                primary: SchedulerQuotaWindow(used: 15, reset: nowMs + 3600000, seconds: 18000),
                weekly: SchedulerQuotaWindow(used: 20, reset: nowMs + 86400000, seconds: 604800)
            )
        )
        let reason1 = engine.decideActivation(sample: activeSample, account: account, attempts: [], nowMs: nowMs, date: "2026-10-20")
        #expect(reason1 == "window-already-active")

        // 2. 额度耗尽 -> quota-exhausted
        let exhaustedSample = SchedulerSample(
            time: nowMs - 1000,
            account: account,
            quota: SchedulerQuota(
                allowed: true,
                primary: SchedulerQuotaWindow(used: 100, reset: nowMs + 3600000, seconds: 18000),
                weekly: SchedulerQuotaWindow(used: 100, reset: nowMs + 86400000, seconds: 604800)
            )
        )
        let reason2 = engine.decideActivation(sample: exhaustedSample, account: account, attempts: [], nowMs: nowMs, date: "2026-10-20")
        #expect(reason2 == "quota-exhausted")

        // 3. 空闲窗口允许唤醒 -> nil
        let idleSample = SchedulerSample(
            time: nowMs - 1000,
            account: account,
            quota: SchedulerQuota(
                allowed: true,
                primary: SchedulerQuotaWindow(used: 0, reset: nowMs - 1000, seconds: 18000),
                weekly: SchedulerQuotaWindow(used: 20, reset: nowMs + 86400000, seconds: 604800)
            )
        )
        let reason3 = engine.decideActivation(sample: idleSample, account: account, attempts: [], nowMs: nowMs, date: "2026-10-20")
        #expect(reason3 == nil)
    }
}
