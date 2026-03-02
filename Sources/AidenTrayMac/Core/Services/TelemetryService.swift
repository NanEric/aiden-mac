import Foundation
import AidenShared

@MainActor
final class TelemetryService {
    private let client: RuntimeAgentClient
    private var timer: Timer?
    private var lastGoodSnapshots: [CliProvider: TelemetrySnapshot] = [:]

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
            var latestSnapshots: [CliProvider: TelemetrySnapshot] = [:]
            for provider in CliProvider.allCases {
                latestSnapshots[provider] = try? await client.telemetry(provider: provider)
            }
            return (status, mergeSnapshots(status: status, latestSnapshots: latestSnapshots))
        } catch {
            return (nil, [:])
        }
    }

    private func mergeSnapshots(
        status: RuntimeStatus,
        latestSnapshots: [CliProvider: TelemetrySnapshot]
    ) -> [CliProvider: TelemetrySnapshot] {
        let now = Date()
        var merged: [CliProvider: TelemetrySnapshot] = [:]

        for provider in CliProvider.allCases {
            let latest = latestSnapshots[provider]

            if let latest, hasBusinessData(latest) {
                lastGoodSnapshots[provider] = latest
            }

            let baseSnapshot: TelemetrySnapshot?
            if let latest, hasBusinessData(latest) {
                baseSnapshot = latest
            } else if let cached = lastGoodSnapshots[provider] {
                baseSnapshot = cached
            } else {
                baseSnapshot = latest
            }

            guard let snapshot = baseSnapshot else { continue }
            merged[provider] = normalized(snapshot: snapshot, online: status.online, updatedAt: now)
        }

        return merged
    }

    private func hasBusinessData(_ snapshot: TelemetrySnapshot) -> Bool {
        snapshot.inputTokens != nil ||
        snapshot.outputTokens != nil ||
        snapshot.currentUserEmail != "Unknown" ||
        snapshot.contextM != nil ||
        snapshot.contextPercent != nil
    }

    private func normalized(snapshot: TelemetrySnapshot, online: Bool, updatedAt: Date) -> TelemetrySnapshot {
        TelemetrySnapshot(
            provider: snapshot.provider,
            inputTokens: snapshot.inputTokens,
            outputTokens: snapshot.outputTokens,
            currentUserEmail: snapshot.currentUserEmail,
            userActiveDays: snapshot.userActiveDays,
            costUsd: snapshot.costUsd,
            contextM: snapshot.contextM,
            contextPercent: snapshot.contextPercent,
            status: online ? "ONLINE" : "OFFLINE",
            updatedAt: updatedAt
        )
    }
}
