import XCTest
@testable import TritonKitCLI

final class SimulatorResourceStateTests: XCTestCase {
    func testParsesBothLaunchdFormatsAndPreservesEnabledOverrides() throws {
        let state = try SimulatorResourceOverrideState.parse("""
        disabled services = {
            "com.apple.a" => disabled
            "com.apple.b" => enabled
            "com.apple.c" => true
            "com.apple.d" => false
        }
        """)
        XCTAssertEqual(state.overrides, ["com.apple.a": true, "com.apple.b": false,
                                         "com.apple.c": true, "com.apple.d": false])
        XCTAssertNil(state.overrides["com.apple.absent"])
    }

    func testMalformedOrTruncatedOutputCannotClaimStock() {
        for text in ["", "permission denied", "disabled services = {", "{\n\"a\" => unknown\n}"] {
            XCTAssertThrowsError(try SimulatorResourceOverrideState.parse(text))
        }
    }

    func testDuplicateLabelsAreRejected() {
        XCTAssertThrowsError(try SimulatorResourceOverrideState.parse("{\n\"a\" => true\n\"a\" => false\n}"))
    }

    func testEmptyMapIsValid() throws {
        XCTAssertEqual(try SimulatorResourceOverrideState.parse("disabled services = {\n}").overrides, [:])
    }
}
