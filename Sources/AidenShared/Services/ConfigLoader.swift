import Foundation

public enum ConfigLoader {
    public static func load(from path: String?) throws -> AppConfig {
        guard let path, FileManager.default.fileExists(atPath: path) else {
            return .default
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        return try decoder.decode(AppConfig.self, from: data)
    }
}
