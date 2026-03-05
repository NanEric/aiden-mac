import Foundation

public struct AppConfig: Codable, Sendable {
    public struct Agent: Codable, Sendable {
        public let host: String
        public let port: Int
    }

    public struct Runtime: Codable, Sendable {
        public let rootPath: String
        public let vmPath: String
        public let collectorPath: String
        public let vmArgs: [String]
        public let collectorArgs: [String]
    }

    public struct Polling: Codable, Sendable {
        public let seconds: Int
    }

    public let agent: Agent
    public let runtime: Runtime
    public let polling: Polling

    public static var `default`: AppConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return AppConfig(
            agent: Agent(host: "127.0.0.1", port: 18777),
            runtime: Runtime(
                rootPath: home + "/Library/Application Support/Aiden/runtime",
                vmPath: "bin/victoria-metrics-prod",
                collectorPath: "bin/otelcol",
                vmArgs: ["-retentionPeriod=30d", "-httpListenAddr=:18428"],
                collectorArgs: ["--config", home + "/Library/Application Support/Aiden/runtime/collector/config/collector.yaml"]
            ),
            polling: Polling(seconds: 5)
        )
    }
}
