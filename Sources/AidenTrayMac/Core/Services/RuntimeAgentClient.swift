import Foundation
import AidenShared

final class RuntimeAgentClient {
    private let baseURL: URL
    private let decoder = JSONDecoder()

    init(host: String = "127.0.0.1", port: Int = 18777) {
        self.baseURL = URL(string: "http://\(host):\(port)")!
    }

    func healthz() async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("healthz"))
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    func status() async throws -> RuntimeStatus {
        let (data, _) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("status"))
        return try decoder.decode(RuntimeStatus.self, from: data)
    }

    func telemetry(provider: CliProvider) async throws -> TelemetrySnapshot {
        var comps = URLComponents(url: baseURL.appendingPathComponent("telemetry"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "cli", value: provider.rawValue)]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try decoder.decode(TelemetrySnapshot.self, from: data)
    }

    func refresh() async {
        var request = URLRequest(url: baseURL.appendingPathComponent("refresh"))
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
    }

    func restart() async {
        var request = URLRequest(url: baseURL.appendingPathComponent("restart"))
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
    }
}
