import Foundation
import Dispatch
import AidenShared

@main
struct AidenRuntimeAgentMain {
    static func main() async {
        do {
            let configPath = ProcessInfo.processInfo.environment["AIDEN_CONFIG_PATH"]
            let appConfig = try ConfigLoader.load(from: configPath)
            let config = AgentConfig(app: appConfig)

            let bootstrapper = DependencyBootstrapper()
            try bootstrapper.verifyInstalled(collector: config.collectorBinary, vm: config.vmBinary)

            let supervisor = RuntimeSupervisor(config: config)
            let state = AgentState()
            let codexLogPath = config.runtimeRoot.appendingPathComponent("logs/codex-otel.jsonl")
            let aggregator = TelemetryAggregator(vmClient: VmClient(), codexLogClient: CodexLogClient(logPath: codexLogPath))

            supervisor.ensureStarted()
            await state.setStatus(supervisor.status())

            let server = try HttpServer(host: config.host, port: UInt16(config.port)) { method, path, query in
                switch (method, path) {
                case ("GET", "/healthz"):
                    return (200, Data("{\"ok\":true}".utf8))
                case ("GET", "/status"):
                    let status = supervisor.status()
                    await state.setStatus(status)
                    return (200, StatusController.encode(status))
                case ("GET", "/telemetry"):
                    let provider = CliProvider(rawValue: query["cli"] ?? "gemini") ?? .gemini
                    if let cached = await state.getSnapshot(provider: provider) {
                        return (200, TelemetryController.encode(cached))
                    }
                    let status = await state.getStatus()
                    let snapshot = await aggregator.snapshot(for: provider, runtimeOnline: status.online)
                    await state.setSnapshot(snapshot)
                    return (200, TelemetryController.encode(snapshot))
                case ("POST", "/refresh"):
                    let status = supervisor.status()
                    await state.setStatus(status)
                    for provider in CliProvider.allCases {
                        let snapshot = await aggregator.snapshot(for: provider, runtimeOnline: status.online)
                        await state.setSnapshot(snapshot)
                    }
                    return (200, ControlController.ok(message: "refreshed"))
                case ("POST", "/restart"):
                    supervisor.restartAll()
                    await state.setStatus(supervisor.status())
                    return (200, ControlController.ok(message: "restarted"))
                default:
                    return (404, Data("{\"error\":\"not_found\"}".utf8))
                }
            }
            server.start()

            Task.detached {
                while true {
                    supervisor.checkAndRecover()
                    let status = supervisor.status()
                    await state.setStatus(status)
                    for provider in CliProvider.allCases {
                        let snapshot = await aggregator.snapshot(for: provider, runtimeOnline: status.online)
                        await state.setSnapshot(snapshot)
                    }
                    try? await Task.sleep(nanoseconds: UInt64(appConfig.polling.seconds) * 1_000_000_000)
                }
            }

            // Keep process alive in async main without leaking a continuation.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        } catch {
            fputs("Runtime agent failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
