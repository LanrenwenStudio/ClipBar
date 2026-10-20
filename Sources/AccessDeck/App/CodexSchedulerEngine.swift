import Foundation

/// AccessDeck - Codex Plus 额度自适应调度与统计引擎
/// 负责在 Mac 端直接由轮询采样驱动额度记录、48槽位消耗统计、每日一次 AI 规划与受限窗口唤醒。
/// 关键语义：最小请求绝不保证或强制刷新/重置额度，仅在空闲期尝试开启五小时窗口。
@MainActor
final class CodexSchedulerEngine {
    static let shared = CodexSchedulerEngine()

    private let stateFileName = "codex-scheduler-state.json"
    private let dayMs: Double = 86_400_000
    private let halfHourMs: Double = 1_800_000

    private var state: CodexSchedulerStatus = CodexSchedulerStatus()
    private var isExecuting = false

    private init() {
        loadState()
    }

    // MARK: - 持久化存储

    private var storageFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AccessDeck", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(stateFileName)
    }

    func currentState() -> CodexSchedulerStatus {
        state
    }

    private func loadState() {
        let url = storageFileURL
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode(CodexSchedulerStatus.self, from: data) {
            self.state = loaded
            return
        }

        #if os(macOS)
        if let remoteState = try? fetchRemoteStateMigration() {
            self.state = remoteState
            saveState()
            return
        }
        #endif

        self.state = CodexSchedulerStatus()
    }

    func saveState() {
        let url = storageFileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(state) else { return }

        let tmpURL = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmpURL, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        } catch {
            try? data.write(to: url, options: .atomic)
        }

        #if os(macOS)
        syncStateToRouterAsync(data: data)
        #endif
    }

    #if os(macOS)
    private func fetchRemoteStateMigration() throws -> CodexSchedulerStatus? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=3",
            "root@192.168.1.3",
            "cat /root/CLIProxyAPI/plus-scheduler/state.json"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return try? JSONDecoder().decode(CodexSchedulerStatus.self, from: data)
    }

    private func syncStateToRouterAsync(data: Data) {
        Task.detached(priority: .background) {
            let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("state-sync-\(UUID().uuidString).json")
            try? data.write(to: tmpFile)
            defer { try? FileManager.default.removeItem(at: tmpFile) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
            process.arguments = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=3",
                tmpFile.path,
                "root@192.168.1.3:/root/CLIProxyAPI/plus-scheduler/state.json"
            ]
            try? process.run()
            process.waitUntilExit()
        }
    }
    #endif

    // MARK: - 时区与时间计算（以 Asia/Shanghai 为准）

    static func beijingDateString(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func beijingMinuteOfDay(for date: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    static func parseDateAndTimeString(date: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter.date(from: "\(date)T\(time):00+08:00")
    }

    // MARK: - 核心入口：处理从 Mac 轮询获得的新数据

    func processPollCycle(
        accounts: [AccountQuota],
        settings: AppSettings,
        client: ManagementClient
    ) async -> CodexSchedulerStatus {
        guard !isExecuting else { return state }
        isExecuting = true
        defer { isExecuting = false }

        let now = Date()
        let nowMs = now.timeIntervalSince1970 * 1000

        // 1. 采集并记录新样本
        let plusRows = filterPlusAccounts(accounts, settings: settings)
        var latestMap: [String: SchedulerSample] = [:]

        for row in plusRows {
            let authIndex = row.account.authIndex
            guard !authIndex.isEmpty else { continue }

            let primaryWin = findFiveHourWindow(row.snapshot.windows)
            let weeklyWin = findWeeklyWindow(row.snapshot.windows)

            let quotaObj: SchedulerQuota?
            if let primaryWin, let weeklyWin {
                let pUsed = primaryWin.remainingPercent.map { 100.0 - $0 }
                let wUsed = weeklyWin.remainingPercent.map { 100.0 - $0 }
                let pReset = parseResetTimestamp(primaryWin.resetText, nowMs: nowMs)
                let wReset = parseResetTimestamp(weeklyWin.resetText, nowMs: nowMs)

                quotaObj = SchedulerQuota(
                    allowed: (row.snapshot.error == nil),
                    primary: SchedulerQuotaWindow(used: pUsed, reset: pReset, seconds: 18000),
                    weekly: SchedulerQuotaWindow(used: wUsed, reset: wReset, seconds: 604800)
                )
            } else {
                quotaObj = nil
            }

            let sample = SchedulerSample(
                time: nowMs,
                account: authIndex,
                quota: quotaObj,
                error: row.snapshot.error
            )
            latestMap[authIndex] = sample
        }

        // 追加新样本并清理 30 天前过期数据
        var allSamples = loadAllSamples()
        for (_, sample) in latestMap {
            allSamples.append(sample)
        }
        let cutoff = nowMs - 30 * dayMs
        allSamples.removeAll { ($0.time ?? 0) < cutoff }
        saveAllSamples(allSamples)

        // 2. 每日 AI 规划（北京时间 04:00 后首次运行尝试）
        let today = Self.beijingDateString(for: now)
        let minOfDay = Self.beijingMinuteOfDay(for: now)
        if minOfDay >= 240 && !state.planning.contains(where: { $0.date == today }) {
            await makePlan(
                date: today,
                accounts: Array(latestMap.keys).sorted(),
                settings: settings,
                client: client,
                allSamples: allSamples,
                now: now
            )
        }

        // 3. 检查并执行到期时点的受限唤醒
        await executeDueWakeups(
            date: today,
            accounts: plusRows,
            latestSamples: latestMap,
            client: client,
            now: now
        )

        // 4. 更新当前状态结构并落盘
        var uniqueAccountIDs = [String]()
        for s in allSamples {
            if !uniqueAccountIDs.contains(s.account) {
                uniqueAccountIDs.append(s.account)
            }
        }
        uniqueAccountIDs.sort()

        let latestSamplesList = uniqueAccountIDs.compactMap { id -> SchedulerSample? in
            if let recent = latestMap[id] { return recent }
            return allSamples.filter { $0.account == id }.last
        }

        let validCount = allSamples.filter { $0.quota != nil }.count
        let historyH = calculateHistoryHours(samples: allSamples, nowMs: nowMs)

        self.state = CodexSchedulerStatus(
            time: ISO8601DateFormatter().string(from: now),
            event: "tick",
            managedBy: "AccessDeck",
            samplesCount: allSamples.count,
            latestSamples: latestSamplesList,
            plan: state.plan,
            planning: state.planning,
            attempts: state.attempts,
            summary: SchedulerSummary(
                timezone: "Asia/Shanghai",
                validSamples: validCount,
                historyHours: historyH
            )
        )
        saveState()
        return self.state
    }

    private func filterPlusAccounts(_ accounts: [AccountQuota], settings: AppSettings) -> [AccountQuota] {
        accounts.filter { row in
            guard row.account.provider == .codex, !row.account.disabled else { return false }
            let isLocallyDisabled = settings.isAccountDisabled(statusKey: row.account.statusKey, serverDisabled: row.account.disabled)
            guard !isLocallyDisabled else { return false }
            let isPlus = row.snapshot.planType?.lowercased().contains("plus") == true
            return isPlus || row.snapshot.windows.count >= 2
        }
    }

    private func findFiveHourWindow(_ windows: [QuotaWindow]) -> QuotaWindow? {
        windows.first { w in
            let label = w.label.lowercased()
            return label.contains("5h") || label.contains("five-hour") || label.contains("5小时") || w.id == "5h"
        }
    }

    private func findWeeklyWindow(_ windows: [QuotaWindow]) -> QuotaWindow? {
        windows.first { w in
            let label = w.label.lowercased()
            return label.contains("week") || label.contains("7d") || label.contains("周") || w.id == "7d"
        }
    }

    // MARK: - 辅助样本持久化

    private var allSamplesFileURL: URL {
        storageFileURL.deletingLastPathComponent().appendingPathComponent("codex-samples-history.json")
    }

    private func loadAllSamples() -> [SchedulerSample] {
        if let data = try? Data(contentsOf: allSamplesFileURL),
           let samples = try? JSONDecoder().decode([SchedulerSample].self, from: data) {
            return samples
        }
        return state.latestSamples
    }

    private func saveAllSamples(_ samples: [SchedulerSample]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(samples) {
            try? data.write(to: allSamplesFileURL, options: .atomic)
        }
    }

    private func calculateHistoryHours(samples: [SchedulerSample], nowMs: Double) -> Double {
        guard let first = samples.first?.time else { return 0 }
        return max(0, (nowMs - first) / 3_600_000)
    }

    private func parseResetTimestamp(_ resetText: String?, nowMs: Double) -> Double? {
        guard let text = resetText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return nowMs + 18000 * 1000
    }

    // MARK: - 消耗统计与 AI 规划

    static func summarizeUsage(samples: [SchedulerSample], nowMs: Double) -> [String: Any] {
        let sevenDaysAgo = nowMs - 7 * 86_400_000
        let recent = samples.filter { ($0.time ?? 0) >= sevenDaysAgo }
        var slots = (0..<48).map { i -> [String: Any] in
            let hour = String(format: "%02d", i / 2)
            let min = i % 2 == 0 ? "00" : "30"
            return ["time": "\(hour):\(min)", "accounts": [String: [String: Any]]()]
        }

        var lastMap = Dictionary<String, SchedulerSample>()
        var intervals = [[String: Any]]()

        for s in recent {
            guard let q = s.quota, let sTime = s.time else {
                lastMap.removeValue(forKey: s.account)
                continue
            }
            guard let p = lastMap[s.account], let pTime = p.time, let pQ = p.quota else {
                lastMap[s.account] = s
                continue
            }
            lastMap[s.account] = s
            let diff = sTime - pTime
            if diff > 45 * 60_000 || diff <= 0 { continue }

            let sameReset = (q.primary?.reset == pQ.primary?.reset)
            let pUsed = pQ.primary?.used ?? 0
            let sUsed = q.primary?.used ?? 0
            let usedDelta = sameReset ? (sUsed - pUsed) : sUsed
            if usedDelta < 0 { continue }

            let pDate = Date(timeIntervalSince1970: pTime / 1000.0)
            let minVal = beijingMinuteOfDay(for: pDate)
            let slotIndex = min(47, max(0, minVal / 30))

            var accountsInSlot = slots[slotIndex]["accounts"] as? [String: [String: Any]] ?? [:]
            var agg = accountsInSlot[s.account] ?? ["observed": 0, "consumedPercent": 0.0, "resetIntervals": 0]
            agg["observed"] = (agg["observed"] as? Int ?? 0) + 1
            agg["consumedPercent"] = (agg["consumedPercent"] as? Double ?? 0.0) + usedDelta
            if !sameReset {
                agg["resetIntervals"] = (agg["resetIntervals"] as? Int ?? 0) + 1
            }
            accountsInSlot[s.account] = agg
            slots[slotIndex]["accounts"] = accountsInSlot

            if sTime >= nowMs - 86_400_000 {
                intervals.append([
                    "account": s.account,
                    "from": pTime,
                    "to": sTime,
                    "consumedPercent": usedDelta,
                    "crossedReset": !sameReset
                ])
            }
        }

        return [
            "timezone": "Asia/Shanghai",
            "sevenDaySlots": slots,
            "last24Hours": intervals,
            "validSamples": recent.filter { $0.quota != nil }.count
        ]
    }

    private func makePlan(
        date: String,
        accounts: [String],
        settings: AppSettings,
        client: ManagementClient,
        allSamples: [SchedulerSample],
        now: Date
    ) async {
        guard !accounts.isEmpty else { return }
        let nowMs = now.timeIntervalSince1970 * 1000

        var planningRecords = state.planning
        let attempt = SchedulerPlanningRecord(time: nowMs, date: date, status: "started")
        planningRecords.append(attempt)
        state = CodexSchedulerStatus(
            time: state.time,
            event: state.event,
            managedBy: state.managedBy,
            samplesCount: state.samplesCount,
            latestSamples: state.latestSamples,
            plan: state.plan,
            planning: planningRecords,
            attempts: state.attempts,
            summary: state.summary
        )
        saveState()

        let usage = Self.summarizeUsage(samples: allSamples, nowMs: nowMs)
        let systemPrompt = "You schedule minimal wake-up requests for two Codex Plus accounts. Requests NEVER reset quotas; they MAY start an idle five-hour window. Optimize readiness for observed user demand, minimize idle windows and unnecessary requests, consider weekly budget and stagger accounts only when supported by data. Timezone Asia/Shanghai. Return JSON ONLY: {\"date\":\"YYYY-MM-DD\",\"accounts\":[{\"account\":\"auth_index\",\"times\":[\"07:00\",\"12:00\",\"17:00\"],\"reason\":\"中文理由\"}]}. Exactly one entry per supplied account. Zero to three times per account, sorted, >=4 hours apart, only :00 or :30. If historyHours<24, retain the baseline 07:00,12:00,17:00 and explain insufficient data. Empty times is allowed when no wake-up is useful. Missing samples are unknown, not zero usage. Cross-reset intervals are lower bounds. Do not propose shell commands. Only plan the supplied date; past times will be ignored. Current active windows are skipped by executor."

        let userPayload: [String: Any] = [
            "date": date,
            "now": ISO8601DateFormatter().string(from: now),
            "accounts": accounts,
            "usage": usage
        ]

        guard let payloadData = try? JSONSerialization.data(withJSONObject: userPayload),
              let payloadStr = String(data: payloadData, encoding: .utf8) else {
            return
        }

        do {
            let requestBody: [String: Any] = [
                "model": "gpt-6.1-sol",
                "reasoning_effort": "low",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": payloadStr]
                ],
                "stream": false,
                "max_tokens": 2200
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

            let (responseData, statusCode) = try await client.request(
                path: "/v1/chat/completions",
                method: "POST",
                timeout: 60,
                headers: ["Content-Type": "application/json"],
                body: bodyData
            )

            guard statusCode == 200,
                  let resObj = JSONValue.object(from: responseData),
                  let choices = resObj["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw URLError(.badServerResponse)
            }

            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "^```(?:json)?\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*```$", with: "", options: .regularExpression)

            guard let jsonData = cleaned.data(using: .utf8),
                  let rawPlanObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw URLError(.cannotParseResponse)
            }

            let validated = try validatePlan(raw: rawPlanObj, date: date, accountIDs: accounts)
            var currentPlanning = state.planning
            if let lastIndex = currentPlanning.indices.last {
                currentPlanning[lastIndex] = SchedulerPlanningRecord(time: nowMs, date: date, status: "completed")
            }

            state = CodexSchedulerStatus(
                time: state.time,
                event: state.event,
                managedBy: state.managedBy,
                samplesCount: state.samplesCount,
                latestSamples: state.latestSamples,
                plan: validated,
                planning: currentPlanning,
                attempts: state.attempts,
                summary: state.summary
            )
            saveState()
        } catch {
            var currentPlanning = state.planning
            if let lastIndex = currentPlanning.indices.last {
                currentPlanning[lastIndex] = SchedulerPlanningRecord(
                    time: nowMs,
                    date: date,
                    status: "failed",
                    error: error.localizedDescription
                )
            }
            state = CodexSchedulerStatus(
                time: state.time,
                event: state.event,
                managedBy: state.managedBy,
                samplesCount: state.samplesCount,
                latestSamples: state.latestSamples,
                plan: state.plan,
                planning: currentPlanning,
                attempts: state.attempts,
                summary: state.summary
            )
            saveState()
        }
    }

    func validatePlan(raw: [String: Any], date: String, accountIDs: [String]) throws -> SchedulerPlan {
        guard let pDate = raw["date"] as? String, pDate == date else {
            throw NSError(domain: "CodexScheduler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid plan date"])
        }
        guard let rawAccounts = raw["accounts"] as? [[String: Any]], rawAccounts.count == accountIDs.count else {
            throw NSError(domain: "CodexScheduler", code: 2, userInfo: [NSLocalizedDescriptionKey: "Account count mismatch"])
        }

        var seen = Set<String>()
        var parsedAccounts = [SchedulerAccountPlan]()

        for a in rawAccounts {
            guard let account = a["account"] as? String,
                  accountIDs.contains(account),
                  !seen.contains(account),
                  let times = a["times"] as? [String],
                  times.count <= 3,
                  let reason = a["reason"] as? String,
                  reason.count <= 1500 else {
                throw NSError(domain: "CodexScheduler", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid account plan"])
            }
            seen.insert(account)

            var prevTime: Date = .distantPast
            let timeRegex = try NSRegularExpression(pattern: "^(?:[01]\\d|2[0-3]):(?:00|30)$")
            for t in times {
                guard timeRegex.firstMatch(in: t, range: NSRange(location: 0, length: t.utf16.count)) != nil else {
                    throw NSError(domain: "CodexScheduler", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid plan time format: \(t)"])
                }
                guard let target = Self.parseDateAndTimeString(date: date, time: t) else {
                    throw NSError(domain: "CodexScheduler", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not parse target time"])
                }
                if target.timeIntervalSince(prevTime) < 4 * 3600 {
                    throw NSError(domain: "CodexScheduler", code: 6, userInfo: [NSLocalizedDescriptionKey: "Plan times must be sorted and >=4 hours apart"])
                }
                prevTime = target
            }

            parsedAccounts.append(SchedulerAccountPlan(account: account, times: times, reason: reason))
        }

        return SchedulerPlan(date: date, accounts: parsedAccounts, createdAt: Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - 到期唤醒执行

    private func executeDueWakeups(
        date: String,
        accounts: [AccountQuota],
        latestSamples: [String: SchedulerSample],
        client: ManagementClient,
        now: Date
    ) async {
        guard let plan = state.plan else { return }
        let effectivePlan = plan.date == date ? plan : SchedulerPlan(
            date: date,
            accounts: accounts.map { row in
                let auth = row.account.authIndex
                let fallbackTimes = plan.accounts.first { $0.account == auth }?.times ?? ["07:00", "12:00", "17:00"]
                return SchedulerAccountPlan(account: auth, times: fallbackTimes, reason: nil)
            }
        )

        let nowMs = now.timeIntervalSince1970 * 1000
        var attempts = state.attempts

        for row in accounts {
            let authIndex = row.account.authIndex
            guard let entry = effectivePlan.accounts.first(where: { $0.account == authIndex }) else { continue }

            for time in entry.times {
                guard let due = Self.parseDateAndTimeString(date: date, time: time) else { continue }
                let dueMs = due.timeIntervalSince1970 * 1000
                let key = "\(date)/\(authIndex)/\(time)"

                if nowMs < dueMs || (nowMs - dueMs) >= halfHourMs || attempts.contains(where: { $0.key == key }) {
                    continue
                }

                let sample = latestSamples[authIndex]
                let reason = decideActivation(sample: sample, account: authIndex, attempts: attempts, nowMs: nowMs, date: date)

                var attempt = SchedulerAttempt(
                    time: nowMs,
                    account: authIndex,
                    key: key,
                    status: reason != nil ? "skipped" : "started",
                    reason: reason,
                    resetBefore: sample?.quota?.primary?.reset
                )
                attempts.append(attempt)
                state = CodexSchedulerStatus(
                    time: state.time,
                    event: state.event,
                    managedBy: state.managedBy,
                    samplesCount: state.samplesCount,
                    latestSamples: state.latestSamples,
                    plan: state.plan,
                    planning: state.planning,
                    attempts: attempts,
                    summary: state.summary
                )
                saveState()

                if reason != nil {
                    continue
                }

                // 唤醒发送
                do {
                    try await sendMinimalWakeupRequest(account: row.account, client: client)
                    if let idx = attempts.indices.last {
                        attempt = SchedulerAttempt(
                            time: attempt.time,
                            account: attempt.account,
                            key: attempt.key,
                            status: "completed",
                            reason: nil,
                            resetBefore: attempt.resetBefore
                        )
                        attempts[idx] = attempt
                        saveState()
                    }
                } catch {
                    if let idx = attempts.indices.last {
                        attempt = SchedulerAttempt(
                            time: attempt.time,
                            account: attempt.account,
                            key: attempt.key,
                            status: "failed",
                            reason: nil,
                            resetBefore: attempt.resetBefore,
                            error: error.localizedDescription
                        )
                        attempts[idx] = attempt
                        saveState()
                    }
                }
            }
        }
    }

    func decideActivation(
        sample: SchedulerSample?,
        account: String,
        attempts: [SchedulerAttempt],
        nowMs: Double,
        date: String
    ) -> String? {
        guard let s = sample, let q = s.quota, let sTime = s.time, (nowMs - sTime) <= 10 * 60_000 else {
            return "quota-unavailable"
        }
        if q.allowed == false || (q.primary?.used ?? 0) >= 100 || (q.weekly?.used ?? 0) >= 100 {
            return "quota-exhausted"
        }
        if let primaryUsed = q.primary?.used, primaryUsed > 0, let reset = q.primary?.reset, reset > nowMs {
            return "window-already-active"
        }

        let todayActiveAttempts = attempts.filter { att in
            att.account == account && att.status != "skipped" && (att.key?.starts(with: date) == true)
        }
        if todayActiveAttempts.count >= 3 {
            return "daily-cap"
        }

        let fourHoursAgo = nowMs - 4 * 3_600_000
        if attempts.contains(where: { att in
            att.account == account && att.status != "skipped" && (att.time ?? 0) > fourHoursAgo
        }) {
            return "minimum-interval"
        }

        return nil
    }

    private func sendMinimalWakeupRequest(account: AuthAccount, client: ManagementClient) async throws {
        guard let accountID = account.accountID, !accountID.isEmpty else {
            throw NSError(domain: "CodexScheduler", code: 10, userInfo: [NSLocalizedDescriptionKey: "Missing Chatgpt-Account-Id"])
        }

        let payload: [String: Any] = [
            "model": "gpt-6.1-sol",
            "instructions": "Reply with OK only.",
            "input": [
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": "Reply OK."]
                    ]
                ]
            ],
            "stream": true,
            "store": false,
            "tools": [],
            "reasoning": ["effort": "low"]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let bodyString = String(data: bodyData, encoding: .utf8)

        let headers = [
            "Authorization": "Bearer $TOKEN$",
            "Chatgpt-Account-Id": accountID,
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "Originator": "codex-tui",
            "User-Agent": "codex-tui/0.154.0"
        ]

        let response = try await client.apiCall(
            authIndex: account.authIndex,
            method: "POST",
            url: "https://chatgpt.com/backend-api/codex/responses",
            headers: headers,
            body: bodyString
        )

        guard (200..<300).contains(response.statusCode) else {
            throw NSError(domain: "CodexScheduler", code: 11, userInfo: [NSLocalizedDescriptionKey: "Upstream HTTP \(response.statusCode)"])
        }

        let body = response.body
        let lines = body.components(separatedBy: "\n")
        let hasCompleted = lines.contains { line in
            line.contains("\"type\":\"response.completed\"") || line.contains("\"status\":\"completed\"")
        }
        guard hasCompleted else {
            throw NSError(domain: "CodexScheduler", code: 12, userInfo: [NSLocalizedDescriptionKey: "No completed model response in SSE output"])
        }
    }
}
