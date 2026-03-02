import Foundation
import AidenShared

final class CliProvisioningService {
    func states() -> [CliState] {
        CliProvider.allCases.map { provider in
            CliState(provider: provider, installed: isInstalled(provider), enabled: isEnabled(provider))
        }
    }

    func setEnabled(_ enabled: Bool, provider: CliProvider) {
        switch provider {
        case .gemini:
            updateJSONConfig(relativePath: ".gemini/settings.json") { root in
                var telemetry = (root["telemetry"] as? [String: Any]) ?? [:]
                telemetry["enabled"] = enabled
                telemetry["target"] = "local"
                telemetry["useCollector"] = true
                telemetry["otlpProtocol"] = "grpc"
                telemetry["otlpEndpoint"] = "http://127.0.0.1:4317"
                root["telemetry"] = telemetry
            }
        case .claude:
            updateJSONConfig(relativePath: ".claude/settings.json") { root in
                var env = (root["env"] as? [String: Any]) ?? [:]
                env["CLAUDE_CODE_ENABLE_TELEMETRY"] = enabled ? "1" : "0"
                env["OTEL_METRICS_EXPORTER"] = enabled ? "otlp" : "none"
                env["OTEL_LOGS_EXPORTER"] = enabled ? "otlp" : "none"
                env["OTEL_EXPORTER_OTLP_PROTOCOL"] = "grpc"
                env["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://127.0.0.1:4317"
                root["env"] = env
            }
        case .codex:
            updateCodexToml(enabled: enabled)
        }
    }

    private func isInstalled(_ provider: CliProvider) -> Bool {
        let command: String
        switch provider {
        case .gemini: command = "gemini"
        case .codex: command = "codex"
        case .claude: command = "claude"
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func isEnabled(_ provider: CliProvider) -> Bool {
        switch provider {
        case .gemini:
            guard let telemetry = readJson(relativePath: ".gemini/settings.json")?["telemetry"] as? [String: Any] else {
                return false
            }
            return parseEnabledValue(telemetry["enabled"])
        case .claude:
            let env = readJson(relativePath: ".claude/settings.json")?["env"] as? [String: Any]
            return (env?["CLAUDE_CODE_ENABLE_TELEMETRY"] as? String) == "1"
        case .codex:
            let path = home().appendingPathComponent(".codex/config.toml").path
            guard let content = try? String(contentsOfFile: path) else { return false }
            return content.contains("otlp-grpc")
        }
    }

    private func parseEnabledValue(_ raw: Any?) -> Bool {
        if let boolValue = raw as? Bool { return boolValue }
        if let stringValue = raw as? String {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "on":
                return true
            default:
                return false
            }
        }
        if let numberValue = raw as? NSNumber { return numberValue.boolValue }
        return false
    }

    private func updateJSONConfig(relativePath: String, update: (inout [String: Any]) -> Void) {
        let url = home().appendingPathComponent(relativePath)
        var root = readJson(relativePath: relativePath) ?? [:]
        update(&root)
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted]) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    private func updateCodexToml(enabled: Bool) {
        let url = home().appendingPathComponent(".codex/config.toml")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let body: String
        if enabled {
            body = """
            [otel]
            environment = "dev"
            log_user_prompt = false
            exporter = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
            trace_exporter = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
            """
        } else {
            body = """
            [otel]
            exporter = "none"
            trace_exporter = "none"
            """
        }
        try? body.write(to: url, atomically: true, encoding: .utf8)
    }

    private func readJson(relativePath: String) -> [String: Any]? {
        let path = home().appendingPathComponent(relativePath).path
        guard let data = FileManager.default.contents(atPath: path),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let map = obj as? [String: Any] else {
            return nil
        }
        return map
    }

    private func home() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
}
