import Foundation

public enum CliProvider: String, Codable, CaseIterable, Sendable {
    case gemini
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .codex: return "Codex"
        case .claude: return "Claude Code"
        }
    }

    public var serviceName: String {
        switch self {
        case .gemini: return "gemini-cli"
        case .codex: return "codex-cli"
        case .claude: return "claude-code"
        }
    }
}
