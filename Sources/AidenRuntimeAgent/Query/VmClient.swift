import Foundation
import AidenShared

struct VmClient {
    struct UserSample {
        let email: String
        let timestampSeconds: Double
    }

    let baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:18428")!) {
        self.baseURL = baseURL
    }

    func queryValue(_ metricsQL: String) async throws -> Double? {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("api/v1/query"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        comps.queryItems = [URLQueryItem(name: "query", value: metricsQL)]
        guard let url = comps.url else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        return Self.parseQueryValueResponse(data)
    }

    func queryLatestUser(_ metricsQL: String) async throws -> UserSample? {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("api/v1/query"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        comps.queryItems = [URLQueryItem(name: "query", value: metricsQL)]
        guard let url = comps.url else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        return Self.parseLatestUserResponse(data)
    }

    func queryEpochSeconds(_ metricsQL: String) async throws -> Double? {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("api/v1/query"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        comps.queryItems = [URLQueryItem(name: "query", value: metricsQL)]
        guard let url = comps.url else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        return Self.parseEpochSecondsResponse(data)
    }

    static func parseQueryValueResponse(_ data: Data) -> Double? {
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataNode = obj?["data"] as? [String: Any]
        let result = dataNode?["result"] as? [[String: Any]]
        guard let first = result?.first, let value = first["value"] as? [Any], value.count >= 2 else {
            return nil
        }
        return Double(String(describing: value[1]))
    }

    static func parseEpochSecondsResponse(_ data: Data) -> Double? {
        parseQueryValueResponse(data)
    }

    static func parseLatestUserResponse(_ data: Data) -> UserSample? {
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataNode = obj?["data"] as? [String: Any]
        let result = dataNode?["result"] as? [[String: Any]]
        let metric = result?.first?["metric"] as? [String: Any]
        guard let email = metric?["user_email"] as? String else { return nil }
        guard let value = result?.first?["value"] as? [Any], value.count >= 2 else { return nil }
        guard let timestamp = Double(String(describing: value[1])) else { return nil }
        return UserSample(email: email, timestampSeconds: timestamp)
    }
}
