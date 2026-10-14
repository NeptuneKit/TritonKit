import Foundation
import TritonKitShared

struct DeviceRecordingFailure: Error, CustomStringConvertible {
    let code: String
    let description: String
    init(_ code: String, _ description: String) { self.code = code; self.description = description }
}

struct DeviceRecordingSession: Codable {
    let schemaVersion: Int
    let sessionID: String
    let ownerUID: UInt32
    let target: String
    let rawTarget: String
    let platform: String
    let scope: String
    let output: String
    let outputDevice: UInt64
    let outputInode: UInt64
    let maximumDurationSeconds: Double
    let startedAt: Date
    let adb: String
    var workerPID: Int32?
    var workerIdentity: String?
    var recorderPID: Int32?
    var recorderIdentity: String?
    var state: String
    var endedAt: Date?
    var actualDurationSeconds: Double?
    var sampleCount: Int?
    var failureCode: String?
    var failureMessage: String?

    func assertAccess(owner: UInt32, device: String?) throws {
        guard ownerUID == owner else { throw DeviceRecordingFailure("recording_owner_mismatch", "Session belongs to another user.") }
        if let device, device != target { throw DeviceRecordingFailure("recording_target_mismatch", "Session belongs to \(target); use the original target.") }
    }
    static func fixture(target: String, owner: UInt32) -> Self {
        Self(schemaVersion: 1, sessionID: UUID().uuidString.lowercased(), ownerUID: owner, target: target,
             rawTarget: "a", platform: "android", scope: "emulator", output: "/tmp/test.mp4", outputDevice: 0,
             outputInode: 0, maximumDurationSeconds: 30, startedAt: Date(), adb: "adb", state: "starting")
    }
}

struct DeviceRecordingOutput: Encodable {
    let ok: Bool
    let action: String
    let session: DeviceRecordingSession
    let wallClockDurationSeconds: Double
    let captureMethod: String
    let includesAudio: Bool = false
    let artifacts: [String]
    var observedFramesPerSecond: Double? {
        guard let count = session.sampleCount, let duration = session.actualDurationSeconds, duration > 0 else { return nil }
        return Double(count) / duration
    }
    enum CodingKeys: String, CodingKey { case ok, action, session, wallClockDurationSeconds, captureMethod, includesAudio, artifacts, observedFramesPerSecond }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ok, forKey: .ok); try c.encode(action, forKey: .action); try c.encode(session, forKey: .session)
        try c.encode(wallClockDurationSeconds, forKey: .wallClockDurationSeconds)
        try c.encode(captureMethod, forKey: .captureMethod); try c.encode(includesAudio, forKey: .includesAudio)
        try c.encode(artifacts, forKey: .artifacts); try c.encodeIfPresent(observedFramesPerSecond, forKey: .observedFramesPerSecond)
    }
}

func validateDeviceRecordingDuration(_ duration: Double) throws {
    guard duration.isFinite, (1...180).contains(duration) else { throw DeviceRecordingFailure("recording_invalid_duration", "Maximum duration must be finite and within 1...180 seconds.") }
}
func validateDeviceRecordingSession(_ session: String) throws {
    guard UUID(uuidString: session) != nil, session == session.lowercased() else { throw DeviceRecordingFailure("recording_invalid_session", "Use the exact lowercase session UUID returned by start.") }
}
func deviceRecordingIdentityMatches(expected: String, observed: String?) -> Bool {
    !expected.isEmpty && expected == observed
}
