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
        let installedRoot = home.appendingPathComponent("Library/Application Support/\(appName)/runtime/current")
        if hasDependencies(root: installedRoot) {
            return installedRoot
        }

        if let overridden = ProcessInfo.processInfo.environment["AIDEN_DEV_RUNTIME_ROOT"], !overridden.isEmpty {
            let root = URL(fileURLWithPath: overridden)
            if hasDependencies(root: root) {
                return root
            }
        }

        throw BootstrapError.runtimeDependenciesMissing(installedRoot.path)
    }

    private func hasDependencies(root: URL) -> Bool {
        let collector = root.appendingPathComponent("bin/otelcol").path
        let vm = root.appendingPathComponent("bin/victoria-metrics-prod").path
        return fileManager.isExecutableFile(atPath: collector) && fileManager.isExecutableFile(atPath: vm)
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
                "\(runtimeRootPath)/config/collector.yaml"
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
