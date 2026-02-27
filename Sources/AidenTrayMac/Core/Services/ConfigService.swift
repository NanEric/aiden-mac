import Foundation
import AidenShared

final class ConfigService {
    func load() -> AppConfig {
        let path = ProcessInfo.processInfo.environment["AIDEN_CONFIG_PATH"]
        return (try? ConfigLoader.load(from: path)) ?? .default
    }
}
