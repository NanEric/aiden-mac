import Foundation

public struct RuntimeStatus: Codable, Sendable {
    public let online: Bool
    public let collectorHealthy: Bool
    public let vmHealthy: Bool
    public let lastError: String?
    public let updatedAt: Date

    public init(online: Bool, collectorHealthy: Bool, vmHealthy: Bool, lastError: String?, updatedAt: Date) {
        self.online = online
        self.collectorHealthy = collectorHealthy
        self.vmHealthy = vmHealthy
        self.lastError = lastError
        self.updatedAt = updatedAt
    }
}
