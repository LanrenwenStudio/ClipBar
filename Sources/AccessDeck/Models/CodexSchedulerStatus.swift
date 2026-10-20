import Foundation

struct CodexSchedulerStatus: Codable, Sendable {
    let time: String?
    let event: String?
    let managedBy: String?
    let samplesCount: Int?
    let latestSamples: [SchedulerSample]
    let plan: SchedulerPlan?
    let planning: [SchedulerPlanningRecord]
    let attempts: [SchedulerAttempt]
    let summary: SchedulerSummary?

    enum CodingKeys: String, CodingKey {
        case time
        case event
        case managedBy
        case samplesCount
        case latestSamples
        case samples
        case plan
        case planning
        case attempts
        case summary
    }

    init(
        time: String? = nil,
        event: String? = nil,
        managedBy: String? = "AccessDeck",
        samplesCount: Int? = 0,
        latestSamples: [SchedulerSample] = [],
        plan: SchedulerPlan? = nil,
        planning: [SchedulerPlanningRecord] = [],
        attempts: [SchedulerAttempt] = [],
        summary: SchedulerSummary? = nil
    ) {
        self.time = time
        self.event = event
        self.managedBy = managedBy
        self.samplesCount = samplesCount
        self.latestSamples = latestSamples
        self.plan = plan
        self.planning = planning
        self.attempts = attempts
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.time = try container.decodeIfPresent(String.self, forKey: .time)
        self.event = try container.decodeIfPresent(String.self, forKey: .event)
        self.managedBy = try container.decodeIfPresent(String.self, forKey: .managedBy)
        self.plan = try container.decodeIfPresent(SchedulerPlan.self, forKey: .plan)
        self.planning = try container.decodeIfPresent([SchedulerPlanningRecord].self, forKey: .planning) ?? []
        self.attempts = try container.decodeIfPresent([SchedulerAttempt].self, forKey: .attempts) ?? []
        self.summary = try container.decodeIfPresent(SchedulerSummary.self, forKey: .summary)

        if let explicitLatest = try container.decodeIfPresent([SchedulerSample].self, forKey: .latestSamples) {
            self.latestSamples = explicitLatest
            self.samplesCount = try container.decodeIfPresent(Int.self, forKey: .samplesCount) ?? explicitLatest.count
        } else if let allSamples = try container.decodeIfPresent([SchedulerSample].self, forKey: .samples) {
            var lastMap: [String: SchedulerSample] = [:]
            for s in allSamples {
                lastMap[s.account] = s
            }
            self.latestSamples = Array(lastMap.values).sorted { $0.account < $1.account }
            self.samplesCount = allSamples.count
        } else {
            self.latestSamples = []
            self.samplesCount = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(time, forKey: .time)
        try container.encodeIfPresent(event, forKey: .event)
        try container.encodeIfPresent(managedBy, forKey: .managedBy)
        try container.encodeIfPresent(samplesCount, forKey: .samplesCount)
        try container.encode(latestSamples, forKey: .latestSamples)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encode(planning, forKey: .planning)
        try container.encode(attempts, forKey: .attempts)
        try container.encodeIfPresent(summary, forKey: .summary)
    }

    /// 最新采样的毫秒时间戳
    var latestSampleTimestamp: Double? {
        latestSamples.compactMap(\.time).max()
    }

    /// 采样是否已滞后超过 45 分钟
    var isStale: Bool {
        guard let ts = latestSampleTimestamp else { return true }
        let ageMs = Date().timeIntervalSince1970 * 1000 - ts
        return ageMs > 45 * 60 * 1000
    }

    /// 格式化的最后采样相对时间
    var formattedLatestSampleTime: String {
        guard let ts = latestSampleTimestamp else { return L10n.t("暂无采样", "No samples") }
        let date = Date(timeIntervalSince1970: ts / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 当前计划是否为今日新生成
    var isPlanFromToday: Bool {
        guard let planDate = plan?.date else { return false }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return planDate == today
    }
}

struct SchedulerSample: Codable, Sendable, Identifiable {
    var id: String { "\(account)-\(time ?? 0)" }
    let time: Double?
    let account: String
    let quota: SchedulerQuota?
    let error: String?

    init(time: Double?, account: String, quota: SchedulerQuota?, error: String? = nil) {
        self.time = time
        self.account = account
        self.quota = quota
        self.error = error
    }

    var shortAccountID: String {
        account.count > 6 ? String(account.suffix(6)) : account
    }

    var formattedTime: String {
        guard let time else { return "--" }
        let date = Date(timeIntervalSince1970: time / 1000.0)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

struct SchedulerQuota: Codable, Sendable {
    let allowed: Bool?
    let primary: SchedulerQuotaWindow?
    let weekly: SchedulerQuotaWindow?

    init(allowed: Bool?, primary: SchedulerQuotaWindow?, weekly: SchedulerQuotaWindow?) {
        self.allowed = allowed
        self.primary = primary
        self.weekly = weekly
    }
}

struct SchedulerQuotaWindow: Codable, Sendable {
    let used: Double?
    let reset: Double?
    let seconds: Int?

    init(used: Double?, reset: Double?, seconds: Int?) {
        self.used = used
        self.reset = reset
        self.seconds = seconds
    }

    var formattedResetTime: String {
        guard let reset else { return "--" }
        let date = Date(timeIntervalSince1970: reset / 1000.0)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

struct SchedulerPlan: Codable, Sendable {
    let date: String
    let accounts: [SchedulerAccountPlan]
    let createdAt: Double?

    init(date: String, accounts: [SchedulerAccountPlan], createdAt: Double? = nil) {
        self.date = date
        self.accounts = accounts
        self.createdAt = createdAt
    }

    var formattedCreatedAt: String {
        guard let createdAt else { return "--" }
        let date = Date(timeIntervalSince1970: createdAt / 1000.0)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct SchedulerAccountPlan: Codable, Sendable, Identifiable {
    var id: String { account }
    let account: String
    let times: [String]
    let reason: String?

    init(account: String, times: [String], reason: String?) {
        self.account = account
        self.times = times
        self.reason = reason
    }

    var shortAccountID: String {
        account.count > 6 ? String(account.suffix(6)) : account
    }

    var timesSummary: String {
        times.isEmpty ? L10n.t("不安排唤醒", "No wake-ups scheduled") : times.joined(separator: "、")
    }
}

struct SchedulerPlanningRecord: Codable, Sendable, Identifiable {
    var id: String { "\(date)-\(time ?? 0)" }
    let time: Double?
    let date: String
    let status: String
    let error: String?

    init(time: Double?, date: String, status: String, error: String? = nil) {
        self.time = time
        self.date = date
        self.status = status
        self.error = error
    }

    var localizedStatus: String {
        switch status {
        case "completed": return L10n.t("规划成功", "Completed")
        case "failed": return L10n.t("规划失败（沿用旧计划或基线）", "Failed (fallback in use)")
        case "started": return L10n.t("规划进行中", "Started")
        default: return status
        }
    }
}

struct SchedulerAttempt: Codable, Sendable, Identifiable {
    var id: String { key ?? "\(account)-\(time ?? 0)" }
    let time: Double?
    let account: String
    let key: String?
    let status: String
    let reason: String?
    let resetBefore: Double?
    let error: String?

    init(
        time: Double?,
        account: String,
        key: String?,
        status: String,
        reason: String? = nil,
        resetBefore: Double? = nil,
        error: String? = nil
    ) {
        self.time = time
        self.account = account
        self.key = key
        self.status = status
        self.reason = reason
        self.resetBefore = resetBefore
        self.error = error
    }

    var shortAccountID: String {
        account.count > 6 ? String(account.suffix(6)) : account
    }

    var formattedTime: String {
        guard let time else { return "--" }
        let date = Date(timeIntervalSince1970: time / 1000.0)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    var localizedStatus: String {
        switch status {
        case "skipped": return L10n.t("跳过", "Skipped")
        case "completed": return L10n.t("调用成功", "Completed")
        case "failed": return L10n.t("调用失败", "Failed")
        case "started": return L10n.t("进行中", "Started")
        default: return status
        }
    }

    var localizedReason: String {
        guard let reason else { return "" }
        switch reason {
        case "quota-unavailable": return L10n.t("额度查询失败或数据过期", "Quota unavailable / stale")
        case "quota-exhausted": return L10n.t("五小时或周额度耗尽", "Quota exhausted")
        case "window-already-active": return L10n.t("已有活跃窗口，无需唤醒", "Active window already present")
        case "daily-cap": return L10n.t("已达每日调用上限（3次）", "Daily attempt cap reached")
        case "minimum-interval": return L10n.t("距上次调用不足四小时", "Minimum interval not met (<4h)")
        default: return reason
        }
    }
}

struct SchedulerSummary: Codable, Sendable {
    let timezone: String?
    let validSamples: Int?
    let historyHours: Double?

    init(timezone: String?, validSamples: Int?, historyHours: Double?) {
        self.timezone = timezone
        self.validSamples = validSamples
        self.historyHours = historyHours
    }
}
