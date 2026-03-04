#if canImport(XCTest)
import XCTest
@testable import AidenRuntimeAgent

final class VmClientTests: XCTestCase {
    func testParseLatestUserResponseUsesTimestampValueFromValueIndexOne() throws {
        let data = Data(
            """
            {
              "status": "success",
              "data": {
                "resultType": "vector",
                "result": [
                  {
                    "metric": {"user_email": "test@example.com"},
                    "value": [1700000100.0, "1700000000"]
                  }
                ]
              }
            }
            """.utf8
        )

        let sample = VmClient.parseLatestUserResponse(data)
        XCTAssertEqual(sample?.email, "test@example.com")
        XCTAssertEqual(sample?.timestampSeconds, 1_700_000_000)
    }

    func testParseLatestUserResponseReturnsNilWhenValueMissing() {
        let data = Data(
            """
            {
              "status": "success",
              "data": {
                "resultType": "vector",
                "result": [
                  {
                    "metric": {"user_email": "test@example.com"}
                  }
                ]
              }
            }
            """.utf8
        )

        XCTAssertNil(VmClient.parseLatestUserResponse(data))
    }

    func testParseLatestUserResponseReturnsNilWhenTimestampInvalid() {
        let data = Data(
            """
            {
              "status": "success",
              "data": {
                "resultType": "vector",
                "result": [
                  {
                    "metric": {"user_email": "test@example.com"},
                    "value": [1700000100.0, "not-a-number"]
                  }
                ]
              }
            }
            """.utf8
        )

        XCTAssertNil(VmClient.parseLatestUserResponse(data))
    }

    func testParseEpochSecondsResponseUsesValueIndexOne() {
        let data = Data(
            """
            {
              "status": "success",
              "data": {
                "resultType": "vector",
                "result": [
                  {
                    "metric": {},
                    "value": [1700000100.0, "1700000000"]
                  }
                ]
              }
            }
            """.utf8
        )
        XCTAssertEqual(VmClient.parseEpochSecondsResponse(data), 1_700_000_000)
    }

    func testParseEpochSecondsResponseReturnsNilWhenInvalid() {
        let data = Data(
            """
            {
              "status": "success",
              "data": {
                "resultType": "vector",
                "result": [
                  {
                    "metric": {},
                    "value": [1700000100.0, "not-a-number"]
                  }
                ]
              }
            }
            """.utf8
        )
        XCTAssertNil(VmClient.parseEpochSecondsResponse(data))
    }
}
#endif
