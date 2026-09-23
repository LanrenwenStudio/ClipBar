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
        return DirectQuotaConnection(service: QuotaService(client: client))
    }
}

struct DirectQuotaConnection: QuotaConnection {
    let service: QuotaService

    func refresh(force _: Bool) async throws -> QuotaRefreshResult {
        QuotaRefreshResult(accounts: try await service.refresh())
    }
}
