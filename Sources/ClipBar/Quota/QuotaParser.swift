import Foundation

enum QuotaParser {
    static func parseCodex(_ object: [String: Any]) -> QuotaSnapshot {
        let plan = JSONValue.firstString(object, paths: ["plan_type", "planType", "account_plan.plan_type"])
        let primary = window(
            id: "5h",
            label: "5h",
            object: object,
            prefix: "rate_limit.primary_window"
        )
        let secondary = window(
            id: "7d",
            label: "7d",
            object: object,
            prefix: "rate_limit.secondary_window"
        )

        var windows: [QuotaWindow] = []
        if let primary {
            windows.append(classifyCodexWindow(primary))
        }
        if let secondary {
            windows.append(classifyCodexWindow(secondary))
        }

        return QuotaSnapshot(planType: plan, windows: windows, error: windows.isEmpty ? "empty quota payload" : nil)
    }

    static func parseClaude(_ object: [String: Any]) -> QuotaSnapshot {
        let fiveHour = utilizationWindow(
            id: "5h",
            label: "5h",
            used: JSONValue.firstDouble(object, paths: [
                "five_hour.utilization",
                "five_hour.used_percentage",
                "rate_limits.five_hour.used_percentage"
            ]),
            resetsAt: JSONValue.firstString(object, paths: [
                "five_hour.resets_at",
                "rate_limits.five_hour.resets_at"
            ])
        )
        let sevenDay = utilizationWindow(
            id: "7d",
            label: "7d",
            used: JSONValue.firstDouble(object, paths: [
                "seven_day.utilization",
                "seven_day.used_percentage",
                "rate_limits.seven_day.used_percentage"
            ]),
            resetsAt: JSONValue.firstString(object, paths: [
                "seven_day.resets_at",
                "rate_limits.seven_day.resets_at"
            ])
        )

        let windows = [fiveHour, sevenDay].compactMap { $0 }
        return QuotaSnapshot(
            planType: "claude",
            windows: windows,
            error: windows.isEmpty ? "empty quota payload" : nil
        )
    }

    static func parseGemini(_ object: [String: Any]) -> QuotaSnapshot {
        guard let buckets = object["buckets"] as? [[String: Any]] else {
            return QuotaSnapshot(planType: nil, windows: [], error: "empty quota payload")
        }

        var windows: [QuotaWindow] = []
        for bucket in buckets {
            let modelID = JSONValue.firstString(bucket, paths: ["modelId", "model_id"]) ?? "model"
            let remaining = remainingPercent(from: bucket)
            let reset = formatReset(JSONValue.firstString(bucket, paths: ["resetTime", "reset_time"]))
            windows.append(
                QuotaWindow(
                    id: modelID,
                    label: shortModelName(modelID),
                    remainingPercent: remaining,
                    resetText: reset
                )
            )
        }
        return QuotaSnapshot(planType: nil, windows: collapseWindows(windows), error: windows.isEmpty ? "empty quota payload" : nil)
    }

    static func parseAntigravity(_ object: [String: Any]) -> QuotaSnapshot {
        var windows: [QuotaWindow] = []
        if let fiveHour = antigravityFiveHourWindow(from: object) {
            windows.append(fiveHour)
        }
        if let weekly = antigravityWeeklyWindow(from: object) {
            windows.append(weekly)
        }
        return QuotaSnapshot(
            planType: parseGoogleAssistTier(object),
            windows: windows,
            error: windows.isEmpty ? "empty quota payload" : nil
        )
    }

