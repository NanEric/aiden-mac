import Foundation
import AidenShared

enum StatusController {
    static func encode(_ status: RuntimeStatus) -> Data {
        (try? JSONEncoder().encode(status)) ?? Data("{}".utf8)
    }
}
