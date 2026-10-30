import Foundation
import XCTest
@testable import TritonKitCLI

final class EmulatorResourceHostMemoryTests: XCTestCase {
    private let android = EmulatorResourceIdentity(platform: .android, target: "emulator-5556", instance: "Fixture_API_34", image: "fixture", bootID: "boot")
    private let harmony = EmulatorResourceIdentity(platform: .harmony, target: "127.0.0.1:5555", instance: "127.0.0.1:5555:Phone", image: "fixture", bootID: "boot")
    private let androidArguments = ["/SDK With Spaces/qemu-system-aarch64-headless", "@Fixture_API_34", "-port", "5556"]
    private let harmonyArguments = ["/Applications/DevEco Studio.app/Contents/Emulator", "-start", "Phone API 22", "-hdcPort", "5555"]
    private enum FixtureFailure: Error { case unavailable }

    func testAndroidSamplesOnlyVerifiedMainProcessAndExcludesChildren() throws {
        var sampled: [Int32] = []
        let result = EmulatorResourceHostMemory.measure(identity: android,
            processList: { [self.entry(10, "qemu-system-aarch64-headless @Fixture_API_34 -port 5556"), self.entry(11, "child", parent: 10)] },
            arguments: { pid in XCTAssertEqual(pid, 10); return self.androidArguments },
            sample: { pid in sampled.append(pid); return 12_345 })
        XCTAssertEqual(result.metric, "host_vm_main_process_physical_footprint_bytes")
        XCTAssertEqual(result.pid, 10)
        XCTAssertEqual(result.physicalFootprintBytes, 12_345)
        XCTAssertFalse(result.partial)
        XCTAssertTrue(result.reason?.contains("excludes child") == true)
        XCTAssertEqual(sampled, [10])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        XCTAssertEqual(json["physicalFootprintBytes"] as? Int, 12_345)
    }

    func testHarmonyUsesExactPortAndPreservesHVDNameContainingSpaces() {
        for flag in ["-start", "-hvd"] {
            var arguments = harmonyArguments
            arguments[1] = flag
            let result = measure(harmony, args: [10: arguments])
            XCTAssertEqual(result.pid, 10)
            XCTAssertEqual(result.physicalFootprintBytes, 42)
            XCTAssertFalse(result.partial)
        }
    }

    func testAndroidRequiresExactExecutablePortAndAVD() {
        let variants = [
            ["/bin/echo"] + Array(androidArguments.dropFirst()),
            ["/sdk/qemu-system-aarch64-headless-imposter"] + Array(androidArguments.dropFirst()),
            [androidArguments[0], "@Wrong_AVD", "-port", "5556"],
            [androidArguments[0], "@Fixture_API_34", "-port", "55560"],
            [androidArguments[0], "@Fixture_API_34", "-port", "5556", "-port", "5558"],
            [androidArguments[0], "@Fixture_API_34", "@Other", "-port", "5556"],
            [androidArguments[0], "@Fixture_API_34", "-port=5556"],
            [androidArguments[0], "@Fixture_API_34", "-port"]
        ]
        for args in variants { assertUnavailable(measure(android, args: [10: args])) }
        var headed = androidArguments
        headed[0] = "/sdk/qemu-system-aarch64"
        XCTAssertEqual(measure(android, args: [10: headed]).pid, 10)
    }

    func testAndroidAutomaticPortUsesUniqueVerifiedAVDAndReportsMatchingBasis() {
        let result = measure(android, args: [10: [androidArguments[0], "@Fixture_API_34", "-no-window"]])
        XCTAssertEqual(result.pid, 10)
        XCTAssertEqual(result.physicalFootprintBytes, 42)
        XCTAssertFalse(result.partial)
        XCTAssertTrue(result.reason?.contains("AVD-only") == true)
        XCTAssertTrue(result.reason?.contains("argv omits -port") == true)
    }

