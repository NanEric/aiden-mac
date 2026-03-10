import Foundation

public struct RuntimeStatus: Codable, Sendable {
    public let online: Bool
    public let collectorHealthy: Bool
    public let vmHealthy: Bool
    public let lastError: String?
    public let message: String?
    public let updatedAt: Date

    public init(online: Bool, collectorHealthy: Bool, vmHealthy: Bool, lastError: String?, message: String? = nil, updatedAt: Date) {
        self.online = online
        self.collectorHealthy = collectorHealthy
        self.vmHealthy = vmHealthy
        self.lastError = lastError
        self.message = message
        self.updatedAt = updatedAt
    }
}
