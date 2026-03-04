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

    func testActiveDaysUsesFloorWholeDays() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let twoDaysAndOneHourAgo = now.timeIntervalSince1970 - (2 * 86_400) - 3_600
        let activeDays = TelemetryAggregator.activeDays(sinceEpochSeconds: twoDaysAndOneHourAgo, now: now)
        XCTAssertEqual(activeDays, 2)
    }

    func testActiveDaysReturnsNilWhenTimestampMissing() {
        XCTAssertNil(TelemetryAggregator.activeDays(sinceEpochSeconds: nil, now: Date()))
    }

    func testLatestActivityTimestampUsesGeminiActivityEpoch() {
        let vmUser = VmClient.UserSample(email: "user@example.com", timestampSeconds: 1_700_000_000)
        let ts = TelemetryAggregator.latestActivityTimestamp(
            provider: .gemini,
            vmUserSample: vmUser,
            fallbackSample: nil,
            geminiActivityEpoch: 1_699_000_000
        )
        XCTAssertEqual(ts, 1_699_000_000)
    }

    func testLatestActivityTimestampGeminiReturnsNilWhenNoActivityEpoch() {
        let vmUser = VmClient.UserSample(email: "user@example.com", timestampSeconds: 1_700_000_000)
        let ts = TelemetryAggregator.latestActivityTimestamp(
            provider: .gemini,
            vmUserSample: vmUser,
            fallbackSample: nil,
            geminiActivityEpoch: nil
        )
        XCTAssertNil(ts)
    }
}
#endif
