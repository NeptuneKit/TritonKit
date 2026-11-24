import ArgumentParser
import Foundation
import Testing
@testable import TritonKitCLI

struct DeviceRecordingTests {
    @Test func rejectsInvalidBoundsAndSessionTraversal() throws {
        #expect(throws: DeviceRecordingFailure.self) { try validateDeviceRecordingDuration(.nan) }
        #expect(throws: DeviceRecordingFailure.self) { try validateDeviceRecordingDuration(181) }
        #expect(throws: DeviceRecordingFailure.self) { try validateDeviceRecordingSession("../../victim") }
        try validateDeviceRecordingDuration(30)
        try validateDeviceRecordingSession(UUID().uuidString.lowercased())
    }
    @Test func parserRequiresExplicitTargetOutputAndSession() throws {
        #expect(throws: (any Error).self) { try DeviceRecordingStart.parse([]) }
        #expect(throws: (any Error).self) { try DeviceRecordingStop.parse([]) }
        let command = try DeviceRecordingStart.parse(["--device", "sim:sample", "--output", "/tmp/sample.mp4", "--maximum-duration", "60", "--json"])
        #expect(command.maximumDuration == 60)
        #expect(command.device == "sim:sample")
    }
    @Test func sessionIdentityRejectsWrongOwnerTargetAndReusedPID() throws {
        let record = DeviceRecordingSession.fixture(target: "sim:a", owner: 100)
        #expect(throws: DeviceRecordingFailure.self) { try record.assertAccess(owner: 101, device: "sim:a") }
        #expect(throws: DeviceRecordingFailure.self) { try record.assertAccess(owner: 100, device: "sim:b") }
        try record.assertAccess(owner: 100, device: "sim:a")
        #expect(!deviceRecordingIdentityMatches(expected: "Mon Oct 12 10:00:00 2026 triton _worker abc", observed: "Mon Oct 12 11:00:00 2026 other"))
        #expect(!deviceRecordingIdentityMatches(expected: "", observed: ""))
    }
    @Test func rejectsSymlinkAndExistingOutputWithoutChangingVictim() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root) }
        let victim = root.appendingPathComponent("victim.mp4")
        try Data("preserve".utf8).write(to: victim)
        #expect(throws: DeviceRecordingFailure.self) { try reserveDeviceRecordingOutput(victim.path) }
        let link = root.appendingPathComponent("link.mp4")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: victim)
        #expect(throws: DeviceRecordingFailure.self) { try reserveDeviceRecordingOutput(link.path) }
        #expect(try String(contentsOf: victim) == "preserve")
    }
    @Test func startupFailureReleasesReservationAndAllowsSameTargetAndOutputRetry() throws {
        let fixture = try RecordingStartFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        #expect(throws: DeviceRecordingFailure.self) {
            try fixture.begin { _ in throw DeviceRecordingFailure("fixture_spawn_failed", "Injected spawn failure") }
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.output))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.store.root.path) == [".lock"])
        let retry = try fixture.begin { _ in }
        #expect(try fixture.store.read(retry.sessionID).state == "starting")
    }

    @Test func expiredUnclaimedSessionAllowsRetryButFreshStartStillBlocks() throws {
        let fixture = try RecordingStartFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let start = Date()
        let stale = try fixture.begin(now: start) { _ in }
        #expect(throws: DeviceRecordingFailure.self) {
            try fixture.begin(now: start.addingTimeInterval(5)) { _ in
                Issue.record("A recent unclaimed session must not be preempted")
            }
        }
        let retry = try fixture.begin(now: start.addingTimeInterval(60)) { _ in }
        #expect(retry.sessionID != stale.sessionID)
        let recovered = try fixture.store.read(stale.sessionID)
        #expect(recovered.state == "failed")
        #expect(recovered.failureCode == "recording_start_timeout")
    }

    @Test func recoveryDoesNotPreemptClaimedWorkerOrRemoveReplacedOutput() throws {
        let fixture = try RecordingStartFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let start = Date()
        var first = try fixture.begin(now: start) { _ in }
        first.workerPID = 12345
        try fixture.store.write(first)
        #expect(throws: DeviceRecordingFailure.self) {
            try fixture.begin(now: start.addingTimeInterval(60)) { _ in
                Issue.record("A claimed session must not be preempted")
            }
        }
        first.workerPID = nil
        try fixture.store.write(first)
        try Data("replacement".utf8).write(to: URL(fileURLWithPath: fixture.output), options: .atomic)
        #expect(throws: DeviceRecordingFailure.self) {
            try fixture.begin(now: start.addingTimeInterval(60)) { _ in
                Issue.record("A replaced reservation must never be removed or overwritten")
            }
        }
        #expect(try String(contentsOfFile: fixture.output, encoding: .utf8) == "replacement")
        #expect(try fixture.store.read(first.sessionID).state == "failed")
    }

    @Test func recorderCommandQuotesSerialAndBindsUniqueArtifact() throws {
        let record = DeviceRecordingSession.fixture(target: "android:a", owner: 100)
        let command = deviceRecordingNativeCommand(session: record, stagingPath: "/private/session/video.mp4")
        #expect(command.arguments.contains(record.rawTarget))
        #expect(command.arguments.joined(separator: " ").contains(record.sessionID))
        #expect(deviceRecordingShellQuote("a'b") == "'a'\\''b'")
    }
    @Test func wallClockCannotReplaceEncodedSamples() {
        #expect(throws: HostSimulatorRecordingValidationError.self) {
            try simulatorRecordingActualDuration(containerDurationSeconds: 30, videoTrackDurationSeconds: [30], videoSampleDurationSeconds: nil)
        }
    }
}

private struct RecordingStartFixture {
    let root: URL
    let store: DeviceRecordingStore
    var output: String { root.appendingPathComponent("recording.mp4").path }
    private let target = HostDeviceTarget(platform: "ios", id: "sim:fixture", target: "fixture", state: "Booted",
                                          ready: true, source: "fixture", name: nil, runtime: nil, transport: nil, scope: "simulator")

    init() throws {
        root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".triton-recording-test-\(UUID().uuidString)")
        store = try DeviceRecordingStore(environment: ["TRITON_RECORDING_STATE_DIR": root.appendingPathComponent("sessions").path])
    }

    func begin(now: Date = Date(), launch: (String) throws -> Void) throws -> DeviceRecordingSession {
        try store.beginRecording(target: target, output: output, maximumDuration: 5, adb: "adb", now: now, launchWorker: launch)
    }
}
