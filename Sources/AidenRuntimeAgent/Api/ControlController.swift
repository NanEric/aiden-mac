import Foundation

enum ControlController {
    static func ok(message: String) -> Data {
        Data("{\"ok\":true,\"message\":\"\(message)\"}".utf8)
    }
}
