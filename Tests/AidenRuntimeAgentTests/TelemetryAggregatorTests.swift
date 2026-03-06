#if canImport(XCTest)
import XCTest
@testable import AidenRuntimeAgent
@testable import AidenShared

final class TelemetryAggregatorTests: XCTestCase {
    func testOfflineSnapshotUsesFallbackValues() async {
        let aggregator = TelemetryAggregator(vmClient: VmClient(), codexLogClient: nil)
        let snapshot = await aggregator.snapshot(for: .gemini, runtimeOnline: false)
        XCTAssertEqual(snapshot.status, "OFFLINE")
        XCTAssertEqual(snapshot.currentUserEmail, "Unknown")
        XCTAssertNil(snapshot.inputTokens)
        XCTAssertNil(snapshot.userActiveDays)
    }

    func testCalculateActiveDaysWithSpan() {
        let t1 = 1_700_000_000.0 // Day 1
        let t2 = t1 + 86_400.0 * 2.5 // 2.5 days later (should be 3rd day)
        
        let days = TelemetryAggregator.calculateActiveDays(earliest: t1, latest: t2, fallbackTimestamp: nil)
        XCTAssertEqual(days, 3) 
    }

    func testCalculateActiveDaysSameMomentIsOneDay() {
        let t = 1_700_000_000.0
        let days = TelemetryAggregator.calculateActiveDays(earliest: t, latest: t, fallbackTimestamp: nil)
        XCTAssertEqual(days, 1)
    }

    func testCalculateActiveDaysReturnsNilWhenNoData() {
        let days = TelemetryAggregator.calculateActiveDays(earliest: nil, latest: nil, fallbackTimestamp: nil)
        XCTAssertNil(days)
    }
}
#endif
