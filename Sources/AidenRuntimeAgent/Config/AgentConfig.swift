import Foundation
import AidenShared

struct AgentConfig {
    let app: AppConfig

    var host: String { app.agent.host }
    var port: Int { app.agent.port }

    var runtimeRoot: URL { URL(fileURLWithPath: app.runtime.rootPath) }

    var collectorBinary: URL {
        runtimeRoot.appendingPathComponent(app.runtime.collectorPath)
    }

    var vmBinary: URL {
        runtimeRoot.appendingPathComponent(app.runtime.vmPath)
    }

    var collectorArgs: [String] { app.runtime.collectorArgs }
    var vmArgs: [String] { app.runtime.vmArgs }
}
