import Foundation

struct CodexSchedulerClient: Sendable {
    let baseURL: String
    private let session: URLSession

    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// 根据用户设置的 CPA 地址推导调度状态服务地址（默认端口 8318）
    var statusEndpointURL: URL? {
        guard let url = URL(string: baseURL), let host = url.host else {
            return URL(string: "http://192.168.1.3:8318/status")
        }
        var components = URLComponents()
        components.scheme = url.scheme ?? "http"
        components.host = host
        components.port = 8318
        components.path = "/status"
        return components.url
    }

    func fetchStatus() async throws -> CodexSchedulerStatus {
        guard let endpoint = statusEndpointURL else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 4.0
        request.setValue("AccessDeck/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoder = JSONDecoder()
            return try decoder.decode(CodexSchedulerStatus.self, from: data)
        } catch {
            #if os(macOS)
            // macOS 本地 fallback：若局域网 HTTP 暂不可用，尝试通过 SSH 只读命令获取
            if let sshStatus = try? fetchStatusViaSSH() {
                return sshStatus
            }
            #endif
            throw error
        }
    }

    #if os(macOS)
    private func fetchStatusViaSSH() throws -> CodexSchedulerStatus {
        guard let url = URL(string: baseURL), let host = url.host else {
            throw URLError(.cannotConnectToHost)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=4",
            "root@\(host)",
            "node /root/CLIProxyAPI/plus-scheduler/scheduler.cjs --status"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw URLError(.cannotConnectToHost)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let decoder = JSONDecoder()
        return try decoder.decode(CodexSchedulerStatus.self, from: data)
    }
    #endif
}
