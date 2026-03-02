import Foundation
import Network
import AidenShared

final class RuntimeSupervisor {
    private let collector: ProcessService
    private let vm: ProcessService
    private var lastError: String?

    init(config: AgentConfig) {
        self.collector = ProcessService(executable: config.collectorBinary, arguments: config.collectorArgs)
        self.vm = ProcessService(executable: config.vmBinary, arguments: config.vmArgs)
    }

    func ensureStarted() {
        vm.startIfNeeded()
        collector.startIfNeeded()
        lastError = collector.lastError ?? vm.lastError
    }

    func restartAll() {
        vm.restart()
        collector.restart()
        lastError = collector.lastError ?? vm.lastError
    }

    func status() -> RuntimeStatus {
        let collectorHealthy = collector.isRunning && isCollectorReachable()
        let vmHealthy = vm.isRunning && isVmHealthy()
        let online = collectorHealthy && vmHealthy
        if !collectorHealthy, collector.lastError == nil {
            lastError = "Collector endpoint 127.0.0.1:4317 is unreachable"
        } else if !vmHealthy, vm.lastError == nil {
            lastError = "VictoriaMetrics health endpoint http://127.0.0.1:18428/health is unreachable"
        } else {
            lastError = collector.lastError ?? vm.lastError
        }
        return RuntimeStatus(
            online: online,
            collectorHealthy: collectorHealthy,
            vmHealthy: vmHealthy,
            lastError: lastError,
            updatedAt: Date()
        )
    }

    private func isVmHealthy() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:18428/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5

        let semaphore = DispatchSemaphore(value: 0)
        var healthy = false

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { return }
            guard let data, let body = String(data: data, encoding: .utf8) else { return }
            healthy = body.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 1.0)
        return healthy
    }

    private func isCollectorReachable() -> Bool {
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: 4317)
        let connection = NWConnection(to: endpoint, using: .tcp)
        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false
        var finished = false

        connection.stateUpdateHandler = { state in
            guard !finished else { return }
            switch state {
            case .ready:
                reachable = true
                finished = true
                connection.cancel()
                semaphore.signal()
            case .failed, .cancelled:
                finished = true
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .utility))
        let waitResult = semaphore.wait(timeout: .now() + 1.0)
        if waitResult == .timedOut {
            connection.cancel()
            return false
        }
        return reachable
    }
}