    func testAndroidAVDOptionSamplesExactTargetAndRechecksArguments() {
        let args = [androidArguments[0], "-avd", "Fixture_API_34", "-port", "5556"]
        var reads: [Int32] = []
        var samples: [Int32] = []
        let result = EmulatorResourceHostMemory.measure(identity: android,
            processList: { [self.entry(10, "qemu-system-aarch64-headless -avd Fixture_API_34 -port 5556")] },
            arguments: { pid in reads.append(pid); return args },
            sample: { pid in samples.append(pid); return 12_345 })
        XCTAssertEqual(result.pid, 10)
        XCTAssertEqual(result.physicalFootprintBytes, 12_345)
        XCTAssertFalse(result.partial)
        XCTAssertFalse(result.reason?.contains("AVD-only") == true)
        XCTAssertEqual(reads, [10, 10])
        XCTAssertEqual(samples, [10])
    }

    func testAndroidUnrelatedAVDOptionDoesNotInvalidateVerifiedTarget() {
        for suffix in [["-port", "5558"], ["-no-window"]] {
            let other = [androidArguments[0], "-avd", "Other_API_34"] + suffix
            let result = measure(android, args: [10: androidArguments, 11: other])
            XCTAssertEqual(result.pid, 10)
            XCTAssertFalse(result.partial)
        }
        let optionTarget = [androidArguments[0], "-avd", "Fixture_API_34", "-port", "5556"]
        let result = measure(android, args: [10: optionTarget, 11: [androidArguments[0], "@Other_API_34", "-port", "5558"]])
        XCTAssertEqual(result.pid, 10)
        XCTAssertFalse(result.partial)
    }

    func testAndroidAVDOptionAutomaticPortPreservesIdentityAndAmbiguityRules() {
        let automatic = [androidArguments[0], "-avd", "Fixture_API_34"]
        let result = measure(android, args: [10: automatic])
        XCTAssertEqual(result.pid, 10)
        XCTAssertFalse(result.partial)
        XCTAssertTrue(result.reason?.contains("AVD-only") == true)
        XCTAssertTrue(result.reason?.contains("argv omits -port") == true)
        for duplicate in [automatic, [androidArguments[0], "@Fixture_API_34"], androidArguments,
                          automatic + ["-port", "5558"], [androidArguments[0], "@Fixture_API_34", "-port", "5558"]] {
            assertUnavailable(measure(android, args: [10: automatic, 11: duplicate]))
        }
        assertUnavailable(measure(android, args: [10: [androidArguments[0], "@Fixture_API_34"],
                                                11: automatic + ["-port", "5558"]]))
        assertUnavailable(measure(android, args: [10: androidArguments, 11: automatic + ["-port", "5556"]]))
    }

    func testAndroidRejectsMalformedOrMultipleAVDSelectorsBeforeSampling() {
        let selectors = [
            ["-avd"], ["-avd", ""], ["-avd", "-port", "5556"],
            ["-avd=Fixture_API_34"], ["-avdFixture_API_34"],
            ["-avd", "Fixture_API_34", "-avd", "Fixture_API_34"],
            ["-avd", "Fixture_API_34", "-avd", "Other_API_34"],
            ["@Fixture_API_34", "-avd", "Fixture_API_34"],
            ["-avd", "Other_API_34", "@Fixture_API_34"],
            ["@Fixture_API_34", "-avd=Other_API_34"],
            ["-avd", "Fixture_API_34", "-avd=Other_API_34"],
            ["-avd", "@Fixture_API_34"], ["@"]
        ]
        for selector in selectors {
            let result = EmulatorResourceHostMemory.measure(identity: android,
                processList: { [self.entry(10, "qemu-system-aarch64-headless")] },
                arguments: { _ in [self.androidArguments[0]] + selector },
                sample: { _ in XCTFail("Malformed AVD selector must not be sampled: \(selector)"); return 1 })
            assertUnavailable(result)
        }
        // An unverified second candidate still prevents a false unique match.
        assertUnavailable(measure(android, args: [10: androidArguments,
                                                11: [androidArguments[0], "-avd=Other_API_34"]]))
    }

