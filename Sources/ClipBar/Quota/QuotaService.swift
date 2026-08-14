import Foundation

struct QuotaService: Sendable {
    var client: ManagementClient

    func refresh() async throws -> [AccountQuota] {
        let files = try await client.fetchAuthFiles()
        var accounts = files.map(Self.account(from:))
        accounts = try await enrichMissingIDs(accounts)

        return try await withThrowingTaskGroup(of: AccountQuota.self) { group in
            for account in accounts {
                group.addTask {
                    await self.loadQuota(for: account)
                }
            }
            var rows: [AccountQuota] = []
            for try await row in group {
                rows.append(row)
            }
            return rows.sorted {
                $0.sortKey.0 == $1.sortKey.0
                    ? ($0.sortKey.1 == $1.sortKey.1 ? $0.sortKey.2 < $1.sortKey.2 : $0.sortKey.1 < $1.sortKey.1)
                    : $0.sortKey.0 < $1.sortKey.0
            }
        }
    }

    private func loadQuota(for account: AuthAccount) async -> AccountQuota {
        do {
            let snapshot = try await fetchSnapshot(for: account)
            return AccountQuota(account: account, snapshot: snapshot)
        } catch {
            return AccountQuota(
                account: account,
                snapshot: QuotaSnapshot(planType: nil, windows: [], error: error.localizedDescription)
            )
        }
    }

    private func fetchSnapshot(for account: AuthAccount) async throws -> QuotaSnapshot {
        switch account.provider {
        case .codex:
            try await fetchCodex(account)
        case .claude:
            try await fetchClaude(account)
        case .geminiCLI:
            try await fetchGemini(account)
        case .antigravity:
            try await fetchAntigravity(account)
        case .xai:
            try await fetchXai(account)
        case .kimi, .unknown:
            QuotaSnapshot(
                planType: nil,
                windows: [],
                error: L10n.t("这个渠道暂不探测订阅额度，只显示账号状态。", "Live quota is not available for this provider yet.")
            )
        }
    }

    private func fetchCodex(_ account: AuthAccount) async throws -> QuotaSnapshot {
        guard let accountID = account.accountID, !accountID.isEmpty else {
            return QuotaSnapshot(planType: nil, windows: [], error: "missing chatgpt_account_id")
        }
        var headers = [
            "Authorization": "Bearer $TOKEN$",
            "Content-Type": "application/json",
            "User-Agent": "codex_cli_rs/0.76.0 (Debian 13.0.0; x86_64) WindowsTerminal"
        ]
        headers["Chatgpt-Account-Id"] = accountID
        let response = try await client.apiCall(
            authIndex: account.authIndex,
            method: "GET",
            url: "https://chatgpt.com/backend-api/wham/usage",
            headers: headers
        )
        return try decode(response, using: QuotaParser.parseCodex)
    }

    private func fetchClaude(_ account: AuthAccount) async throws -> QuotaSnapshot {
        let response = try await client.apiCall(
            authIndex: account.authIndex,
            method: "GET",
            url: "https://api.anthropic.com/api/oauth/usage",
            headers: [
                "Authorization": "Bearer $TOKEN$",
                "Content-Type": "application/json",
                "anthropic-beta": "oauth-2025-04-20"
            ]
        )
        return try decode(response, using: QuotaParser.parseClaude)
    }

    private func fetchGemini(_ account: AuthAccount) async throws -> QuotaSnapshot {
        let projectID = try await resolveGoogleProjectID(account, metadata: Self.geminiMetadata)
        let body = try jsonString(["project": projectID])
        let response = try await client.apiCall(
            authIndex: account.authIndex,
            method: "POST",
            url: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota",
            headers: Self.googleHeaders(Self.geminiMetadata),
            body: body
        )
        return try decode(response, using: QuotaParser.parseGemini)
    }

    private func fetchAntigravity(_ account: AuthAccount) async throws -> QuotaSnapshot {
        let projectID = try await resolveGoogleProjectID(account, metadata: Self.antigravityMetadata)
        let body = try jsonString(["project": projectID])
        let headers = [
            "Authorization": "Bearer $TOKEN$",
            "Content-Type": "application/json",
            "User-Agent": "antigravity/cli/1.0.13 (aidev_client; os_type=darwin; arch=arm64)"
        ]
        let endpoints = [
            "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
            "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
            "https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels",
            "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"
        ]
        var lastError = "retrieveUserQuotaSummary failed"
        for endpoint in endpoints {
            let response = try await client.apiCall(
                authIndex: account.authIndex,
                method: "POST",
                url: endpoint,
                headers: headers,
                body: body
            )
            if (200..<300).contains(response.statusCode),
               let object = JSONValue.object(from: response.body) {
                let snapshot = QuotaParser.parseAntigravity(object)
                if snapshot.hasLiveData {
                    return snapshot
                }
                lastError = snapshot.error ?? "empty 5h quota"
                continue
            }
            lastError = response.body.isEmpty ? "HTTP \(response.statusCode)" : response.body
        }
        return QuotaSnapshot(planType: nil, windows: [], error: lastError)
    }

