import Darwin
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Harmony framebuffer capture budgets", .serialized)
struct HarmonyFramebufferTimeoutTests {
    @Test("Each capture stage can finish beyond the former five-second budget", arguments: ["snapshot", "receive"])
    func slowStageStillPublishesFrame(_ stage: String) throws {
        let fixture = try SlowHDCFixture(stage: stage, delay: 5.2)
        let session = HarmonySession(target: "fixture", hdcPath: fixture.helper.path)
        defer { session.stop(); fixture.cleanUp() }
        let started = ContinuousClock.now
        session.start()
        let produced = fixture.wait(timeout: 10) { session.getLatestFrameWithVersion() != nil || !session.running }
        #expect(produced)
        let frame = session.getLatestFrameWithVersion()
        #expect(frame?.0 == fixture.jpeg, "The delayed \(stage) must finish and publish its received frame")
        #expect(frame?.1 == 1)
        #expect(started.duration(to: .now) >= .seconds(5.2))
    }

    @Test("Injected stage budgets remain bounded and terminal sessions do not restart", arguments: ["snapshot", "receive"])
    func injectedBudgetStillStopsWithoutRelaunch(_ stage: String) throws {
        let fixture = try SlowHDCFixture(stage: stage, delay: 30)
        let session = HarmonySession(target: "fixture", hdcPath: fixture.helper.path, captureTimeout: 2)
        defer { session.stop(); fixture.cleanUp() }
        session.start()
        #expect(fixture.wait(timeout: 5) { !session.running })
        let pid = try #require(fixture.delayedPID)
        #expect(fixture.wait(timeout: 1) { kill(pid, 0) != 0 })
        #expect(!session.running)
        #expect(session.getLatestFrameWithVersion() == nil)
        let invocations = fixture.invocations
        session.start()
        Thread.sleep(forTimeInterval: 0.1)
        #expect(!session.running)
        #expect(fixture.invocations == invocations)
    }

    @Test("Stopping immediately cancels an owned HDC process in either capture stage", arguments: ["snapshot", "receive"])
    func stopCancelsWaitingStage(_ stage: String) throws {
        let fixture = try SlowHDCFixture(stage: stage, delay: 30)
        let session = HarmonySession(target: "fixture", hdcPath: fixture.helper.path)
        defer { session.stop(); fixture.cleanUp() }
        session.start()
        #expect(fixture.wait(timeout: 3) { fixture.delayedPID != nil })
        let pid = try #require(fixture.delayedPID)
        let stopped = ContinuousClock.now
        session.stop()
        #expect(fixture.wait(timeout: 1) { kill(pid, 0) != 0 })
        #expect(stopped.duration(to: .now) < .seconds(1))
        #expect(!session.running)
        #expect(session.getLatestFrameWithVersion() == nil)
        let invocations = fixture.invocations
        session.start()
        Thread.sleep(forTimeInterval: 0.1)
        #expect(fixture.invocations == invocations, "A cancelled session must never relaunch its helper")
    }
}

private struct SlowHDCFixture {
    let directory: URL
    let helper: URL
    let jpeg = Data([0xff, 0xd8, 0xff, 0xd9])
    let stage: String

    init(stage: String, delay: TimeInterval) throws {
        self.stage = stage
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-hdc-timeout-\(UUID().uuidString)")
        helper = directory.appendingPathComponent("hdc")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try jpeg.write(to: directory.appendingPathComponent("fixture.jpeg"))
        let script = """
        #!/bin/sh
        fixture_dir=$(/usr/bin/dirname "$0")
        case "$3:$4" in
          shell:snapshot_display)
            printf 'snapshot\\n' >> "$fixture_dir/invocations"
            if [ "\(stage)" = snapshot ]; then
              printf '%s' "$$" > "$fixture_dir/delayed-pid"
              exec /bin/sleep \(delay)
            fi
            ;;
          file:recv)
            printf 'receive\\n' >> "$fixture_dir/invocations"
            /bin/cp "$fixture_dir/fixture.jpeg" "$6" || exit 1
            if [ "\(stage)" = receive ]; then
              printf '%s' "$$" > "$fixture_dir/delayed-pid"
              exec /bin/sleep \(delay)
            fi
            ;;
          shell:rm)
            printf cleanup > "$fixture_dir/cleanup"
            ;;
          *) exit 2 ;;
        esac
        """
        try script.write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
    }

    var delayedPID: Int32? {
        guard let value = try? String(contentsOf: directory.appendingPathComponent("delayed-pid"), encoding: .utf8) else { return nil }
        return Int32(value)
    }

    var invocations: String {
        (try? String(contentsOf: directory.appendingPathComponent("invocations"), encoding: .utf8)) ?? ""
    }

    func wait(timeout: TimeInterval, until predicate: () -> Bool) -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while ContinuousClock.now < deadline {
            if predicate() { return true }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return predicate()
    }

    func cleanUp() {
        _ = wait(timeout: 3) { FileManager.default.fileExists(atPath: directory.appendingPathComponent("cleanup").path) }
        try? FileManager.default.removeItem(at: directory)
    }
}