    func testUnrelatedAVDWithAutomaticPortDoesNotInvalidateExplicitTarget() {
        let result = measure(android, args: [10: androidArguments, 11: [androidArguments[0], "@Dxyer", "-no-window"]])
        XCTAssertEqual(result.pid, 10)
        XCTAssertFalse(result.partial)
        XCTAssertFalse(result.reason?.contains("AVD-only") == true)
        let automatic = measure(android, args: [10: [androidArguments[0], "@Fixture_API_34"], 11: [androidArguments[0], "@Dxyer"]])
        XCTAssertEqual(automatic.pid, 10)
    }

    func testAutomaticPortRejectsUnknownPortFormsAndSameAVDAmbiguity() {
        let automatic = [androidArguments[0], "@Fixture_API_34"]
        for suffix in [["-ports", "5556,5557"], ["-ports=5556,5557"], ["-port=5556"], ["-port"], ["-port", "5556", "-ports", "5556,5557"]] {
            assertUnavailable(measure(android, args: [10: automatic + suffix]))
        }
        assertUnavailable(measure(android, args: [10: automatic, 11: automatic]))
        assertUnavailable(measure(android, args: [10: automatic, 11: androidArguments]))
        // When argv lacks a port, even a second same-AVD process on a different port makes AVD-only selection ambiguous.
        assertUnavailable(measure(android, args: [10: automatic, 11: automatic + ["-port", "5558"]]))
    }

    func testHarmonyRequiresSingleNamedHVDAndExactPort() {
        let variants = [
            ["/sdk/EmulatorHelper", "-start", "Phone API 22", "-hdcPort", "5555"],
            [harmonyArguments[0], "-start", "Phone API 22", "-hdcPort", "55550"],
            [harmonyArguments[0], "-hdcPort", "5555"],
            [harmonyArguments[0], "-start", "", "-hdcPort", "5555"],
            [harmonyArguments[0], "-start", "-hdcPort", "5555"],
            harmonyArguments + ["-hdcPort", "5555"],
            harmonyArguments + ["-hvd", "Other"]
        ]
        for args in variants { assertUnavailable(measure(harmony, args: [10: args])) }
    }

    func testPSDisplayCannotSpoofActualArguments() {
        let result = EmulatorResourceHostMemory.measure(identity: android,
            processList: { [self.entry(10, "qemu-system-aarch64-headless @Fixture_API_34 -port 5556")] },
            arguments: { _ in ["/bin/echo", "qemu-system-aarch64-headless", "@Fixture_API_34", "-port", "5556"] },
            sample: { _ in XCTFail("Must not sample an unverified process"); return 1 })
        assertUnavailable(result)
    }

    func testAmbiguousMainProcessesAreUnavailableWithoutSampling() {
        assertUnavailable(measure(android, args: [10: androidArguments, 11: androidArguments]))
        assertUnavailable(measure(harmony, args: [10: harmonyArguments, 11: harmonyArguments]))
    }

    func testUnreadablePotentialMainProcessPreventsFalseUniqueMatch() {
        let result = EmulatorResourceHostMemory.measure(identity: android,
            processList: { [self.entry(10, "qemu-system-aarch64-headless"), self.entry(11, "qemu-system-aarch64-headless")] },
            arguments: { pid in if pid == 11 { throw FixtureFailure.unavailable }; return self.androidArguments },
            sample: { _ in XCTFail("An unreadable candidate prevents uniqueness proof"); return 1 })
        assertUnavailable(result)
    }

    func testProcessListFailureAndMalformedSnapshotsReturnUnavailable() {
        let failed = EmulatorResourceHostMemory.measure(identity: android, processList: { throw FixtureFailure.unavailable }, arguments: { _ in self.androidArguments }, sample: { _ in 1 })
        assertUnavailable(failed)
        for entries in [[entry(10, "qemu-system-aarch64"), entry(10, "qemu-system-aarch64")], [entry(0, "qemu-system-aarch64")], [entry(10, "qemu-system-aarch64", parent: -1)]] {
            assertUnavailable(EmulatorResourceHostMemory.measure(identity: android, processList: { entries }, arguments: { _ in self.androidArguments }, sample: { _ in 1 }))
        }
    }

