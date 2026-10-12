import Darwin
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

    @Test func helperBootstrapFailureRetainsSpecificReason() {
        #expect(iosHostHIDFailureCode(stderr: "SimulatorKit dlopen failed; SimDeviceLegacyHIDClient class not found") == "ios_host_hid_legacy_backend_unavailable")
        #expect(iosHostHIDFailureCode(stderr: "SimulatorKit dlopen failed") == "ios_host_hid_simulator_kit_load_failed")
        #expect(iosHostHIDFailureCode(stderr: "layout success") == nil)
    }

    @Test func doctorParserAcceptsSelectedDevice() throws {
        let doctor = try DeviceDoctor.parse(["--platform", "ios", "--device", "SIM-1", "--json"])
        #expect(doctor.device == "SIM-1")
    }
    @Test func swipeBootstrapEOFProducesTypedRedactedEnvelope() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("hid-bootstrap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("baguette")
        let script = """
        #!/bin/sh
        IFS= read -r first
        printf '%s\\n' 'SimulatorKit dlopen failed /private/secret; SimDeviceLegacyHIDClient class not found' >&2
        i=0
        while [ "$i" -lt 3000 ]; do
          printf '%s\\n' 'private diagnostic payload' >&2
          i=$((i+1))
        done
        exit 1
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        chmod(executable.path, S_IRWXU)
        let lifecycle = try webIOSBaguetteSwipeLifecycle(input: .swipe(startX: 2, startY: 8, endX: 2, endY: 2), udid: "SIM-1", screen: .init(width: 10, height: 10), executable: executable.path)
        let started = Date()
        var failure: Error?
        do { _ = try runWebIOSBaguetteLifecycle(lifecycle) }
        catch { failure = error }
        let error = try #require(failure)
        guard case HostCommandRunError.nonZeroExit(_, let result) = error else {
            Issue.record("Bootstrap EOF discarded stderr: \(error)")
            return
        }
        #expect(result.stderr.contains("SimDeviceLegacyHIDClient"))
        #expect(result.stderrBytes > 16_384)
        #expect(result.stderrData.count <= 16_384)
        #expect(result.stderrTruncated)
        #expect(Date().timeIntervalSince(started) < 5)
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        do { try failHostCommand(error, outputFormat: .json) } catch { }
        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        try pipe.fileHandleForWriting.close()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let envelope = try JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
        #expect(!envelope.ok)
        #expect(envelope.error.code == "ios_host_hid_legacy_backend_unavailable")
        #expect(!String(decoding: data, as: UTF8.self).contains("/private/secret"))
        #expect(!String(decoding: data, as: UTF8.self).contains("diagnostic payload"))
    }

}
