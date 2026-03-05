import Foundation

struct RuntimeBootstrapService {
    enum BootstrapError: LocalizedError {
        case agentBinaryNotFound
        case runtimeDependenciesMissing(String)

        var errorDescription: String? {
            switch self {
            case .agentBinaryNotFound:
                return "Runtime agent binary is missing. Build the project or install Aiden package first."
            case .runtimeDependenciesMissing(let root):
                return "Runtime dependencies are missing under \(root). Install package or provide AIDEN_DEV_RUNTIME_ROOT."
            }
        }
    }

    private let fileManager = FileManager.default
    private let appName = "Aiden"
    private let label = "com.aiden.runtimeagent"
    private let collectorTemplate = """
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 127.0.0.1:4317

    processors:
      batch: {}

    exporters:
      prometheusremotewrite:
        endpoint: http://127.0.0.1:18428/api/v1/write
      file/codex:
        path: __CODEX_LOG_PATH__
        format: json
      nop: {}

    service:
      pipelines:
        metrics:
          receivers: [otlp]
          processors: [batch]
          exporters: [prometheusremotewrite]
        logs:
          receivers: [otlp]
          processors: [batch]
          exporters: [file/codex]
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [nop]
    """

    func ensureRuntimeFiles() throws {
        let home = fileManager.homeDirectoryForCurrentUser
        let appSupportRoot = home.appendingPathComponent("Library/Application Support/\(appName)")
        let configDir = appSupportRoot.appendingPathComponent("config")
        let logsDir = home.appendingPathComponent("Library/Logs/\(appName)")
        let launchAgentsDir = home.appendingPathComponent("Library/LaunchAgents")

        try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        let runtimeRoot = try resolveRuntimeRoot(home: home)
        try ensureCollectorConfig(runtimeRoot: runtimeRoot)
        try writeRuntimeDepsLock(runtimeRoot: runtimeRoot)
        let configPath = configDir.appendingPathComponent("runtime.shared.json")
        try upsertRuntimeConfig(path: configPath, runtimeRoot: runtimeRoot)

        let agentBinary = try resolveAgentBinary(home: home)
        let plistPath = launchAgentsDir.appendingPathComponent("\(label).plist")
        try upsertRuntimeAgentPlist(
            path: plistPath,
            agentBinary: agentBinary.path,
            configPath: configPath.path,
            logsDir: logsDir.path
        )
    }

    private func resolveAgentBinary(home: URL) throws -> URL {
        let installed = home.appendingPathComponent("Library/Application Support/\(appName)/bin/AidenRuntimeAgent")
        if fileManager.isExecutableFile(atPath: installed.path) {
            return installed
        }

        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let debug = cwd.appendingPathComponent(".build/debug/AidenRuntimeAgent")
        if fileManager.isExecutableFile(atPath: debug.path) {
            return debug
        }

        let archDebug = cwd.appendingPathComponent(".build/arm64-apple-macosx/debug/AidenRuntimeAgent")
        if fileManager.isExecutableFile(atPath: archDebug.path) {
            return archDebug
        }

        throw BootstrapError.agentBinaryNotFound
    }

    private func resolveRuntimeRoot(home: URL) throws -> URL {
        if let overridden = ProcessInfo.processInfo.environment["AIDEN_DEV_RUNTIME_ROOT"], !overridden.isEmpty {
            let root = URL(fileURLWithPath: overridden)
            if hasDependencies(root: root) {
                return root
            }
        }

        let installedRoot = home.appendingPathComponent("Library/Application Support/\(appName)/runtime")
        if hasDependencies(root: installedRoot) {
            return installedRoot
        }

        throw BootstrapError.runtimeDependenciesMissing(installedRoot.path)
    }

    private func hasDependencies(root: URL) -> Bool {
        let collector = root.appendingPathComponent("bin/otelcol").path
        let vm = root.appendingPathComponent("bin/victoria-metrics-prod").path
        return fileManager.isExecutableFile(atPath: collector)
            && fileManager.isExecutableFile(atPath: vm)
    }

