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
