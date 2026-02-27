#if canImport(XCTest)
import XCTest
@testable import AidenShared

final class ConfigLoaderTests: XCTestCase {
    func testDefaultConfigWhenFileMissing() throws {
        let config = try ConfigLoader.load(from: "/tmp/non-existent-aiden-config.json")
        XCTAssertEqual(config.agent.host, "127.0.0.1")
        XCTAssertEqual(config.polling.seconds, 5)
    }
}
#endif
