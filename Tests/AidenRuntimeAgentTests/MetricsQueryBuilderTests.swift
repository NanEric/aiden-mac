#if canImport(XCTest)
import XCTest
@testable import AidenRuntimeAgent

final class MetricsQueryBuilderTests: XCTestCase {
    func testBuildInputQuery() {
        let q = MetricsQueryBuilder.inputTokens(serviceName: "codex-cli")
        XCTAssertTrue(q.contains("gen_ai.token.type=\"input\""))
        XCTAssertTrue(q.contains("service.name=\"codex-cli\""))
    }
}
#endif