    static func antigravityFiveHourWindow(from object: [String: Any]) -> QuotaWindow? {
        if let groups = object["groups"] as? [[String: Any]] {
            return antigravityGroupedWindow(
                groups: groups,
                id: "5h",
                label: "5h",
                matches: isFiveHourWindow
            )
        }

        let models: [String: [String: Any]]
        if let nested = object["models"] as? [String: [String: Any]] {
            models = nested
        } else if let nested = object["models"] as? [String: Any] {
            models = nested.compactMapValues { $0 as? [String: Any] }
        } else {
            return nil
        }

        var remainings: [Double] = []
        var reset: String?
        for (_, entry) in models {
            let quota = (entry["quotaInfo"] as? [String: Any]) ?? (entry["quota_info"] as? [String: Any]) ?? [:]
            if let remaining = remainingPercent(from: quota) {
                remainings.append(remaining)
            }
            if reset == nil {
                reset = formatReset(JSONValue.firstString(quota, paths: ["resetTime", "reset_time"]))
            }
        }
        guard !remainings.isEmpty else { return nil }
        return QuotaWindow(
            id: "5h",
            label: "5h",
            remainingPercent: remainings.reduce(0, +) / Double(remainings.count),
            resetText: reset
        )
    }

    static func antigravityWeeklyWindow(from object: [String: Any]) -> QuotaWindow? {
        guard let groups = object["groups"] as? [[String: Any]] else { return nil }
        return antigravityGroupedWindow(
            groups: groups,
            id: "7d",
            label: L10n.t("周额度", "Week"),
            matches: isWeeklyWindow
        )
    }

    private static func antigravityGroupedWindow(
        groups: [[String: Any]],
        id: String,
        label: String,
        matches: (String?) -> Bool
    ) -> QuotaWindow? {
        var remainings: [Double] = []
        var reset: String?
        for group in groups {
            let buckets = (group["buckets"] as? [[String: Any]]) ?? []
            for bucket in buckets {
                guard matches(JSONValue.firstString(bucket, paths: ["window"])) else { continue }
                if let remaining = remainingPercent(from: bucket) {
                    remainings.append(remaining)
                }
                if reset == nil {
                    reset = formatReset(JSONValue.firstString(bucket, paths: ["resetTime", "reset_time"]))
                }
            }
        }
        guard !remainings.isEmpty else { return nil }
        return QuotaWindow(
            id: id,
            label: label,
            remainingPercent: remainings.reduce(0, +) / Double(remainings.count),
            resetText: reset
        )
    }

    private static func isFiveHourWindow(_ raw: String?) -> Bool {
        let value = normalizedWindowName(raw)
        return value == "5h" || value == "five-hour" || value == "fivehour" || value.contains("5-hour")
    }

    private static func isWeeklyWindow(_ raw: String?) -> Bool {
        let value = normalizedWindowName(raw)
        return value == "7d"
            || value == "7-day"
            || value == "7day"
            || value == "seven-day"
            || value == "sevenday"
            || value == "weekly"
            || value == "week"
            || value.contains("7-day")
            || value.contains("seven-day")
            || value.contains("weekly")
    }

