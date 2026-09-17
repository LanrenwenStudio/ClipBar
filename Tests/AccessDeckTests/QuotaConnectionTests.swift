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

    @Test("Plugin refresh uses POST while snapshot reads use GET")
    func pluginRoutesAndMethods() async throws {
        let transport = RecordingHTTPDataClient(responses: [
            Response(statusCode: 200, body: Data(snapshotJSON(updatedAt: "2026-01-01T00:00:00Z").utf8)),
            Response(statusCode: 200, body: Data(snapshotJSON(updatedAt: "2026-01-01T00:00:00.250Z").utf8))
        ])
        var settings = AppSettings.default
        settings.baseURL = "http://cpa.example.test/"
        settings.managementKey = "management-key"
        settings.connectionMode = .plugin
        let connection = QuotaConnectionFactory(transport: transport).make(settings: settings)

        let cached = try await connection.refresh(force: false)
        let refreshed = try await connection.refresh(force: true)

        #expect(cached.accounts.count == 1)
        #expect(refreshed.accounts.count == 1)
        #expect(transport.requests.map(\.httpMethod) == ["GET", "POST"])
        #expect(transport.requests[0].url?.path == "/v0/management/plugins/clipbar-quota/snapshot")
        #expect(transport.requests[1].url?.path == "/v0/management/plugins/clipbar-quota/refresh")
        #expect(transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer management-key" })
        #expect(transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "X-Management-Key") == "management-key" })
    }

    @Test("Plugin decoder accepts nested snapshots and fractional timestamps")
    func decoderAcceptsNestedSnapshot() throws {
        let data = Data(#"{"snapshot":{"schema_version":1,"last_updated_at":"2026-01-01T00:00:00.250Z","accounts":[]}}"#.utf8)
        let result = try PluginSnapshotDecoder.decode(data: data, statusCode: 200)

        #expect(result.accounts.isEmpty)
        let expected = ISO8601DateFormatter()
        expected.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(result.updatedAt == expected.date(from: "2026-01-01T00:00:00.250Z"))
        #expect(result.error == nil)
    }

    @Test("Plugin decoder preserves cached accounts with an HTTP error")
    func decoderPreservesCachedAccountsOnHTTPError() throws {
        let data = Data(snapshotJSON(updatedAt: "2026-01-01T00:00:00Z", error: "provider unavailable").utf8)
        let result = try PluginSnapshotDecoder.decode(data: data, statusCode: 502)

        #expect(result.accounts.count == 1)
        #expect(result.error == "provider unavailable")
    }

    @Test("Plugin decoder throws HTTP errors when no cached accounts are available")
    func decoderRejectsHTTPErrorWithoutAccounts() {
        let data = Data(#"{"error":"provider unavailable","accounts":[]}"#.utf8)

        #expect(throws: ManagementClientError.httpStatus(502, "provider unavailable")) {
            try PluginSnapshotDecoder.decode(data: data, statusCode: 502)
        }
    }

    @Test("Plugin decoder reports a successful response error without accounts")
    func decoderRejectsSuccessfulErrorWithoutAccounts() {
        let data = Data(#"{"error":"plugin is disabled","accounts":[]}"#.utf8)

        #expect(throws: QuotaConnectionError.plugin("plugin is disabled")) {
            try PluginSnapshotDecoder.decode(data: data, statusCode: 200)
        }
    }

    @Test("Management client rejects unconfigured requests before transport")
    func managementClientRejectsUnconfiguredRequest() async {
        let transport = RecordingHTTPDataClient(responses: [])
        let client = ManagementClient(settings: .default, transport: transport)

        await #expect(throws: ManagementClientError.notConfigured) {
            try await client.request(path: "/v0/management/plugins/clipbar-quota/snapshot", method: "GET")
        }
        #expect(transport.requests.isEmpty)
    }

    private func snapshotJSON(updatedAt: String, error: String? = nil) -> String {
        let errorJSON = error.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "schema_version": 1,
          "last_updated_at": "\(updatedAt)",
          "accounts": [
            {
              "account": {
                "id": "account-1",
                "authIndex": "auth-1",
                "name": "account.json",
                "provider": "codex",
                "providerRaw": "openai",
                "status": "ready",
                "disabled": false,
                "unavailable": false
              },
              "snapshot": {
                "planType": "plus",
                "windows": [{"id":"5h","label":"5h","remainingPercent":80,"resetText":null}],
                "error": null
              }
            }
          ],
          "error": \(errorJSON)
        }
        """
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
