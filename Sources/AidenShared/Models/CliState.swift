import Foundation

public struct CliState: Codable, Sendable {
    public let provider: CliProvider
    public let installed: Bool
    public let enabled: Bool

    public init(provider: CliProvider, installed: Bool, enabled: Bool) {
        self.provider = provider
        self.installed = installed
        self.enabled = enabled
    }

    public var available: Bool { installed && enabled }
}
