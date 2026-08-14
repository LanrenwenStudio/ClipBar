import Foundation

struct APICallResponse: Sendable {
    var statusCode: Int
    var body: String
}

enum ManagementClientError: LocalizedError, Equatable {
    case notConfigured
    case invalidBaseURL
    case httpStatus(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            L10n.t("先填写 CLIProxyAPI 地址和管理密钥。", "Enter the CLIProxyAPI URL and management key first.")
        case .invalidBaseURL:
            L10n.t("管理地址无效。", "The management URL is invalid.")
        case let .httpStatus(code, body):
            "HTTP \(code): \(body.prefix(160))"
        case .invalidResponse:
            L10n.t("管理接口返回了无法解析的数据。", "The management API returned an invalid response.")
        }
    }
}

struct ManagementClient: Sendable {
    var settings: AppSettings
    var session: URLSession = .shared

    func fetchAuthFiles() async throws -> [[String: Any]] {
        let data = try await get(path: "/v0/management/auth-files")
        if let object = JSONValue.object(from: data), let files = object["files"] as? [[String: Any]] {
            return files
        }
        if let files = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
            return files
        }
        throw ManagementClientError.invalidResponse
    }

    func downloadAuthFile(named name: String) async throws -> [String: Any] {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let data = try await get(path: "/v0/management/auth-files/download?name=\(encoded)")
        guard let object = JSONValue.object(from: data) else {
            throw ManagementClientError.invalidResponse
        }
        return object
    }

    func apiCall(
        authIndex: String,
        method: String,
        url: String,
        headers: [String: String],
        body: String? = nil
    ) async throws -> APICallResponse {
        var request = try managementRequest(path: "/v0/management/api-call")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "auth_index": authIndex,
            "method": method,
            "url": url,
            "header": headers
        ]
        if let body {
            payload["data"] = body
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ManagementClientError.invalidResponse
        }
        if let envelope = JSONValue.object(from: data),
           let status = JSONValue.int(envelope["status_code"]) ?? JSONValue.int(envelope["statusCode"]) {
            let bodyText: String
            if let text = envelope["body"] as? String {
                bodyText = text
            } else if let nested = envelope["body"],
                      let nestedData = try? JSONSerialization.data(withJSONObject: nested),
                      let text = String(data: nestedData, encoding: .utf8) {
                bodyText = text
            } else {
                bodyText = String(data: data, encoding: .utf8) ?? ""
            }
            return APICallResponse(statusCode: status, body: bodyText)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ManagementClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        throw ManagementClientError.invalidResponse
    }

    private func get(path: String) async throws -> Data {
        var request = try managementRequest(path: path)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ManagementClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ManagementClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    private func managementRequest(path: String) throws -> URLRequest {
        guard settings.isConfigured else {
            throw ManagementClientError.notConfigured
        }
        guard let url = managementURL(path: path) else {
            throw ManagementClientError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(settings.normalizedManagementKey)", forHTTPHeaderField: "Authorization")
        request.setValue(settings.normalizedManagementKey, forHTTPHeaderField: "X-Management-Key")
        request.setValue("ClipBar/0.1", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func managementURL(path: String) -> URL? {
        var raw = settings.normalizedBaseURL
        if !raw.contains("://") {
            raw = "http://\(raw)"
        }
        guard var components = URLComponents(string: raw) else {
            return nil
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.contains("?") {
            let pieces = path.split(separator: "?", maxSplits: 1).map(String.init)
            let suffix = pieces[0].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + [basePath, suffix].filter { !$0.isEmpty }.joined(separator: "/")
            components.query = pieces.count > 1 ? pieces[1] : nil
        } else {
            let suffix = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + [basePath, suffix].filter { !$0.isEmpty }.joined(separator: "/")
        }
        return components.url
    }
}