    private static func normalizedWindowName(_ raw: String?) -> String {
        (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    static func parseXai(_ object: [String: Any]) -> QuotaSnapshot {
        let config = (object["config"] as? [String: Any]) ?? object
        var windows: [QuotaWindow] = []

        let period = (config["currentPeriod"] as? [String: Any])
            ?? (config["current_period"] as? [String: Any])
            ?? [:]
        let weeklyUsed = JSONValue.firstDouble(config, paths: ["creditUsagePercent", "credit_usage_percent"])
        let weeklyEnd = JSONValue.firstString(period, paths: ["end"])
            ?? JSONValue.firstString(config, paths: ["periodEnd", "period_end"])
        if let weeklyUsed {
            windows.append(
                QuotaWindow(
                    id: "week",
                    label: L10n.t("周额度", "Week"),
                    remainingPercent: JSONValue.clampPercent(100 - weeklyUsed),
                    resetText: formatReset(weeklyEnd)
                )
            )
        }

        let products = (config["productUsage"] as? [[String: Any]])
            ?? (config["product_usage"] as? [[String: Any]])
            ?? []
        for product in products {
            let name = JSONValue.firstString(product, paths: ["product"]) ?? "Grok"
            guard let used = JSONValue.firstDouble(product, paths: ["usagePercent", "usage_percent"]) else {
                continue
            }
            windows.append(
                QuotaWindow(
                    id: "product-\(name)",
                    label: name,
                    remainingPercent: JSONValue.clampPercent(100 - used),
                    resetText: nil
                )
            )
        }

        let monthlyLimit = xaiCents(config, paths: ["monthlyLimit", "monthly_limit"])
        let usedCents = xaiCents(config, paths: ["used"])
        let monthlyEnd = JSONValue.firstString(config, paths: ["billingPeriodEnd", "billing_period_end"])
        if let monthlyLimit, monthlyLimit > 0, let usedCents {
            let included = min(usedCents, monthlyLimit)
            windows.append(
                QuotaWindow(
                    id: "month",
                    label: L10n.t("月额度", "Month"),
                    remainingPercent: JSONValue.clampPercent(100 - (included / monthlyLimit * 100)),
                    resetText: formatReset(monthlyEnd)
                )
            )
        }

        return QuotaSnapshot(
            planType: xaiPlan(from: config),
            windows: windows,
            error: windows.isEmpty ? "empty quota payload" : nil
        )
    }

    static func parseKimi(_ object: [String: Any]) -> QuotaSnapshot {
        let (usageDetail, limits) = kimiUsageDetails(from: object)
        var windows: [QuotaWindow] = []

        if let usageDetail,
           let weekly = kimiWindow(id: "7d", label: "7d", detail: usageDetail) {
            windows.append(weekly)
        }

        for limit in limits {
            guard let window = limit["window"] as? [String: Any],
                  let detail = limit["detail"] as? [String: Any],
                  let label = kimiWindowLabel(from: window),
                  let quotaWindow = kimiWindow(id: label, label: label, detail: detail)
            else {
                continue
            }

            if let existingIndex = windows.firstIndex(where: { $0.id == quotaWindow.id }) {
                let existing = windows[existingIndex]
                guard existing.remainingPercent != quotaWindow.remainingPercent
                    || existing.resetText != quotaWindow.resetText
                else {
                    continue
                }
                var distinctWindow = quotaWindow
                distinctWindow.id = "\(label)-\(existingIndex + 2)"
                windows.append(distinctWindow)
            } else {
                windows.append(quotaWindow)
            }
        }

        return QuotaSnapshot(
            planType: kimiPlan(from: object),
            windows: windows,
            error: windows.isEmpty ? "empty quota payload" : nil
        )
    }

    static func mergeXai(weekly: QuotaSnapshot, monthly: QuotaSnapshot) -> QuotaSnapshot {
        var byID: [String: QuotaWindow] = [:]
        for window in weekly.windows + monthly.windows where byID[window.id] == nil {
            byID[window.id] = window
        }
        let extras = byID.keys.filter { $0.hasPrefix("product-") }.sorted()
        let windows = (["week"] + extras + ["month"]).compactMap { byID[$0] }
        return QuotaSnapshot(
            planType: monthly.planType ?? weekly.planType,
            windows: windows,
            error: windows.isEmpty ? (weekly.error ?? monthly.error) : nil
        )
    }

    private static func kimiUsageDetails(from object: [String: Any]) -> (
        detail: [String: Any]?,
        limits: [[String: Any]]
    ) {
        let topLevelLimits = object["limits"] as? [[String: Any]] ?? []

        if let usage = object["usage"] as? [String: Any] {
            let detail = (usage["detail"] as? [String: Any]) ?? usage
            let limits = usage["limits"] as? [[String: Any]] ?? topLevelLimits
            return (detail, limits)
        }

        if let usages = object["usages"] as? [[String: Any]],
           let codingUsage = usages.first(where: {
               JSONValue.firstString($0, paths: ["scope"])?.uppercased() == "FEATURE_CODING"
           }) ?? usages.first {
            let detail = codingUsage["detail"] as? [String: Any]
            let limits = codingUsage["limits"] as? [[String: Any]] ?? topLevelLimits
            return (detail, limits)
        }

        if let detail = object["detail"] as? [String: Any] {
            return (detail, topLevelLimits)
        }
        if object["limit"] != nil {
            return (object, topLevelLimits)
        }
        return (nil, topLevelLimits)
    }

    private static func kimiWindow(
        id: String,
        label: String,
        detail: [String: Any]
    ) -> QuotaWindow? {
        guard let remainingPercent = kimiRemainingPercent(from: detail) else {
            return nil
        }
        return QuotaWindow(
            id: id,
            label: label,
            remainingPercent: remainingPercent,
            resetText: formatReset(JSONValue.firstString(detail, paths: [
                "resetTime",
                "reset_time",
                "resetAt",
                "reset_at"
            ]))
        )
    }

    private static func kimiRemainingPercent(from detail: [String: Any]) -> Double? {
        guard let limit = JSONValue.firstDouble(detail, paths: ["limit"]), limit > 0 else {
            return nil
        }
        if let remaining = JSONValue.firstDouble(detail, paths: ["remaining"]) {
            return JSONValue.clampPercent(remaining / limit * 100)
        }
        if let used = JSONValue.firstDouble(detail, paths: ["used"]) {
            return JSONValue.clampPercent(100 - used / limit * 100)
        }
        return nil
    }

    private static func kimiWindowLabel(from window: [String: Any]) -> String? {
        guard let duration = JSONValue.firstDouble(window, paths: ["duration"]), duration > 0,
              let rawUnit = JSONValue.firstString(window, paths: ["timeUnit", "time_unit"])
        else {
            return nil
        }

        let unit = rawUnit.uppercased()
        switch unit {
        case "TIME_UNIT_MINUTE", "MINUTE", "MINUTES":
            if duration.truncatingRemainder(dividingBy: 60) == 0 {
                return "\(Int(duration / 60))h"
            }
            return "\(Int(duration))m"
        case "TIME_UNIT_HOUR", "HOUR", "HOURS":
            return "\(Int(duration))h"
        case "TIME_UNIT_DAY", "DAY", "DAYS":
            return "\(Int(duration))d"
        case "TIME_UNIT_WEEK", "WEEK", "WEEKS":
            return "\(Int(duration))w"
        default:
            return nil
        }
    }

    private static func kimiPlan(from object: [String: Any]) -> String? {
        guard let raw = JSONValue.firstString(object, paths: [
            "user.membership.level",
            "user.membership.name",
            "membership.level",
            "membership.name",
            "plan_type",
            "planType",
            "plan",
            "subscription",
            "tier",
            "level"
        ]) else {
            return nil
        }

        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["LEVEL_", "PLAN_", "TIER_", "MEMBERSHIP_"] {
            if value.uppercased().hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
                break
            }
        }
        let formatted = value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .localizedCapitalized
        return formatted.isEmpty ? nil : formatted
    }

    static func parseGoogleAssistTier(_ object: [String: Any]) -> String? {
        formatMembership(
            JSONValue.firstString(object, paths: [
                "currentTier.name",
                "currentTier.id",
                "paidTier.name",
                "paidTier.id"
            ])
        )
    }

    static func formatMembership(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        switch normalized {
        case "plus": return "Plus"
        case "pro": return "Pro"
        case "prolite", "pro-lite": return "Pro Lite"
        case "ultra", "antigravity-ultra": return "Ultra"
        case "supergrok": return "SuperGrok"
        case "supergrok-heavy": return "SuperGrok Heavy"
        case "free", "free-tier", "legacy", "legacy-tier": return "Free"
        case "standard": return "Standard"
        default:
            return raw.replacingOccurrences(of: "_", with: " ").localizedCapitalized
        }
    }

    static func xaiPlan(from config: [String: Any]) -> String? {
        if let monthlyLimit = xaiCents(config, paths: ["monthlyLimit", "monthly_limit"]) {
            switch monthlyLimit {
            case 15_000: return "SuperGrok"
            case 150_000: return "SuperGrok Heavy"
            default: break
            }
        }
        return formatMembership(
            JSONValue.firstString(config, paths: ["planType", "plan_type", "plan", "subscription", "product"])
        )
    }

    static func jwtString(_ jwt: String, key: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2, let payload = decodeBase64URL(String(parts[1])) else {
            return nil
        }
        return JSONValue.firstString(payload, paths: [key])
    }

    static func chatgptAccountID(fromJWT jwt: String) -> String? {
        jwtString(jwt, key: "chatgpt_account_id")
            ?? jwtString(jwt, key: "https://api.openai.com/auth.chatgpt_account_id")
    }

    static func formatDuration(seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours >= 48 {
            return "\(hours / 24)d \(hours % 24)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func formatReset(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
            return formatDuration(seconds: date.timeIntervalSinceNow)
        }
        return raw
    }

    private static func window(id: String, label: String, object: [String: Any], prefix: String) -> QuotaWindow? {
        let used = JSONValue.firstDouble(object, paths: ["\(prefix).used_percent"])
        let resetSeconds = JSONValue.firstDouble(object, paths: ["\(prefix).reset_after_seconds"])
        let limitSeconds = JSONValue.firstDouble(object, paths: ["\(prefix).limit_window_seconds"])
        guard used != nil || resetSeconds != nil || limitSeconds != nil else {
            return nil
        }
        return QuotaWindow(
            id: id,
            label: (limitSeconds ?? 0) >= 86_400 ? "7d" : label,
            remainingPercent: used.map { JSONValue.clampPercent(100 - $0) },
            resetText: resetSeconds.map(formatDuration(seconds:))
        )
    }

    private static func classifyCodexWindow(_ window: QuotaWindow) -> QuotaWindow {
        window
    }

    private static func utilizationWindow(id: String, label: String, used: Double?, resetsAt: String?) -> QuotaWindow? {
        guard used != nil || resetsAt != nil else { return nil }
        return QuotaWindow(
            id: id,
            label: label,
            remainingPercent: used.map { JSONValue.clampPercent(100 - $0) },
            resetText: formatReset(resetsAt)
        )
    }

    private static func remainingPercent(from object: [String: Any]) -> Double? {
        if let fraction = JSONValue.firstDouble(object, paths: ["remainingFraction", "remaining_fraction"]) {
            return JSONValue.clampPercent(fraction <= 1.5 ? fraction * 100 : fraction)
        }
        if let remaining = JSONValue.firstDouble(object, paths: ["remaining"]) {
            return JSONValue.clampPercent(remaining <= 1.5 ? remaining * 100 : remaining)
        }
        if let amount = JSONValue.firstDouble(object, paths: ["remainingAmount", "remaining_amount"]), amount <= 0 {
            return 0
        }
        return nil
    }

    private static func collapseWindows(_ windows: [QuotaWindow]) -> [QuotaWindow] {
        guard windows.count > 6 else { return windows }
        return Array(windows.sorted { ($0.remainingPercent ?? 999) < ($1.remainingPercent ?? 999) }.prefix(6))
    }

    private static func shortModelName(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "gemini-", with: "")
            .replacingOccurrences(of: "-preview", with: "")
            .replacingOccurrences(of: "-thinking", with: "")
    }

    private static func xaiCents(_ object: [String: Any], paths: [String]) -> Double? {
        for path in paths {
            guard let value = JSONValue.value(object, path) else { continue }
            if let number = JSONValue.double(value) {
                return number
            }
            if let nested = value as? [String: Any], let number = JSONValue.double(nested["val"]) {
                return number
            }
        }
        return nil
    }

    private static func decodeBase64URL(_ value: String) -> [String: Any]? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return JSONValue.object(from: data)
    }
}
