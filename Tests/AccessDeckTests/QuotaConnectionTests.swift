import Foundation
import Testing
@testable import AccessDeck

struct QuotaConnectionTests {
    @Test("Magpie connection maps account quotas and authenticates")
    func magpieConnection() async throws {
        let transport = RecordingHTTPDataClient(responses: [
            Response(statusCode: 200, body: Data(#"[{"provider":"codex","name":"Codex","user":"example@example.test","plan":"Plus","windows":[{"name":"5 hours","used":12},{"name":"7 days","used":32}],"resets":{"count":2}}]"#.utf8))
        ])
        var settings = AppSettings.default
        settings.baseURL = "http://magpie.example.test:3430"
        settings.managementKey = "web-key"
        let result = try await QuotaConnectionFactory(transport: transport).make(settings: settings).refresh(force: true)
        let row = try #require(result.accounts.first)
        #expect(row.account.provider == .codex)
        #expect(row.snapshot.windows.map(\.id) == ["5h", "7d"])
        #expect(row.snapshot.windows.map(\.remainingPercent) == [88, 68])
        #expect(row.snapshot.resetCreditCount == 2)
        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].url?.absoluteString == "http://magpie.example.test:3430/api/usage/quotas?asked=1")
        #expect(transport.requests[0].value(forHTTPHeaderField: "Cookie") == "magpie_web_session=web-key; magpie_web_3430=web-key")
    }

    @Test("Magpie gateway connection on port 3425 decodes envelope, remaining field, and Bearer auth")
    func magpieGatewayConnection() async throws {
        let envelopeJSON = """
        {
          "data": [
            {
              "provider": "antigravity",
              "name": "Antigravity",
              "user": "agy@test.com",
              "plan": "pro",
              "windows": [
                { "name": "5 hours", "remaining": 92.5 },
                { "name": "7 days", "remaining": 80.0 }
              ]
            }
          ],
          "object": "list"
        }
        """
        let transport = RecordingHTTPDataClient(responses: [
            Response(statusCode: 200, body: Data(envelopeJSON.utf8))
        ])
        var settings = AppSettings.default
        settings.baseURL = "http://192.168.1.158:3425"
        settings.managementKey = "gateway-secret-key"

        let result = try await QuotaConnectionFactory(transport: transport).make(settings: settings).refresh(force: true)
        let row = try #require(result.accounts.first)
        #expect(row.account.provider == .antigravity)
        #expect(row.snapshot.windows.map(\.id) == ["5h", "7d"])
        #expect(row.snapshot.windows.map(\.remainingPercent) == [92.5, 80.0])
        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].url?.absoluteString == "http://192.168.1.158:3425/v1/magpie/quotas?asked=1")
        #expect(transport.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer gateway-secret-key")
        #expect(transport.requests[0].value(forHTTPHeaderField: "x-api-key") == "gateway-secret-key")
        #expect(transport.requests[0].value(forHTTPHeaderField: "Cookie") == "magpie_web_session=gateway-secret-key; magpie_web_3425=gateway-secret-key")
    }

    @Test("Magpie connection falls back to next candidate path on 404")
    func magpieFallbackCandidatePath() async throws {
        let transport = RecordingHTTPDataClient(responses: [
            Response(statusCode: 404, body: Data()),
            Response(statusCode: 200, body: Data(#"[{"provider":"claude","name":"Claude","user":"claude@test.com","windows":[{"name":"5 hours","used":10}]}]"#.utf8))
        ])
        var settings = AppSettings.default
        settings.baseURL = "http://192.168.1.158:3425"
        settings.managementKey = "any-key"

        let result = try await QuotaConnectionFactory(transport: transport).make(settings: settings).refresh(force: true)
        let row = try #require(result.accounts.first)
        #expect(row.account.provider == .claude)
        #expect(transport.requests.count == 2)
        #expect(transport.requests[0].url?.path == "/v1/magpie/quotas")
        #expect(transport.requests[1].url?.path == "/api/usage/quotas")
    }

    @Test("Magpie connection automatically fails over from offline desktop to router gateway")
    func magpieFailoverFromDesktopToRouterGateway() async throws {
        let envelopeJSON = """
        {
          "data": [
            {
              "provider": "codex",
              "name": "Codex",
              "user": "router@test.com",
              "plan": "Plus",
              "windows": [{ "name": "5 hours", "used": 10 }]
            }
          ]
        }
        """
        #if os(macOS)
        let responses = [
            Response(statusCode: 500, body: Data()),
            Response(statusCode: 500, body: Data()),
            Response(statusCode: 200, body: Data(envelopeJSON.utf8))
        ]
        #else
        let responses = [
            Response(statusCode: 500, body: Data()),
            Response(statusCode: 200, body: Data(envelopeJSON.utf8))
        ]
        #endif
        let transport = RecordingHTTPDataClient(responses: responses)
        let settings = AppSettings.default
        let result = try await QuotaConnectionFactory(transport: transport).make(settings: settings).refresh(force: true)
        let row = try #require(result.accounts.first)
        #expect(row.account.email == "router@test.com")
    }

    @Test("Management client rejects unconfigured requests before transport")
    func managementClientRejectsUnconfiguredRequest() async {
        let transport = RecordingHTTPDataClient(responses: [])
        var unconfigured = AppSettings.default
        unconfigured.baseURL = ""
        unconfigured.managementKey = ""
        let client = ManagementClient(settings: unconfigured, transport: transport)

        await #expect(throws: ManagementClientError.notConfigured) {
            try await client.request(path: "/v0/management/auth-files", method: "GET")
        }
        #expect(transport.requests.isEmpty)
    }

    @Test("Magpie maps Credits, Tokens and Free plan accounts")
    func magpieCreditsAndFreePlanAccountMapping() async throws {
        let json = """
        [
          {
            "provider": "workbuddy-ai",
            "name": "WorkBuddy AI",
            "user": "free@test.com",
            "plan": "Free plan",
            "windows": []
          },
          {
            "provider": "workbuddy-ai",
            "name": "WorkBuddy AI",
            "user": "credits@test.com",
            "plan": "Free plan",
            "windows": [
              {
                "name": "Credits",
                "remaining": 100,
                "display": "0 / 350",
                "unit": "credits"
              },
              {
                "name": "Free model tokens",
                "remaining": 86.67,
                "display": "13.3M / 100M",
                "unit": "tokens"
              }
            ]
          }
        ]
        """
        let transport = RecordingHTTPDataClient(responses: [
            Response(statusCode: 200, body: Data(json.utf8))
        ])
        var settings = AppSettings.default
        settings.baseURL = "http://192.168.1.158:3425"
        settings.managementKey = "key"

        let result = try await QuotaConnectionFactory(transport: transport).make(settings: settings).refresh(force: true)
        #expect(result.accounts.count == 2)

        let freeRow = result.accounts[0]
        #expect(freeRow.account.provider == .workbuddy)
        #expect(freeRow.snapshot.windows.isEmpty)
        #expect(freeRow.snapshot.planType == "Free plan")

        let creditsRow = result.accounts[1]
        #expect(creditsRow.account.provider == .workbuddy)
        #expect(creditsRow.snapshot.windows.count == 2)
        #expect(creditsRow.snapshot.windows[0].id == "credits")
        #expect(creditsRow.snapshot.windows[0].remainingPercent == 100)
        #expect(creditsRow.snapshot.windows[0].label.contains("0 / 350"))
        #expect(creditsRow.snapshot.windows[1].id == "free_tokens")
        #expect(creditsRow.snapshot.windows[1].remainingPercent == 86.67)
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