    private func ensureCollectorConfig(runtimeRoot: URL) throws {
        let collectorConfig = runtimeRoot.appendingPathComponent("collector/config/collector.yaml")
        let logsDir = runtimeRoot.appendingPathComponent("logs")
        let codexLogPath = logsDir.appendingPathComponent("codex-otel.jsonl").path
        try fileManager.createDirectory(at: collectorConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let templateText = loadCollectorTemplate()
        let rendered = templateText.replacingOccurrences(of: "__CODEX_LOG_PATH__", with: codexLogPath)

        var existingText = ""
        if fileManager.fileExists(atPath: collectorConfig.path),
           let data = fileManager.contents(atPath: collectorConfig.path),
           let text = String(data: data, encoding: .utf8) {
            existingText = text
        }

        if existingText == rendered {
            return
        }
        if !existingText.isEmpty && !existingText.contains("__CODEX_LOG_PATH__") {
            return
        }

        try writeAtomically(text: rendered, to: collectorConfig)
    }

    private func loadCollectorTemplate() -> String {
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let repoTemplate = cwd
            .appendingPathComponent("third_party")
            .appendingPathComponent("collector")
            .appendingPathComponent("config.yaml.template")
        if let data = fileManager.contents(atPath: repoTemplate.path),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return collectorTemplate
    }

    private func writeRuntimeDepsLock(runtimeRoot: URL) throws {
        let collectorBinary = runtimeRoot.appendingPathComponent("bin/otelcol")
        let vmBinary = runtimeRoot.appendingPathComponent("bin/victoria-metrics-prod")
        let lockPath = runtimeRoot.appendingPathComponent("deps.lock.json")

        let now = iso8601Now()
        let payload: [String: Any] = [
            "updated_at": now,
            "collector": [
                "binary_path": collectorBinary.path,
                "binary_sha256": sha256(path: collectorBinary.path) ?? "unknown",
                "version": collectorVersion(binary: collectorBinary) ?? "unknown",
                "observed_at": now
            ],
            "vm": [
                "binary_path": vmBinary.path,
                "binary_sha256": sha256(path: vmBinary.path) ?? "unknown",
                "version": vmVersion(binary: vmBinary) ?? "unknown",
                "observed_at": now
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try writeAtomically(data: data, to: lockPath)
    }

    private func sha256(path: String) -> String? {
        guard let output = runCommand("/usr/bin/shasum", ["-a", "256", path]) else { return nil }
        let parts = output.split(separator: " ")
        guard let first = parts.first else { return nil }
        return String(first).lowercased()
    }

    private func collectorVersion(binary: URL) -> String? {
        guard let output = runCommand(binary.path, ["components"]) else { return nil }
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("version:") {
                return trimmed.replacingOccurrences(of: "version:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func vmVersion(binary: URL) -> String? {
        guard let output = runCommand(binary.path, ["-version"]) else { return nil }
        if let match = output.range(of: #"v\d+\.\d+\.\d+([-\+][A-Za-z0-9\.-]+)?"#, options: .regularExpression) {
            return String(output[match])
        }
        return nil
    }

    private func runCommand(_ executable: String, _ arguments: [String]) -> String? {
        guard fileManager.isExecutableFile(atPath: executable) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func writeAtomically(text: String, to path: URL) throws {
        try writeAtomically(data: Data(text.utf8), to: path)
    }

    private func writeAtomically(data: Data, to path: URL) throws {
        let temp = path.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        try data.write(to: temp, options: .atomic)
        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
        }
        try fileManager.moveItem(at: temp, to: path)
    }

    private func upsertRuntimeConfig(path: URL, runtimeRoot: URL) throws {
        let runtimeRootPath = runtimeRoot.path
        var payload: [String: Any] = [:]
        if let existing = fileManager.contents(atPath: path.path),
           let loaded = try? JSONSerialization.jsonObject(with: existing) as? [String: Any] {
            payload = loaded
        }

        payload["agent"] = [
            "host": "127.0.0.1",
            "port": 18777
        ]
        payload["runtime"] = [
            "rootPath": runtimeRootPath,
            "vmPath": "bin/victoria-metrics-prod",
            "collectorPath": "bin/otelcol",
            "vmArgs": [
                "-retentionPeriod=30d",
                "-httpListenAddr=:18428",
                "-storageDataPath",
                "\(runtimeRootPath)/data/victoria-metrics"
            ],
            "collectorArgs": [
                "--config",
                "\(runtimeRootPath)/collector/config/collector.yaml"
            ]
        ]
        payload["polling"] = ["seconds": 5]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: path, options: .atomic)
    }

    private func upsertRuntimeAgentPlist(path: URL, agentBinary: String, configPath: String, logsDir: String) throws {
        var plist: [String: Any] = [:]
        if let existing = fileManager.contents(atPath: path.path),
           let loaded = try? PropertyListSerialization.propertyList(from: existing, options: [], format: nil) as? [String: Any] {
            plist = loaded
        }

        plist["Label"] = label
        plist["ProgramArguments"] = [agentBinary]
        plist["RunAtLoad"] = false
        plist["KeepAlive"] = true
        plist["StandardOutPath"] = "\(logsDir)/runtimeagent.out.log"
        plist["StandardErrorPath"] = "\(logsDir)/runtimeagent.err.log"
        plist["EnvironmentVariables"] = ["AIDEN_CONFIG_PATH": configPath]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: path, options: .atomic)
    }
}
