import Foundation
import AidenShared

struct TelemetryAggregator {
    let vmClient: VmClient

    func snapshot(for provider: CliProvider, runtimeOnline: Bool) async -> TelemetrySnapshot {
        guard runtimeOnline else {
            return TelemetrySnapshot(
                provider: provider,
                inputTokens: nil,
                outputTokens: nil,
                currentUserEmail: "Unknown",
                userActiveDays: nil,
                costUsd: 0,
                contextM: nil,
                contextPercent: nil,
                status: "OFFLINE",
                updatedAt: Date()
            )
        }

        let service = provider.serviceName
        do {
            let input = try await vmClient.queryValue(MetricsQueryBuilder.inputTokens(serviceName: service))
            let output = try await vmClient.queryValue(MetricsQueryBuilder.outputTokens(serviceName: service))
            let userSample = try await vmClient.queryLatestUser(MetricsQueryBuilder.currentUser(serviceName: service))
            let user = userSample?.email ?? "Unknown"
            let knownUser = user != "Unknown"
            let activeDays: Int? = {
                guard let timestamp = userSample?.timestampSeconds else { return nil }
                let delta = max(0, Date().timeIntervalSince1970 - timestamp)
                return Int(floor(delta / 86_400.0))
            }()

            let cost = ((input ?? 0) * 0.000001) + ((output ?? 0) * 0.000002)
            let contextM = input.map { $0 / 1_000_000.0 }
            let contextPct = contextM.map { min(100, ($0 / 1.0) * 100.0) }

            return TelemetrySnapshot(
                provider: provider,
                inputTokens: knownUser ? input : nil,
                outputTokens: knownUser ? output : nil,
                currentUserEmail: user,
                userActiveDays: knownUser ? activeDays : nil,
                costUsd: cost,
                contextM: knownUser ? contextM : nil,
                contextPercent: knownUser ? contextPct : nil,
                status: "ONLINE",
                updatedAt: Date()
            )
        } catch {
            return TelemetrySnapshot(
                provider: provider,
                inputTokens: nil,
                outputTokens: nil,
                currentUserEmail: "Unknown",
                userActiveDays: nil,
                costUsd: 0,
                contextM: nil,
                contextPercent: nil,
                status: "OFFLINE",
                updatedAt: Date()
            )
        }
    }
}
