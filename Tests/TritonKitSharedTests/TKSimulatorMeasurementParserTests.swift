import XCTest
import TritonKitShared

final class TKSimulatorMeasurementParserTests: XCTestCase {
    func testRSSIsConvertedFromKiBToBytes() throws {
        let value = try TKSimulatorMeasurementParser.measurement(udid: "fixture", psOutput: "PID RSS\n10 2\n11 3\n")
        XCTAssertEqual(value.memoryBytes, 5120)
        XCTAssertEqual(value.processCount, 2)
    }

    func testRejectsMissingMalformedNegativeAndDuplicateSamples() {
        for output in ["", "PID RSS", "permission denied", "10 1\n11 missing", "10 -1", "0 1", "10 2\n10 3", "10 9,000"] {
            XCTAssertThrowsError(try TKSimulatorMeasurementParser.parsePS(output), output)
        }
    }

    func testOverflowDoesNotTrapOrWrap() {
        XCTAssertThrowsError(try TKSimulatorMeasurementParser.parsePS("10 9223372036854775807"))
        XCTAssertThrowsError(try TKSimulatorMeasurementParser.measurement(udid: "fixture", psOutput: "10 9007199254740991\n11 9007199254740991"))
    }
}
