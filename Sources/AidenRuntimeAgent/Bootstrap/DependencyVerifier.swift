import Foundation

struct DependencyVerifier {
    func verifyExecutable(at url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }
}
