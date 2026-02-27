import Foundation
import AidenShared

@MainActor
final class TelemetryService {
    private let client: RuntimeAgentClient
    private var timer: Timer?

    init(client: RuntimeAgentClient = RuntimeAgentClient()) {
        self.client = client
    }

    func startPolling(seconds: Int, onTick: @escaping @MainActor (RuntimeStatus, [CliProvider: TelemetrySnapshot]) -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let result = await self.fetchAll()
                if let status = result.0 {
                    onTick(status, result.1)
                }
            }
        }

        Task { @MainActor in
            let result = await fetchAll()
            if let status = result.0 {
                onTick(status, result.1)
            }
        }
    }

    func refreshNow() async {
        await client.refresh()
    }

    private func fetchAll() async -> (RuntimeStatus?, [CliProvider: TelemetrySnapshot]) {
        do {
            let status = try await client.status()
            var snapshots: [CliProvider: TelemetrySnapshot] = [:]
            for provider in CliProvider.allCases {
                snapshots[provider] = try? await client.telemetry(provider: provider)
            }
            return (status, snapshots)
        } catch {
            return (nil, [:])
        }
    }
}