    private func fetchXai(_ account: AuthAccount) async throws -> QuotaSnapshot {
        var headers = [
            "Authorization": "Bearer $TOKEN$",
            "x-xai-token-auth": "xai-grok-cli",
            "x-grok-client-version": "0.2.91",
            "accept": "*/*",
            "user-agent": "grok-pager/0.2.91 grok-shell/0.2.91 (macos; aarch64)"
        ]
        if let userID = account.accountID, !userID.isEmpty {
            headers["x-userid"] = userID
        }

        async let weeklyCall = client.apiCall(
            authIndex: account.authIndex,
            method: "GET",
            url: "https://cli-chat-proxy.grok.com/v1/billing?format=credits",
            headers: headers
        )
        async let monthlyCall = client.apiCall(
            authIndex: account.authIndex,
            method: "GET",
            url: "https://cli-chat-proxy.grok.com/v1/billing",
            headers: headers
        )
        let (weekly, monthly) = try await (weeklyCall, monthlyCall)
        let weeklySnapshot = snapshotIfOK(weekly, using: QuotaParser.parseXai)
        let monthlySnapshot = snapshotIfOK(monthly, using: QuotaParser.parseXai)
        var snapshot: QuotaSnapshot
        if let weeklySnapshot, let monthlySnapshot {
            snapshot = QuotaParser.mergeXai(weekly: weeklySnapshot, monthly: monthlySnapshot)
        } else if let weeklySnapshot {
            snapshot = weeklySnapshot
        } else if let monthlySnapshot {
            snapshot = monthlySnapshot
        } else {
            let failed = [weekly, monthly].first { !(200..<300).contains($0.statusCode) } ?? weekly
            throw ManagementClientError.httpStatus(failed.statusCode, failed.body)
        }
        if snapshot.planType == nil, let object = JSONValue.object(from: monthly.body) {
            snapshot.planType = QuotaParser.parseXai(object).planType
        }
        return snapshot
    }

    private func snapshotIfOK(
        _ response: APICallResponse,
        using parse: ([String: Any]) -> QuotaSnapshot
    ) -> QuotaSnapshot? {
        guard (200..<300).contains(response.statusCode),
              let object = JSONValue.object(from: response.body)
        else {
            return nil
        }
        let snapshot = parse(object)
        return snapshot.hasLiveData ? snapshot : nil
    }

    private func resolveGoogleProjectID(_ account: AuthAccount, metadata: [String: String]) async throws -> String {
        if let projectID = account.projectID, !projectID.isEmpty {
            return projectID
        }
        let body = try jsonString(["metadata": metadata])
        let response = try await client.apiCall(
            authIndex: account.authIndex,
            method: "POST",
            url: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist",
            headers: Self.googleHeaders(metadata),
            body: body
        )
        guard (200..<300).contains(response.statusCode),
              let object = JSONValue.object(from: response.body),
              let projectID = JSONValue.firstString(object, paths: ["cloudaicompanionProject", "cloudaicompanionProject.id"])
        else {
            throw ManagementClientError.invalidResponse
        }
        return projectID
    }

    private func loadGoogleAssistTier(authIndex: String, projectID: String) async -> String? {
        guard let body = try? jsonString([
            "metadata": Self.antigravityMetadata,
            "cloudaicompanionProject": projectID
        ]) else {
            return nil
        }
        guard let response = try? await client.apiCall(
            authIndex: authIndex,
            method: "POST",
            url: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist",
            headers: Self.googleHeaders(Self.antigravityMetadata),
            body: body
        ), (200..<300).contains(response.statusCode),
           let object = JSONValue.object(from: response.body)
        else {
            return nil
        }
        return QuotaParser.parseGoogleAssistTier(object)
    }

