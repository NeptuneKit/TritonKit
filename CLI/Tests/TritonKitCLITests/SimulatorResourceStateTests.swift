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
        for text in ["", "permission denied", "disabled services = {", "{\nunknown\n}", "{\n\"a\" => true\n}\n}", "{\n\"a\" => unknown\n}"] {
            XCTAssertThrowsError(try SimulatorResourceOverrideState.parse(text))
        }
    }

    func testDuplicateLabelsAreRejected() {
        XCTAssertThrowsError(try SimulatorResourceOverrideState.parse("{\n\"a\" => true\n\"a\" => false\n}"))
    }

    func testEmptyMapIsValid() throws {
        XCTAssertEqual(try SimulatorResourceOverrideState.parse("disabled services = {\n}").overrides, [:])
    }

    func testParsesIndentedRealLaunchctlOutput() throws {
        // Captured print-disabled output: header and closing brace are tab-indented.
        let output = "\n" + """
        \tdisabled services = {
        \t\t"com.apple.nanonewscd" => enabled
        \t\t"com.apple.companionmessagesd" => enabled
        \t\t"com.apple.bulletindistributord" => enabled
        \t\t"com.apple.security.otpaird" => enabled
        \t\t"com.apple.brook.brookcompaniond" => enabled
        \t\t"com.apple.NPKCompanionAgent" => enabled
        \t\t"com.apple.nanomapscd" => enabled
        \t\t"com.apple.pairedsyncd" => enabled
        \t\t"com.apple.eventkitsyncd" => enabled
        \t\t"com.apple.companionfindlocallyd" => enabled
        \t\t"com.apple.appconduitd" => enabled
        \t\t"com.apple.schooltimed" => enabled
        \t\t"com.apple.nanosystemsettingsd" => enabled
        \t\t"com.apple.companionappd" => enabled
        \t\t"com.apple.nanoappregistryd" => enabled
        \t\t"com.apple.pairedunlockd" => enabled
        \t\t"com.apple.addressbooksyncd" => enabled
        \t}
        """
        let state = try SimulatorResourceOverrideState.parse(output)
        XCTAssertEqual(state.overrides.count, 17)
        XCTAssertTrue(state.overrides.values.allSatisfy { !$0 })
        XCTAssertEqual(state.overrides["com.apple.nanonewscd"], false)
        XCTAssertEqual(state.overrides["com.apple.addressbooksyncd"], false)
    }

    func testIndentedWrappersDoNotRelaxContentValidation() {
        for text in [
            "\tdisabled services = {\n\t\"a\" => disabled trailing\n\t}",
            "\tdisabled services = {\n\t\"a\" => unknown\n\t}",
            "\tdisabled services = {\n\t\"a\" => true\n\t\"a\" => false\n\t}",
            "\tdisabled services = { extra\n\t}",
            "\tdisabled services = {\n\t} trailing",
        ] {
            XCTAssertThrowsError(try SimulatorResourceOverrideState.parse(text))
        }
    }

    func testWhitespaceAroundBothWrapperFormatsIsAccepted() throws {
        for header in ["{", "disabled services = {"] {
            let state = try SimulatorResourceOverrideState.parse("\t\(header) \t\n\t\"a\" => disabled\n\t} \t\n")
            XCTAssertEqual(state.overrides, ["a": true])
        }
    }
}
