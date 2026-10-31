import Foundation

struct MagpieTarget: Sendable {
    let label: String
    let baseURL: String
    let key: String
    let candidatePaths: [String]
    let timeout: TimeInterval
}

struct MagpieQuotaConnection: QuotaConnection {
    let settings: AppSettings
    let transport: any HTTPDataClient

    func candidateTargets() -> [MagpieTarget] {
        var targets: [MagpieTarget] = []

        let customURL = settings.normalizedBaseURL
        let customKey = settings.normalizedManagementKey
        if !customURL.isEmpty && !customKey.isEmpty {
            var raw = customURL
            if !raw.contains("://") { raw = "http://" + raw }
            let is3430 = raw.contains(":3430")
            let paths = is3430 ? ["api/usage/quotas", "v1/magpie/quotas"] : ["v1/magpie/quotas", "api/usage/quotas"]
            targets.append(MagpieTarget(
                label: "自定义配置",
                baseURL: raw,
                key: customKey,
                candidatePaths: paths,
                timeout: 5.0
            ))
        }

        #if os(macOS)
        targets.append(MagpieTarget(
            label: "电脑本机 (127.0.0.1:3425)",
            baseURL: AppSettings.builtinDesktopLocalURL,
            key: AppSettings.builtinDesktopGatewayKey,
            candidatePaths: ["v1/magpie/quotas", "api/usage/quotas"],
            timeout: 2.5
        ))
        #endif

        targets.append(MagpieTarget(
            label: "电脑局域网 (192.168.1.158:3425)",
            baseURL: AppSettings.builtinDesktopMacURL,
            key: AppSettings.builtinDesktopGatewayKey,
            candidatePaths: ["v1/magpie/quotas", "api/usage/quotas"],
            timeout: 3.0
        ))

        targets.append(MagpieTarget(
            label: "软路由网关 (192.168.1.3:3425)",
            baseURL: AppSettings.builtinRouterGatewayURL,
            key: AppSettings.builtinRouterGatewayKey,
            candidatePaths: ["v1/magpie/quotas", "api/usage/quotas"],
            timeout: 5.0
        ))

        targets.append(MagpieTarget(
            label: "软路由网页 (192.168.1.3:3430)",
            baseURL: AppSettings.builtinRouterWebURL,
            key: AppSettings.builtinRouterWebKey,
            candidatePaths: ["api/usage/quotas", "v1/magpie/quotas"],
            timeout: 5.0
        ))

        var seen = Set<String>()
        return targets.filter { target in
            var raw = target.baseURL
            if !raw.contains("://") { raw = "http://" + raw }
            let normalized = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return seen.insert("\(normalized)|\(target.key)").inserted
        }
    }

