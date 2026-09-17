import Foundation

struct QuotaRefreshResult: Sendable {
    let accounts: [AccountQuota]
    let updatedAt: Date?
    let error: String?

    init(accounts: [AccountQuota], updatedAt: Date? = nil, error: String? = nil) {
        self.accounts = accounts
        self.updatedAt = updatedAt
        self.error = error
    }
}

protocol QuotaConnection: Sendable {
    func refresh(force: Bool) async throws -> QuotaRefreshResult
}

protocol HTTPDataClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionDataClient: HTTPDataClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

struct QuotaConnectionFactory: Sendable {
    private let transport: any HTTPDataClient

    init(transport: any HTTPDataClient = URLSessionDataClient()) {
        self.transport = transport
    }

    func make(settings: AppSettings) -> any QuotaConnection {
        let client = ManagementClient(settings: settings, transport: transport)
        switch settings.connectionMode {
        case .direct:
            return DirectQuotaConnection(service: QuotaService(client: client))
        case .plugin:
            return PluginQuotaConnection(client: client)
        }
    }
}

struct DirectQuotaConnection: QuotaConnection {
    let service: QuotaService

    func refresh(force _: Bool) async throws -> QuotaRefreshResult {
        QuotaRefreshResult(accounts: try await service.refresh())
    }
}

struct PluginQuotaConnection: QuotaConnection {
    let client: ManagementClient

    func refresh(force: Bool) async throws -> QuotaRefreshResult {
        let path = force
            ? "/v0/management/plugins/clipbar-quota/refresh"
            : "/v0/management/plugins/clipbar-quota/snapshot"
        let method = force ? "POST" : "GET"
        let response = try await client.request(path: path, method: method, timeout: force ? 90 : 30)
        return try PluginSnapshotDecoder.decode(data: response.data, statusCode: response.statusCode)
    }
}

enum QuotaConnectionError: LocalizedError, Equatable, Sendable {
    case plugin(String)

    var errorDescription: String? {
        switch self {
        case .plugin(let message):
            message
        }
    }
}

enum PluginSnapshotDecoder {
    private struct Snapshot: Decodable {
        let accounts: [AccountQuota]
        let updatedAt: Date?
        let error: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accounts = try container.decodeIfPresent([AccountQuota].self, forKey: .accounts) ?? []
            error = try container.decodeIfPresent(String.self, forKey: .error)

            let rawDate = try container.decodeIfPresent(String.self, forKey: .lastUpdatedAt)
            updatedAt = rawDate.flatMap(Self.parseDate)
        }

        private enum CodingKeys: String, CodingKey {
            case accounts
            case error
            case lastUpdatedAt = "last_updated_at"
        }

        private static func parseDate(_ raw: String) -> Date? {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        }
    }

    static func decode(data: Data, statusCode: Int) throws -> QuotaRefreshResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if (200..<300).contains(statusCode) {
                throw ManagementClientError.invalidResponse
            }
            throw ManagementClientError.httpStatus(statusCode, "")
        }

        let snapshotObject = (root["snapshot"] as? [String: Any]) ?? root
        let snapshotData = try JSONSerialization.data(withJSONObject: snapshotObject)
        let snapshot = try decodeSnapshot(snapshotData)
        let envelopeError = JSONValue.string(root["error"])
        let message = envelopeError ?? snapshot.error

        if !(200..<300).contains(statusCode) {
            guard !snapshot.accounts.isEmpty else {
                throw ManagementClientError.httpStatus(statusCode, message ?? "")
            }
            return QuotaRefreshResult(
                accounts: snapshot.accounts,
                updatedAt: snapshot.updatedAt,
                error: message ?? "HTTP \(statusCode)"
            )
        }

        if let message, snapshot.accounts.isEmpty {
            throw QuotaConnectionError.plugin(message)
        }
        return QuotaRefreshResult(
            accounts: snapshot.accounts,
            updatedAt: snapshot.updatedAt,
            error: message
        )
    }

    private static func decodeSnapshot(_ data: Data) throws -> Snapshot {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Snapshot.self, from: data)
        } catch {
            let compatibleDecoder = JSONDecoder()
            compatibleDecoder.keyDecodingStrategy = .convertFromSnakeCase
            return try compatibleDecoder.decode(Snapshot.self, from: data)
        }
    }
}
