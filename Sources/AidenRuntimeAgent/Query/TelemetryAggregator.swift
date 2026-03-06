import Foundation
import AidenShared

struct TelemetryAggregator {
    let vmClient: VmClient
    let codexLogClient: CodexLogClient?

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
            let vmInput = try await vmClient.queryValue(MetricsQueryBuilder.inputTokens(serviceName: service))
            let vmOutput = try await vmClient.queryValue(MetricsQueryBuilder.outputTokens(serviceName: service))
            let vmUserSample = try await vmClient.queryLatestUser(MetricsQueryBuilder.currentUser(serviceName: service))
            let fallbackSample = codexFallback(provider: provider, vmInput: vmInput, vmOutput: vmOutput, vmUser: vmUserSample?.email)
            
            let user = vmUserSample?.email ?? fallbackSample?.email ?? "Unknown"
            
            // Get activity range (earliest and latest activity timestamps)
            let activityRange = try await queryActivityRange(
                provider: provider,
                service: service,
                userEmail: user
            )

            let input = vmInput ?? fallbackSample?.inputTokens
            let output = vmOutput ?? fallbackSample?.outputTokens
            
            let activeDays = Self.calculateActiveDays(
                earliest: activityRange.earliest,
                latest: activityRange.latest,
                fallbackTimestamp: fallbackSample?.timestamp.timeIntervalSince1970
            )

            let cost = ((input ?? 0) * 0.000001) + ((output ?? 0) * 0.000002)
            let contextM = input.map { $0 / 1_000_000.0 }
            let contextPct = contextM.map { min(100, ($0 / 1.0) * 100.0) }

            return TelemetrySnapshot(
                provider: provider,
                inputTokens: input,
                outputTokens: output,
                currentUserEmail: user,
                userActiveDays: activeDays,
                costUsd: cost,
                contextM: contextM,
                contextPercent: contextPct,
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

    private func codexFallback(
        provider: CliProvider,
        vmInput: Double?,
        vmOutput: Double?,
        vmUser: String?
    ) -> CodexLogClient.UsageSample? {
        guard provider == .codex else { return nil }
        let vmHasData = vmInput != nil || vmOutput != nil || (vmUser?.isEmpty == false)
        guard !vmHasData else { return nil }
        return codexLogClient?.latestUsage()
    }

    private func queryActivityRange(
        provider: CliProvider,
        service: String,
        userEmail: String
    ) async throws -> (earliest: Double?, latest: Double?) {
        guard userEmail != "Unknown", !userEmail.isEmpty else { return (nil, nil) }
        
        let latestQuery = MetricsQueryBuilder.latestActivityTime(serviceName: service, userEmail: userEmail)
        let earliestQuery = MetricsQueryBuilder.earliestActivityTime(serviceName: service, userEmail: userEmail)
        
        async let latest = vmClient.queryEpochSeconds(latestQuery)
        async let earliest = vmClient.queryEpochSeconds(earliestQuery)
        
        return try await (earliest, latest)
    }

    static func calculateActiveDays(earliest: Double?, latest: Double?, fallbackTimestamp: Double?) -> Int? {
        let tStart = earliest ?? fallbackTimestamp
        let tEnd = latest ?? fallbackTimestamp
        
        guard let start = tStart, let end = tEnd else { return nil }
        let span = max(0, end - start)
        return Int(floor(span / 86_400.0)) + 1
    }
}