    func refresh(force: Bool) async throws -> QuotaRefreshResult {
        guard settings.isConfigured else { throw ManagementClientError.notConfigured }

        let targets = candidateTargets()
        guard !targets.isEmpty else { throw ManagementClientError.invalidBaseURL }

        var lastError: Error?
        for target in targets {
            var raw = target.baseURL
            if !raw.contains("://") { raw = "http://" + raw }
            guard let components = URLComponents(string: raw),
                  let host = components.host, !host.isEmpty,
                  let scheme = components.scheme, ["http", "https"].contains(scheme),
                  components.user == nil, components.password == nil else {
                continue
            }
            let port = components.port ?? (scheme == "https" ? 443 : 80)
            let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            var cleanKey = target.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanKey.lowercased().hasPrefix("bearer ") {
                cleanKey = String(cleanKey.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            for path in target.candidatePaths {
                var reqComponents = components
                let fullPath = trimmedPath.isEmpty ? path : "\(trimmedPath)/\(path)"
                reqComponents.path = "/" + fullPath
                reqComponents.query = force ? "asked=1" : nil
                reqComponents.fragment = nil
                guard let url = reqComponents.url else { continue }

                var request = URLRequest(url: url)
                request.timeoutInterval = target.timeout
                if !cleanKey.isEmpty {
                    request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
                    request.setValue(cleanKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("magpie_web_session=\(cleanKey); magpie_web_\(port)=\(cleanKey)", forHTTPHeaderField: "Cookie")
                }
                request.setValue("AccessDeck/0.1", forHTTPHeaderField: "User-Agent")

                do {
                    let (data, response) = try await transport.data(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        lastError = ManagementClientError.invalidResponse
                        continue
                    }

                    // If 404 and there's another candidate endpoint path for this target, try next path
                    if http.statusCode == 404 && path != target.candidatePaths.last {
                        continue
                    }

                    guard (200..<300).contains(http.statusCode) else {
                        let bodyText = String(data: data, encoding: .utf8) ?? ""
                        lastError = ManagementClientError.httpStatus(http.statusCode, bodyText)
                        break
                    }

                    let quotas: [MagpieQuota]
                    if let direct = try? JSONDecoder().decode([MagpieQuota].self, from: data) {
                        quotas = direct
                    } else if let envelope = try? JSONDecoder().decode(MagpieQuotaEnvelope.self, from: data) {
                        quotas = envelope.data
                    } else {
                        lastError = ManagementClientError.invalidResponse
                        break
                    }

                    return QuotaRefreshResult(accounts: quotas.enumerated().map { index, quota in
                        quota.accountQuota(index: index)
                    })
                } catch {
                    lastError = error
                    break
                }
            }
        }

        if let lastError {
            throw lastError
        }
        throw ManagementClientError.invalidResponse
    }
}

private struct MagpieQuotaEnvelope: Decodable {
    let data: [MagpieQuota]
}

private struct MagpieQuota: Decodable {
    struct Window: Decodable {
        let name: String
        let used: Double?
        let remaining: Double?
        let resetsAt: String?
        let text: Bool?
        let display: String?
        let limit: Double?
        let amount: Double?
        let unit: String?

        enum CodingKeys: String, CodingKey {
            case name, used, remaining, resetsAt, text, display, limit, amount, unit
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            used = try? c.decodeIfPresent(Double.self, forKey: .used)
            remaining = try? c.decodeIfPresent(Double.self, forKey: .remaining)
            resetsAt = try? c.decodeIfPresent(String.self, forKey: .resetsAt)
            text = try? c.decodeIfPresent(Bool.self, forKey: .text)
            display = try? c.decodeIfPresent(String.self, forKey: .display)
            unit = try? c.decodeIfPresent(String.self, forKey: .unit)

            if let d = try? c.decodeIfPresent(Double.self, forKey: .limit) {
                limit = d
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .limit) {
                limit = Double(s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                limit = nil
            }

            if let d = try? c.decodeIfPresent(Double.self, forKey: .amount) {
                amount = d
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .amount) {
                amount = Double(s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                amount = nil
            }
        }
    }
    struct Resets: Decodable {
        let count: Int?
        let until: String?
    }
    let provider: String
    let name: String
    let user: String?
    let alias: String?
    let plan: String?
    let windows: [Window]?
    let error: String?
    let resets: Resets?

    private static func formatCompactNumber(_ num: Double) -> String {
        if num == 0 { return "0" }
        let absNum = abs(num)
        if absNum >= 1_000_000_000 {
            let val = num / 1_000_000_000.0
            return val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))B" : String(format: "%.1fB", val)
        }
        if absNum >= 1_000_000 {
            let val = num / 1_000_000.0
            return val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))M" : String(format: "%.1fM", val)
        }
        if absNum >= 10_000 {
            let val = num / 1_000.0
            return val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))K" : String(format: "%.1fK", val)
        }
        if num.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(num))"
        }
        return String(format: "%.1f", num)
    }

    private static func parseCompactNumber(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasSuffix("B") {
            let sub = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(sub).map { $0 * 1_000_000_000 }
        }
        if trimmed.hasSuffix("M") {
            let sub = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(sub).map { $0 * 1_000_000 }
        }
        if trimmed.hasSuffix("K") {
            let sub = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(sub).map { $0 * 1_000 }
        }
        let cleaned = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private static func resolveRemainingDisplay(window: Window) -> String? {
        if let limit = window.limit, limit > 0 {
            let usedAmount: Double
            if let amount = window.amount {
                usedAmount = max(0, amount)
            } else if let used = window.used {
                usedAmount = max(0, limit * (used / 100.0))
            } else if let remaining = window.remaining {
                usedAmount = max(0, limit * ((100.0 - remaining) / 100.0))
            } else {
                usedAmount = 0
            }
            let remainingAmount = max(0, limit - usedAmount)
            let leftStr = formatCompactNumber(remainingAmount)
            let rightStr = formatCompactNumber(limit)
            return "\(leftStr) / \(rightStr)"
        }

        if let rawDisplay = window.display?.trimmingCharacters(in: .whitespacesAndNewlines), rawDisplay.contains("/") {
            let parts = rawDisplay.components(separatedBy: "/")
            if parts.count == 2,
               let usedVal = parseCompactNumber(parts[0]),
               let totalVal = parseCompactNumber(parts[1]),
               totalVal > 0 {
                let remainingVal = max(0, totalVal - usedVal)
                let leftStr = formatCompactNumber(remainingVal)
                let rightStr = formatCompactNumber(totalVal)
                return "\(leftStr) / \(rightStr)"
            }
        }

        return window.display
    }

    func accountQuota(index: Int) -> AccountQuota {
        let identity = user.flatMap { $0.isEmpty ? nil : $0 } ?? alias.flatMap { $0.isEmpty ? nil : $0 } ?? "\(name)-\(index)"
        let id = "magpie:\(provider):\(identity)"
        let parsedProvider = QuotaProvider.parse(provider)
        let account = AuthAccount(id: id, authIndex: id, name: alias ?? name, email: user, provider: parsedProvider, providerRaw: provider, status: error == nil ? "active" : "error", statusMessage: error, disabled: false, unavailable: false, accountID: nil, projectID: nil, fileName: nil)
        var seen = Set<String>()
        let mapped = (windows ?? []).enumerated().map { index, window in
            let canonical: String
            let lowerName = window.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerDisplay = (window.display ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let combined = lowerName + " " + lowerDisplay

            if parsedProvider == .antigravity {
                if combined.contains("high") || (combined.contains("argon") && !combined.contains("low")) {
                    canonical = "argon"
                } else if combined.contains("low") || combined.contains("gemini") {
                    canonical = "gemini"
                } else if index == 0 {
                    canonical = "argon"
                } else {
                    canonical = "gemini"
                }
            } else {
                switch lowerName {
                case "5 hours", "5h", "5 hour":
                    canonical = "5h"
                case "7 days", "7d", "7 day", "weekly", "week":
                    canonical = "7d"
                case "credits", "credit", "积分":
                    canonical = "credits"
                case "free model tokens", "free tokens", "tokens":
                    canonical = "free_tokens"
                default:
                    canonical = window.name
                }
            }
            let id = seen.insert(canonical).inserted ? canonical : "\(canonical):\(index)"
            let remainingDisplay = Self.resolveRemainingDisplay(window: window)
            let label: String
            if parsedProvider == .antigravity {
                label = canonical == "argon" ? "Argon" : "Gemini"
            } else if canonical == "5h" || canonical == "7d" {
                label = canonical
            } else if canonical == "credits" {
                let base = L10n.t("积分", "Credits")
                if let display = remainingDisplay, !display.isEmpty {
                    label = "\(base) (\(display))"
                } else {
                    label = base
                }
            } else if canonical == "free_tokens" {
                let base = L10n.t("免费 Token", "Free Tokens")
                if let display = remainingDisplay, !display.isEmpty {
                    label = "\(base) (\(display))"
                } else {
                    label = base
                }
            } else if let display = remainingDisplay, !display.isEmpty {
                label = "\(window.name) (\(display))"
            } else {
                label = window.name
            }
            let remPct: Double?
            if window.text == true {
                remPct = nil
            } else if let rem = window.remaining {
                remPct = min(100, max(0, rem))
            } else if let used = window.used {
                remPct = min(100, max(0, 100 - used))
            } else {
                remPct = nil
            }
            return QuotaWindow(id: id, label: label, remainingPercent: remPct, resetText: QuotaParser.formatReset(window.resetsAt))
        }
        let date = resets?.until.flatMap { ISO8601DateFormatter().date(from: $0) }
        return AccountQuota(account: account, snapshot: QuotaSnapshot(planType: plan, windows: mapped, error: error, resetCreditCount: resets?.count, resetCreditExpiresAt: date))
    }
}
