import Foundation
import TritonKitShared
import Testing
@testable import TritonKitCLI

@Suite("Selected Simulator HID compatibility", .serialized)
struct IOSHostHIDProbeTests {
    let developer = "/fixture/Selected Xcode.app/Contents/Developer"

    @Test func modernLayoutIsSelectedWithoutGuessingAnotherXcode() {
        let candidates = simulatorKitFrameworkCandidates(developerDirectory: developer)
        #expect(candidates.first?.path == "/fixture/Selected Xcode.app/Contents/SharedFrameworks/SimulatorKit.framework/SimulatorKit")
        #expect(candidates.allSatisfy { $0.path.hasPrefix("/fixture/Selected Xcode.app/") })
        #expect(simulatorKitFrameworkCandidates(developerDirectory: "/fixture/Selected Xcode.app").map(\.path) == candidates.map(\.path))
    }

    @Test func missingFrameworkDoesNotLoadOrGrantTouch() {
        var loads = 0
        let probe = probeIOSHostHID(selectedDevice: "SIM-1", developerDirectory: developer, fileExists: { _ in false }, loader: { _ in
            loads += 1
            return .init(loaded: true, legacyClientAvailable: true, modernClientAvailable: false, error: nil)
        })
        #expect(loads == 0)
        #expect(!probe.compatible && !probe.available)
        #expect(probe.code == "ios_host_hid_simulator_kit_unavailable")
        #expect(probe.target == "SIM-1")
    }

    @Test func distinctBootstrapFailuresRemainTyped() {
        for (loaded, modern, expected) in [(false, false, "ios_host_hid_simulator_kit_load_failed"), (true, false, "ios_host_hid_legacy_backend_unavailable"), (true, true, "ios_host_hid_modern_backend_unsupported")] {
            let probe = probeIOSHostHID(selectedDevice: "SIM-1", developerDirectory: developer, fileExists: { _ in true }, loader: { _ in
                .init(loaded: loaded, legacyClientAvailable: false, modernClientAvailable: modern, error: "PRIVATE PATH")
            })
            #expect(!probe.compatible && !probe.available)
            #expect(probe.code == expected)
            #expect(!probe.message.contains("PRIVATE"))
            #expect(probe.errorDetail.nextAction?.args.contains("SIM-1") == true)
        }
    }

    @Test func classPresenceNeverProvesTouchOrBusinessReadiness() throws {
        let probe = probeIOSHostHID(selectedDevice: "SIM-1", developerDirectory: developer, fileExists: { _ in true }, loader: { _ in
            .init(loaded: true, legacyClientAvailable: true, modernClientAvailable: false, error: nil)
        })
        #expect(probe.compatible)
        #expect(probe.toolchainSource == "provided")
        #expect(!probe.sourceCommands.contains("xcode-select -p"))
        #expect(probe.sourceCommands == ["triton device hid-bootstrap --framework <selected-SimulatorKit>"])
        #expect(!probe.available && !probe.inputDispatchVerified)
        #expect(probe.verification == "framework-compatibility-only")
        let idb = HostToolProbeOutput(name: "idb", path: "idb", available: true, versionSummary: nil, error: nil, sourceCommand: "idb --version")
        let capabilities = iosStrongControlProbes(idbProbe: idb, hidProbe: probe)
        #expect(capabilities[0].available)
        #expect(!capabilities[1].available)
        #expect(capabilities[1].reason == "ios_host_hid_dispatch_not_probed")
        let json = String(decoding: try JSONEncoder().encode(probe), as: UTF8.self)
        #expect(!json.contains("/fixture"))
    }

    @Test func doctorParserAcceptsSelectedDevice() throws {
        let doctor = try DeviceDoctor.parse(["--platform", "ios", "--device", "SIM-1", "--json"])
        #expect(doctor.device == "SIM-1")
    }

    @Test func nativeHelperMalformedBootstrapFailsWithoutLeakingOutput() throws {
        let input = TKInputRequest.tap(x: 1, y: 2)
        do {
            _ = try runNativeSimulatorInput(target: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", input: input) { command in
                let result = HostProcessResult(stdoutData: Data("PRIVATE MALFORMED ENVELOPE".utf8), stderrData: Data("/private/secret diagnostic payload".utf8), exitCode: 1, sourceCommand: "private command", stdoutTruncated: false, stderrTruncated: true, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 26, stderrBytes: 30)
                throw HostCommandRunError.nonZeroExit(command: command, result: result)
            }
            Issue.record("Malformed native helper output must fail closed")
        } catch let error as NativeHIDControlError {
            #expect(error.code == "ios_host_hid_helper_failed")
            let json = try encodeJSON(error.detail)
            #expect(!json.contains("PRIVATE"))
            #expect(!json.contains("/private/secret"))
            #expect(!json.contains("diagnostic payload"))
        }
    }
}
