import Foundation
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
        let collectorHealthy = collector.isRunning
        let vmHealthy = vm.isRunning
        let online = collectorHealthy && vmHealthy
        return RuntimeStatus(
            online: online,
            collectorHealthy: collectorHealthy,
            vmHealthy: vmHealthy,
            lastError: lastError,
            updatedAt: Date()
        )
    }
}
