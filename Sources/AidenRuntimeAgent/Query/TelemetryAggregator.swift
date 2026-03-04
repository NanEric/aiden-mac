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
            // Keep "Current User Email" source unchanged; use it as anchor for Gemini active-days lookup.
            let geminiActivityEpoch = try await queryGeminiActivityEpoch(
                provider: provider,
                service: service,
                currentUserEmail: vmUserSample?.email
            )

            let input = vmInput ?? fallbackSample?.inputTokens
            let output = vmOutput ?? fallbackSample?.outputTokens
            let user = vmUserSample?.email ?? fallbackSample?.email ?? "Unknown"
            let latestTimestamp = Self.latestActivityTimestamp(
                provider: provider,
                vmUserSample: vmUserSample,
                fallbackSample: fallbackSample,
                geminiActivityEpoch: geminiActivityEpoch
            )
            let activeDays = Self.activeDays(sinceEpochSeconds: latestTimestamp, now: Date())

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

    private func queryGeminiActivityEpoch(
        provider: CliProvider,
        service: String,
        currentUserEmail: String?
    ) async throws -> Double? {
        guard provider == .gemini else { return nil }
        guard let currentUserEmail, !currentUserEmail.isEmpty else { return nil }
        let query = MetricsQueryBuilder.latestActivityTime(serviceName: service, userEmail: currentUserEmail)
        return try await vmClient.queryEpochSeconds(query)
    }

    static func latestActivityTimestamp(
        provider: CliProvider,
        vmUserSample: VmClient.UserSample?,
        fallbackSample: CodexLogClient.UsageSample?,
        geminiActivityEpoch: Double?
    ) -> Double? {
        if provider == .gemini {
            return geminiActivityEpoch
        }
        return vmUserSample?.timestampSeconds ?? fallbackSample?.timestamp.timeIntervalSince1970
    }

    static func activeDays(sinceEpochSeconds timestamp: Double?, now: Date) -> Int? {
        guard let timestamp else { return nil }
        let delta = max(0, now.timeIntervalSince1970 - timestamp)
        return Int(floor(delta / 86_400.0))
    }
}
