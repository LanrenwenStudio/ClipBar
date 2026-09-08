import Foundation

struct QuotaBackendClient: Sendable {
    var settings: AppSettings
    var session: URLSession = .shared

    func fetchSnapshot() async throws -> (accounts: [AccountQuota], updatedAt: Date?) {
        try await requestSnapshot(path: "/v1/snapshot", method: "GET")
    }

    func refreshSnapshot() async throws -> (accounts: [AccountQuota], updatedAt: Date?) {
        try await requestSnapshot(path: "/v1/refresh", method: "POST")
    }

    func fetchRefreshInterval() async throws -> Int {
        guard settings.usesBackend else {
            throw ManagementClientError.notConfigured
        }
        guard let url = backendURL(path: "/v1/settings") else {
            throw ManagementClientError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(settings.normalizedBackendAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("ClipBar/0.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ManagementClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode),
              let object = JSONValue.object(from: data),
              let seconds = JSONValue.int(object["refresh_interval_seconds"]) else {
            throw ManagementClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return seconds
    }

    func updateRefreshInterval(_ seconds: Int) async throws -> Int {
        guard settings.usesBackend else {
            throw ManagementClientError.notConfigured
        }
        guard let url = backendURL(path: "/v1/settings") else {
            throw ManagementClientError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 15
        request.setValue("Bearer \(settings.normalizedBackendAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ClipBar/0.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_interval_seconds": seconds])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ManagementClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode),
              let object = JSONValue.object(from: data),
              let value = JSONValue.int(object["refresh_interval_seconds"]) else {
            throw ManagementClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return value
    }

    private func requestSnapshot(path: String, method: String) async throws -> (accounts: [AccountQuota], updatedAt: Date?) {
        guard settings.usesBackend else {
            throw ManagementClientError.notConfigured
        }
        guard let url = backendURL(path: path) else {
            throw ManagementClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = method == "POST" ? 60 : 30
        request.setValue("Bearer \(settings.normalizedBackendAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("ClipBar/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ManagementClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ManagementClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let object = JSONValue.object(from: data),
              let rawAccounts = object["accounts"] as? [[String: Any]] else {
            throw ManagementClientError.invalidResponse
        }

        let accounts = try rawAccounts.map { raw in
            guard let accountObject = raw["account"] as? [String: Any],
                  let snapshotObject = raw["snapshot"] as? [String: Any] else {
                throw ManagementClientError.invalidResponse
            }
            return AccountQuota(
                account: try decodeAccount(accountObject),
                snapshot: try decodeSnapshot(snapshotObject)
            )
        }
        let updatedAt = (object["last_updated_at"] as? String).flatMap(Self.parseDate)
        if let error = object["error"] as? String, !error.isEmpty, accounts.isEmpty {
            throw ManagementClientError.httpStatus(503, error)
        }
        return (accounts, updatedAt)
    }

    private func backendURL(path: String) -> URL? {
        var raw = settings.normalizedBackendURL
        if !raw.contains("://") {
            raw = "http://\(raw)"
        }
        guard var components = URLComponents(string: raw) else { return nil }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, suffix].filter { !$0.isEmpty }.joined(separator: "/")
        return components.url
    }

    private func decodeAccount(_ object: [String: Any]) throws -> AuthAccount {
        guard let id = JSONValue.firstString(object, paths: ["id"]),
              let authIndex = JSONValue.firstString(object, paths: ["authIndex"]),
              let name = JSONValue.firstString(object, paths: ["name"]),
              let providerRaw = JSONValue.firstString(object, paths: ["providerRaw"]) else {
            throw ManagementClientError.invalidResponse
        }
        return AuthAccount(
            id: id,
            authIndex: authIndex,
            name: name,
            email: JSONValue.firstString(object, paths: ["email"]),
            provider: QuotaProvider.parse(JSONValue.firstString(object, paths: ["provider", "providerRaw"])),
            providerRaw: providerRaw,
            status: JSONValue.firstString(object, paths: ["status"]) ?? "unknown",
            statusMessage: JSONValue.firstString(object, paths: ["statusMessage"]),
            disabled: JSONValue.bool(object["disabled"]),
            unavailable: JSONValue.bool(object["unavailable"]),
            accountID: JSONValue.firstString(object, paths: ["accountID"]),
            projectID: JSONValue.firstString(object, paths: ["projectID"]),
            fileName: JSONValue.firstString(object, paths: ["fileName"])
        )
    }

    private func decodeSnapshot(_ object: [String: Any]) throws -> QuotaSnapshot {
        let rawWindows = object["windows"] as? [[String: Any]] ?? []
        let windows = rawWindows.compactMap { raw -> QuotaWindow? in
            guard let id = JSONValue.firstString(raw, paths: ["id"]),
                  let label = JSONValue.firstString(raw, paths: ["label"]) else {
                return nil
            }
            return QuotaWindow(
                id: id,
                label: label,
                remainingPercent: JSONValue.double(raw["remainingPercent"]),
                resetText: JSONValue.firstString(raw, paths: ["resetText"])
            )
        }
        return QuotaSnapshot(
            planType: JSONValue.firstString(object, paths: ["planType"]),
            windows: windows,
            error: JSONValue.firstString(object, paths: ["error"])
        )
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}
