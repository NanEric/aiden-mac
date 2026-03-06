#if canImport(XCTest)
import XCTest
@testable import AidenRuntimeAgent

final class MetricsQueryBuilderTests: XCTestCase {
    func testBuildInputQuery() {
        let q = MetricsQueryBuilder.inputTokens(serviceName: "codex-cli")
        XCTAssertTrue(q.contains("gen_ai_token_type=\"input\""))
        XCTAssertTrue(q.contains("job=\"codex-cli\""))
    }

    func testBuildLatestActivityTimeQueryForGemini() {
        let q = MetricsQueryBuilder.latestActivityTime(
            serviceName: "gemini-cli",
            userEmail: "u@example.com",
            lookbackDays: 365
        )
        XCTAssertTrue(q.contains("max_over_time"))
        XCTAssertTrue(q.contains("job=\"gemini-cli\""))
        XCTAssertTrue(q.contains("user_email=\"u@example.com\""))
        XCTAssertTrue(q.contains("[365d:1h]"))
    }

    func testBuildEarliestActivityTimeQueryForGemini() {
        let q = MetricsQueryBuilder.earliestActivityTime(
            serviceName: "gemini-cli",
            userEmail: "u@example.com",
            lookbackDays: 365
        )
        XCTAssertTrue(q.contains("min_over_time"))
        XCTAssertTrue(q.contains("job=\"gemini-cli\""))
        XCTAssertTrue(q.contains("user_email=\"u@example.com\""))
        XCTAssertTrue(q.contains("[365d:1h]"))
    }
}
#endif
