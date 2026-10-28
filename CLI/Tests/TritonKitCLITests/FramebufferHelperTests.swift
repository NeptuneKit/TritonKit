import Foundation
import Testing
@testable import TritonKitCLI

@Suite("SP-196 framebuffer selected toolchain and bounded helpers", .serialized)
struct FramebufferHelperTests {
    @Test func selectedSharedFrameworkAndContextAreBoundTogether() throws {
        let developer = "/Applications/Chosen Xcode.app/Contents/Developer"
        let shared = "/Applications/Chosen Xcode.app/Contents/SharedFrameworks"
        let plan = try #require(framebufferFrameworkPlan(developerDirectory: developer, fileExists: {
            $0 == shared + "/SimulatorKit.framework/SimulatorKit" || $0 == shared + "/CoreSimulator.framework/CoreSimulator"
        }))
        #expect(plan.developerDirectory == developer)
        #expect(plan.simulatorKit == shared + "/SimulatorKit.framework/SimulatorKit")
        #expect(plan.coreSimulator == shared + "/CoreSimulator.framework/CoreSimulator")
    }

    @Test func missingOrRelativeSelectedFrameworksNeverUseDefaultXcode() {
        #expect(framebufferFrameworkPlan(developerDirectory: nil, fileExists: { _ in true }) == nil)
        #expect(framebufferFrameworkPlan(developerDirectory: "relative/Xcode", fileExists: { _ in true }) == nil)
        #expect(framebufferFrameworkPlan(developerDirectory: "/Applications/Missing.app", fileExists: { $0.hasPrefix("/Applications/Xcode.app/") }) == nil)
    }

    @Test func frameworkLoadPinsToolchainEvenAfterPartialLoad() {
        let loader = FramebufferFrameworkLoader()
        let a = FramebufferFrameworkPlan(developerDirectory: "/A", coreSimulator: "/A/Core", simulatorKit: "/A/Kit")
        let b = FramebufferFrameworkPlan(developerDirectory: "/B", coreSimulator: "/B/Core", simulatorKit: "/B/Kit")
        var paths: [String] = []
        #expect(!loader.load(a, load: { paths.append($0); return $0 == a.coreSimulator }))
        #expect(!loader.load(b, load: { paths.append($0); return true }))
        #expect(paths == [a.coreSimulator, a.simulatorKit])
        #expect(loader.load(a, load: { paths.append($0); return true }))
        #expect(loader.load(a, load: { _ in Issue.record("must not reload"); return false }))
    }

    @Test func drainsBothPipesAndBoundsCapture() throws {
        let runner = FramebufferCaptureProcess()
        let result = try #require(runner.run(executable: "/bin/sh", arguments: ["-c", "i=0; while [ $i -lt 5000 ]; do printf '1234567890'; printf 'stderr1234' >&2; i=$((i+1)); done"], timeout: 5, maximumOutputBytes: 100000))
        #expect(result.exitStatus == 0)
        #expect(result.stdout.count == 50000)
        #expect(result.stderr.count == 50000)
        #expect(runner.run(executable: "/bin/sh", arguments: ["-c", "while :; do printf '0123456789'; done"], timeout: 5, maximumOutputBytes: 1024) == nil)
    }


    @Test func legacyLayoutAndAppDirectoryRemainSupported() throws {
        let developer = "/Applications/Legacy.app/Contents/Developer"
        let plan = try #require(framebufferFrameworkPlan(developerDirectory: "/Applications/Legacy.app", fileExists: {
            $0 == developer + "/Library/PrivateFrameworks/SimulatorKit.framework/Versions/A/SimulatorKit" || $0 == "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator"
        }))
        #expect(plan.developerDirectory == developer)
        #expect(plan.simulatorKit == developer + "/Library/PrivateFrameworks/SimulatorKit.framework/Versions/A/SimulatorKit")
    }

    @Test func coldLoaderCanRetryAnotherToolchainBeforeAnyImageLoads() {
        let loader = FramebufferFrameworkLoader()
        let a = FramebufferFrameworkPlan(developerDirectory: "/A", coreSimulator: "/A/Core", simulatorKit: "/A/Kit")
        let b = FramebufferFrameworkPlan(developerDirectory: "/B", coreSimulator: "/B/Core", simulatorKit: "/B/Kit")
        #expect(!loader.load(a, load: { _ in false }))
        #expect(loader.load(b, load: { _ in true }))
    }

    @Test func exitedParentWithInheritedPipeCannotHoldCaptureOpen() throws {
        let runner = FramebufferCaptureProcess()
        let start = Date()
        let result = try #require(runner.run(executable: "/bin/sh", arguments: ["-c", "/bin/sleep 1 & printf done"], timeout: 0.2))
        #expect(result.exitStatus == 0)
        #expect(String(data: result.stdout, encoding: .utf8) == "done")
        #expect(Date().timeIntervalSince(start) < 0.8)
    }


    @Test func exitFailureAndInvalidBoundsAreExplicit() throws {
        let runner = FramebufferCaptureProcess()
        let result = try #require(runner.run(executable: "/bin/sh", arguments: ["-c", "printf failure >&2; exit 7"]))
        #expect(result.exitStatus == 7)
        #expect(String(data: result.stderr, encoding: .utf8) == "failure")
        #expect(runner.run(executable: "/bin/echo", arguments: ["no"], timeout: .infinity) == nil)
        #expect(runner.run(executable: "/bin/echo", arguments: ["no"], maximumOutputBytes: 0) == nil)
    }

    @Test func stoppedSessionsDoNotPublishOrRestart() {
        let android = AndroidSession(serial: "fixture", adbPath: "/does/not/exist")
        android.stop()
        android.start()
        #expect(android.getLatestFrameWithVersion() == nil)
        let harmony = HarmonySession(target: "fixture", hdcPath: "/does/not/exist")
        harmony.stop()
        harmony.start()
        #expect(harmony.getLatestFrameWithVersion() == nil)
        let simulator = FramebufferSession(udid: "fixture")
        simulator.stop()
        #expect(simulator.getLatestFrameWithVersion() == nil)
    }


    @Test func timedOutAndroidHelperIsNotAutomaticallyRelaunched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("invocations")
        let helper = directory.appendingPathComponent("adb-fixture")
        try Data(("#!/bin/sh\nprintf x >> '" + marker.path + "'\nexec /bin/sleep 10\n").utf8).write(to: helper)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        // This tests no relaunch after a timeout, not subsecond script startup.
        // A fresh executable script can take over 0.5s to reach its first line.
        let session = AndroidSession(serial: "fixture", adbPath: helper.path, captureTimeout: 2)
        session.start()
        defer { session.stop() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while session.running && ContinuousClock.now < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #expect(try Data(contentsOf: marker) == Data("x".utf8))
        #expect(!session.running)
        #expect(session.getLatestFrameWithVersion() == nil)
    }

    @Test func timeoutAndCancellationStopOwnedProcess() throws {
        let runner = FramebufferCaptureProcess()
        let start = Date()
        #expect(runner.run(executable: "/bin/sleep", arguments: ["10"], timeout: 0.05) == nil)
        #expect(Date().timeIntervalSince(start) < 2)
        let cancelled = FramebufferCaptureProcess()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            _ = cancelled.run(executable: "/bin/sleep", arguments: ["10"], timeout: 5)
            done.signal()
        }
        Thread.sleep(forTimeInterval: 0.05)
        cancelled.cancel()
        #expect(done.wait(timeout: .now() + 2) == .success)
        #expect(cancelled.run(executable: "/bin/echo", arguments: ["late"]) == nil)
    }
}
