import Foundation
import AidenShared

enum TelemetryController {
    static func encode(_ snapshot: TelemetrySnapshot) -> Data {
        (try? JSONEncoder().encode(snapshot)) ?? Data("{}".utf8)
    }
}
