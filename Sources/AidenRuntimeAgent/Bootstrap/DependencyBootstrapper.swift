import Foundation

struct DependencyBootstrapper {
    private let verifier = DependencyVerifier()

    func verifyInstalled(collector: URL, vm: URL) throws {
        if !verifier.verifyExecutable(at: collector) {
            throw NSError(domain: "AidenRuntimeAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "Collector binary missing or not executable"])
        }
        if !verifier.verifyExecutable(at: vm) {
            throw NSError(domain: "AidenRuntimeAgent", code: 2, userInfo: [NSLocalizedDescriptionKey: "VictoriaMetrics binary missing or not executable"])
        }
    }
}
