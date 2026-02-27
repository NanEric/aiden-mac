import Foundation
import AidenShared

struct DashboardState {
    var selectedProvider: CliProvider = .gemini
    var snapshots: [CliProvider: TelemetrySnapshot] = [:]
    var runtimeStatus: RuntimeStatus?
    var lastUpdatedAt: Date?
}