    private func enrichMissingIDs(_ accounts: [AuthAccount]) async throws -> [AuthAccount] {
        try await withThrowingTaskGroup(of: AuthAccount.self) { group in
            for account in accounts {
                group.addTask {
                    var next = account
                    let needsAccountID = (account.provider == .codex || account.provider == .xai)
                        && (account.accountID ?? "").isEmpty
                    let needsProjectID = (account.provider == .geminiCLI || account.provider == .antigravity)
                        && (account.projectID ?? "").isEmpty
                    guard needsAccountID || needsProjectID, let fileName = account.fileName else {
                        return next
                    }
                    if let downloaded = try? await client.downloadAuthFile(named: fileName) {
                        if needsAccountID {
                            next.accountID = account.provider == .xai
                                ? Self.xaiUserID(from: downloaded)
                                : Self.codexAccountID(from: downloaded)
                        }
                        if needsProjectID {
                            next.projectID = JSONValue.firstString(downloaded, paths: ["project_id", "metadata.project_id"])
                        }
                    }
                    return next
                }
            }
            var updated: [AuthAccount] = []
            for try await account in group {
                updated.append(account)
            }
            return updated
        }
    }

    private func decode(_ response: APICallResponse, using parse: ([String: Any]) -> QuotaSnapshot) throws -> QuotaSnapshot {
        guard (200..<300).contains(response.statusCode) else {
            throw ManagementClientError.httpStatus(response.statusCode, response.body)
        }
        guard let object = JSONValue.object(from: response.body) else {
            throw ManagementClientError.invalidResponse
        }
        return parse(object)
    }

    private func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ManagementClientError.invalidResponse
        }
        return text
    }

    static func account(from raw: [String: Any]) -> AuthAccount {
        let name = JSONValue.firstString(raw, paths: ["name", "id"]) ?? UUID().uuidString
        let providerRaw = JSONValue.firstString(raw, paths: ["provider", "type"]) ?? ""
        let provider = QuotaProvider.parse(providerRaw)
        return AuthAccount(
            id: JSONValue.firstString(raw, paths: ["id", "auth_index", "name"]) ?? name,
            authIndex: JSONValue.firstString(raw, paths: ["auth_index", "authIndex", "id"]) ?? name,
            name: name,
            email: JSONValue.firstString(raw, paths: ["email"]),
            provider: provider,
            providerRaw: providerRaw,
            status: JSONValue.firstString(raw, paths: ["status"]) ?? "unknown",
            statusMessage: JSONValue.firstString(raw, paths: ["status_message"]),
            disabled: JSONValue.bool(raw["disabled"]),
            unavailable: JSONValue.bool(raw["unavailable"]),
            accountID: provider == .xai ? xaiUserID(from: raw) : codexAccountID(from: raw),
            projectID: JSONValue.firstString(raw, paths: ["project_id", "metadata.project_id"]),
            fileName: JSONValue.firstString(raw, paths: ["name"])
        )
    }

    static func codexAccountID(from raw: [String: Any]) -> String? {
        if let accountID = JSONValue.firstString(raw, paths: [
            "account_id",
            "chatgpt_account_id",
            "id_token.chatgpt_account_id",
            "metadata.account_id"
        ]) {
            return accountID
        }
        if let jwt = JSONValue.firstString(raw, paths: ["id_token", "metadata.id_token"]) {
            return QuotaParser.chatgptAccountID(fromJWT: jwt)
        }
        return nil
    }

    static func xaiUserID(from raw: [String: Any]) -> String? {
        if let userID = JSONValue.firstString(raw, paths: [
            "sub",
            "subject",
            "user_id",
            "userId",
            "metadata.sub",
            "metadata.subject",
            "metadata.user_id",
            "metadata.userId",
            "attributes.sub",
            "oauth.sub",
            "oauth.subject",
            "user.sub",
            "user.id"
        ]) {
            return userID
        }
        for path in ["access_token", "id_token", "metadata.access_token", "metadata.id_token"] {
            if let jwt = JSONValue.firstString(raw, paths: [path]),
               let userID = QuotaParser.jwtString(jwt, key: "sub") {
                return userID
            }
        }
        return nil
    }

    private static let geminiMetadata = [
        "ideType": "IDE_UNSPECIFIED",
        "platform": "PLATFORM_UNSPECIFIED",
        "pluginType": "GEMINI"
    ]

    private static let antigravityMetadata = [
        "ideType": "ANTIGRAVITY",
        "platform": "PLATFORM_UNSPECIFIED",
        "pluginType": "GEMINI"
    ]

    private static func googleHeaders(_ metadata: [String: String]) -> [String: String] {
        var headers = [
            "Authorization": "Bearer $TOKEN$",
            "Content-Type": "application/json",
            "User-Agent": "google-api-nodejs-client/9.15.1",
            "X-Goog-Api-Client": "google-cloud-sdk vscode_cloudshelleditor/0.1"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: metadata),
           let text = String(data: data, encoding: .utf8) {
            headers["Client-Metadata"] = text
        }
        return headers
    }
}
