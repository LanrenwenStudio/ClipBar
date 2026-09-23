import Foundation
import Testing
@testable import AccessDeck

struct QuotaConnectionTests {
    @Test("Factory selects the direct connection mode")
    func factorySelectsDirectMode() async throws {
        let transport = RecordingHTTPDataClient(responses: [
            Response(
                statusCode: 200,
                body: Data(#"{"files":[]}"#.utf8)
            )
        ])
        var settings = AppSettings.default
        settings.baseURL = "http://cpa.example.test"
        settings.managementKey = "management-key"

        let result = try await QuotaConnectionFactory(transport: transport)
            .make(settings: settings)
            .refresh(force: true)

        #expect(result.accounts.isEmpty)
        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].httpMethod == "GET")
        #expect(transport.requests[0].url?.absoluteString == "http://cpa.example.test/v0/management/auth-files")
    }

    @Test("Management client rejects unconfigured requests before transport")
    func managementClientRejectsUnconfiguredRequest() async {
        let transport = RecordingHTTPDataClient(responses: [])
        let client = ManagementClient(settings: .default, transport: transport)

        await #expect(throws: ManagementClientError.notConfigured) {
            try await client.request(path: "/v0/management/auth-files", method: "GET")
        }
        #expect(transport.requests.isEmpty)
    }
}

private struct Response: Sendable {
    let statusCode: Int
    let body: Data
}

private final class RecordingHTTPDataClient: HTTPDataClient, @unchecked Sendable {
    private var responseQueue: [Response]
    private(set) var requests: [URLRequest] = []

    init(responses: [Response]) {
        self.responseQueue = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = responseQueue.isEmpty
            ? Response(statusCode: 500, body: Data())
            : responseQueue.removeFirst()

        let httpResponse = HTTPURLResponse(
            url: request.url ?? URL(string: "http://invalid.example.test")!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response.body, httpResponse)
    }
}