    func testSampleFailureAndPIDReuseReturnUnavailable() {
        var calls = 0
        let changed = EmulatorResourceHostMemory.measure(identity: android,
            processList: { [self.entry(10, "qemu-system-aarch64-headless")] },
            arguments: { _ in calls += 1; return calls == 1 ? self.androidArguments : ["/bin/replacement"] },
            sample: { _ in 1 })
        assertUnavailable(changed)
        let failed = EmulatorResourceHostMemory.measure(identity: android,
            processList: { [self.entry(10, "qemu-system-aarch64-headless")] },
            arguments: { _ in self.androidArguments }, sample: { _ in throw FixtureFailure.unavailable })
        assertUnavailable(failed)
    }

    func testInvalidTargetDoesNotReadHostProcesses() {
        for (platform, target) in [(EmulatorResourcePlatform.android, "emulator-5555"), (.android, "emulator-05556"), (.harmony, "192.168.0.1:5555"), (.harmony, "127.0.0.1:05555")] {
            let identity = EmulatorResourceIdentity(platform: platform, target: target, instance: "fixture", image: "image", bootID: "boot")
            let result = EmulatorResourceHostMemory.measure(identity: identity, processList: { XCTFail("Invalid target must fail before host access"); return [] }, arguments: { _ in [] }, sample: { _ in 1 })
            assertUnavailable(result)
        }
    }

    func testProcArgsParserPreservesSpacesEmptyArgumentsAndIgnoresEnvironment() throws {
        let argv = ["custom-argv0", "-start", "Phone API 22", "", "-hdcPort", "5555"]
        let data = procArgs(executable: harmonyArguments[0], arguments: argv, environment: ["PRIVATE_TOKEN=not-an-argument"])
        XCTAssertEqual(try EmulatorResourceHostMemory.parseProcArgs(data), [harmonyArguments[0]] + Array(argv.dropFirst()))
    }

    func testProcArgsParserRejectsMissingNULTerminatorInvalidUTF8AndImpossibleCount() {
        XCTAssertThrowsError(try EmulatorResourceHostMemory.parseProcArgs(Data()))
        var count: Int32 = 0
        let zero = withUnsafeBytes(of: &count) { Data($0) }
        XCTAssertThrowsError(try EmulatorResourceHostMemory.parseProcArgs(zero))
        var truncated = procArgs(executable: "/sdk/Emulator", arguments: ["Emulator", "-start"])
        truncated.removeLast()
        XCTAssertThrowsError(try EmulatorResourceHostMemory.parseProcArgs(truncated))
        var invalidUTF8 = procArgs(executable: "/sdk/Emulator", arguments: ["Emulator"])
        invalidUTF8[4] = 0xff
        XCTAssertThrowsError(try EmulatorResourceHostMemory.parseProcArgs(invalidUTF8))
        XCTAssertThrowsError(try EmulatorResourceHostMemory.parseProcArgs(Data(repeating: 0, count: 1_048_577)))
    }

    private func measure(_ identity: EmulatorResourceIdentity, args: [Int32: [String]]) -> EmulatorResourceHostMemory {
        EmulatorResourceHostMemory.measure(identity: identity,
            processList: { args.keys.sorted().map { self.entry($0, identity.platform == .android ? "qemu-system-aarch64-headless" : "/sdk/Emulator") } },
            arguments: { pid in try XCTUnwrap(args[pid]) },
            sample: { _ in 42 })
    }

    private func entry(_ pid: Int32, _ arguments: String, parent: Int32 = 1) -> SimulatorPhysicalFootprint.ProcessEntry {
        .init(pid: pid, parentPID: parent, arguments: arguments)
    }

    private func assertUnavailable(_ value: EmulatorResourceHostMemory, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(value.physicalFootprintBytes, file: file, line: line)
        XCTAssertNil(value.pid, file: file, line: line)
        XCTAssertTrue(value.partial, file: file, line: line)
        XCTAssertNotNil(value.reason, file: file, line: line)
    }

    private func procArgs(executable: String, arguments: [String], environment: [String] = []) -> Data {
        var argc = Int32(arguments.count)
        var data = withUnsafeBytes(of: &argc) { Data($0) }
        data.append(Data(executable.utf8))
        data.append(contentsOf: [0, 0, 0])
        for argument in arguments + environment { data.append(Data(argument.utf8)); data.append(0) }
        return data
    }
}
