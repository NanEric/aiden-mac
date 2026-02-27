import Foundation
import AidenShared

actor AgentState {
    private(set) var runtimeStatus: RuntimeStatus
    private var snapshots: [CliProvider: TelemetrySnapshot] = [:]

    init() {
        runtimeStatus = RuntimeStatus(online: false, collectorHealthy: false, vmHealthy: false, lastError: nil, updatedAt: Date())
    }

    func setStatus(_ status: RuntimeStatus) {
        runtimeStatus = status
    }

    func setSnapshot(_ snapshot: TelemetrySnapshot) {
        snapshots[snapshot.provider] = snapshot
    }

    func getStatus() -> RuntimeStatus { runtimeStatus }

    func getSnapshot(provider: CliProvider) -> TelemetrySnapshot? {
        snapshots[provider]
    }
}
