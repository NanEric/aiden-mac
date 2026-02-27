#if canImport(XCTest)
import XCTest
@testable import AidenRuntimeAgent
@testable import AidenShared

final class TelemetryAggregatorTests: XCTestCase {
    func testOfflineSnapshotUsesFallbackValues() async {
        let aggregator = TelemetryAggregator(vmClient: VmClient())
        let snapshot = await aggregator.snapshot(for: .gemini, runtimeOnline: false)
        XCTAssertEqual(snapshot.status, "OFFLINE")
        XCTAssertEqual(snapshot.currentUserEmail, "Unknown")
        XCTAssertNil(snapshot.inputTokens)
    }
}
#endif
