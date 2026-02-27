import Foundation

public struct TelemetrySnapshot: Codable, Sendable {
    public let provider: CliProvider
    public let inputTokens: Double?
    public let outputTokens: Double?
    public let currentUserEmail: String
    public let userActiveDays: Int?
    public let costUsd: Double
    public let contextM: Double?
    public let contextPercent: Double?
    public let status: String
    public let updatedAt: Date

    public init(
        provider: CliProvider,
        inputTokens: Double?,
        outputTokens: Double?,
        currentUserEmail: String,
        userActiveDays: Int?,
        costUsd: Double,
        contextM: Double?,
        contextPercent: Double?,
        status: String,
        updatedAt: Date
    ) {
        self.provider = provider
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.currentUserEmail = currentUserEmail
        self.userActiveDays = userActiveDays
        self.costUsd = costUsd
        self.contextM = contextM
        self.contextPercent = contextPercent
        self.status = status
        self.updatedAt = updatedAt
    }
}
