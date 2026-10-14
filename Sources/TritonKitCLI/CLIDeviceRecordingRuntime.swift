import AVFoundation
import AppKit
import Darwin
import Foundation
import TritonKitShared

// Session state lives in an owner-only directory. The only process permitted to
// signal the recorder is its original long-lived parent worker.
struct DeviceRecordingStore {
    let root: URL
    init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        root = URL(fileURLWithPath: environment["TRITON_RECORDING_STATE_DIR"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tritonkit/recordings").path).standardizedFileURL
        try deviceRecordingCreatePrivateDirectories(root.path)
        try deviceRecordingCheckPath(root.path)
        var info = stat()
        guard lstat(root.path, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw DeviceRecordingFailure("recording_unsafe_store", "Recording directory must belong to this user and have mode 0700.")
        }
    }
    func directory(_ session: String) throws -> URL {
        try validateDeviceRecordingSession(session)
        let directory = root.appendingPathComponent(session)
        try deviceRecordingCheckPath(directory.path)
        return directory
    }
    func read(_ session: String) throws -> DeviceRecordingSession {
        let path = try directory(session).appendingPathComponent("session.json")
        try deviceRecordingCheckPath(path.path)
        let record = try JSONDecoder().decode(DeviceRecordingSession.self, from: Data(contentsOf: path))
        guard record.sessionID == session else { throw DeviceRecordingFailure("recording_session_corrupt", "Stored session identity does not match.") }
        try record.assertAccess(owner: getuid(), device: nil)
        return record
    }
    func write(_ record: DeviceRecordingSession) throws {
        let path = try directory(record.sessionID).appendingPathComponent("session.json")
        try deviceRecordingCheckPath(path.path, allowMissingLeaf: true)
        try JSONEncoder().encode(record).write(to: path, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }
    func locked<T>(_ body: () throws -> T) throws -> T {
        try deviceRecordingCheckPath(root.path)
        let fd = open(root.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw DeviceRecordingFailure("recording_lock_failed", "Could not open safe recording lock.") }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_nlink == 1,
              info.st_mode & S_IFMT == S_IFREG else { throw DeviceRecordingFailure("recording_lock_failed", "Recording lock ownership is unsafe.") }
        // Nonblocking retries keep a corrupt/held lock from hanging a CLI forever.
        let deadline = Date().addingTimeInterval(5)
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard Date() < deadline else { throw DeviceRecordingFailure("recording_busy", "Recording store is busy.") }
            Thread.sleep(forTimeInterval: 0.05)
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }
    func stopRequested(_ session: String) throws -> Bool {
        let path = try directory(session).appendingPathComponent("stop")
        try deviceRecordingCheckPath(path.path, allowMissingLeaf: true)
        return FileManager.default.fileExists(atPath: path.path)
    }
}

private func deviceRecordingCreatePrivateDirectories(_ path: String) throws {
    guard path.hasPrefix("/") else { throw DeviceRecordingFailure("recording_unsafe_path", "Use an absolute recording state directory.") }
    var cursor = ""
    for part in URL(fileURLWithPath: path).standardizedFileURL.pathComponents {
        cursor = part == "/" ? "/" : (cursor as NSString).appendingPathComponent(part)
        var info = stat()
        if lstat(cursor, &info) != 0 {
            guard errno == ENOENT, mkdir(cursor, 0o700) == 0, lstat(cursor, &info) == 0 else { throw DeviceRecordingFailure("recording_unsafe_path", "Cannot create safe recording directory.") }
        }
        guard info.st_mode & S_IFMT == S_IFDIR else { throw DeviceRecordingFailure("recording_unsafe_path", "Recording directory ancestors must be directories, without symlinks.") }
    }
}

func deviceRecordingCheckPath(_ path: String, allowMissingLeaf: Bool = false) throws {
    guard path.hasPrefix("/"), !path.contains("\0") else { throw DeviceRecordingFailure("recording_unsafe_path", "Use an absolute path.") }
    let pieces = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
    var cursor = ""
    for (index, part) in pieces.enumerated() {
        cursor = part == "/" ? "/" : (cursor as NSString).appendingPathComponent(part)
        var info = stat()
        if lstat(cursor, &info) != 0 {
            if allowMissingLeaf, index == pieces.count - 1, errno == ENOENT { return }
            throw DeviceRecordingFailure("recording_unsafe_path", "Path component is unavailable: \(cursor)")
        }
        guard info.st_mode & S_IFMT != S_IFLNK else { throw DeviceRecordingFailure("recording_unsafe_path", "Symlink paths are refused: \(cursor)") }
    }
}

@discardableResult
func reserveDeviceRecordingOutput(_ path: String) throws -> (UInt64, UInt64) {
    guard path.hasPrefix("/"), URL(fileURLWithPath: path).pathExtension.lowercased() == "mp4" else { throw DeviceRecordingFailure("recording_invalid_output", "Use an absolute fresh .mp4 destination.") }
    try deviceRecordingCheckPath(path, allowMissingLeaf: true)
    let fd = open(path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else { throw DeviceRecordingFailure("recording_output_exists", "Output exists or cannot be safely reserved; choose a fresh destination.") }
    defer { close(fd) }
    var info = stat()
    guard fstat(fd, &info) == 0 else { throw DeviceRecordingFailure("recording_unsafe_path", "Could not verify output reservation.") }
    return (UInt64(info.st_dev), UInt64(info.st_ino))
}

func deviceRecordingShellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
func deviceRecordingNativeCommand(session: DeviceRecordingSession, stagingPath: String) -> TKHostCommand {
    if session.platform == "android" {
        let remote = "/data/local/tmp/triton-recording-\(session.sessionID).mp4"
        // The PID/creation tick pair is recorded on the device. A unique artifact
        // binds cleanup to this session, never to all screenrecord processes.
        let pidfile = remote + ".pid"
        let script = "screenrecord --time-limit \(Int(session.maximumDurationSeconds)) \(deviceRecordingShellQuote(remote)) & p=$!; t=$(awk '{print $22}' /proc/$p/stat); printf '%s %s\\n' $p $t > \(deviceRecordingShellQuote(pidfile)); wait $p"
        // adb shell already accepts one bounded script argument. Adding a
        // second `sh -c` layer would preserve the quote characters and prevent
        // screenrecord from creating the UUID-bound artifact on recent adb.
        return TKHostCommand(executable: session.adb, arguments: ["-s", session.rawTarget, "shell", script], riskLevel: .evidence, defaultTimeoutSeconds: session.maximumDurationSeconds + 15)
    }
    return TKHostCommand(executable: "/usr/bin/xcrun", arguments: ["simctl", "io", session.rawTarget, "recordVideo", "--codec=h264", stagingPath], riskLevel: .evidence, defaultTimeoutSeconds: session.maximumDurationSeconds + 15)
}

func deviceRecordingProcessIdentity(_ pid: Int32) -> String? {
    guard pid > 1 else { return nil }
    let result = try? runHostCommand(TKHostCommand(executable: "/bin/ps", arguments: ["-p", String(pid), "-o", "lstart=", "-o", "command="], riskLevel: .readonly, defaultTimeoutSeconds: 2))
    guard let result, result.exitCode == 0 else { return nil }
    let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

func startDeviceRecording(device: String, output: String, maximumDuration: Double, adb: String, hdc: String) async throws -> DeviceRecordingSession {
    try validateDeviceRecordingDuration(maximumDuration)
    let selected = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device), hdc: hdc, adb: adb).target
    guard selected.ready else { throw DeviceRecordingFailure("recording_target_not_ready", "Recording requires a ready device.") }
    guard selected.platform == "android" || selected.platform == "ios" else { throw DeviceRecordingFailure("recording_unsupported", "Native recording currently supports iOS and Android; Harmony recording is not available.") }
    if selected.platform == "ios", selected.scope != "real" { try assertIOSSimulatorResizeCaptureAllowed(target: selected.rawTarget, environment: [:]) }
    let store = try DeviceRecordingStore()
    let record = try store.locked { () -> DeviceRecordingSession in
        for name in try FileManager.default.contentsOfDirectory(atPath: store.root.path) where UUID(uuidString: name) != nil {
            let other = try store.read(name)
            if other.target == selected.id, ["starting", "recording", "stopping"].contains(other.state) {
                throw DeviceRecordingFailure("recording_already_active", "Target already has session \(other.sessionID); inspect or stop that session first.")
            }
        }
        let reservation = try reserveDeviceRecordingOutput(output)
        let id = UUID().uuidString.lowercased()
        let directory = store.root.appendingPathComponent(id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let initial = DeviceRecordingSession(schemaVersion: 1, sessionID: id, ownerUID: getuid(), target: selected.id,
                                             rawTarget: selected.rawTarget, platform: selected.platform, scope: selected.scope ?? "simulator", output: output,
                                             outputDevice: reservation.0, outputInode: reservation.1,
                                             maximumDurationSeconds: maximumDuration, startedAt: Date(), adb: adb, state: "starting")
        try store.write(initial)
        let process = Process()
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw DeviceRecordingFailure("recording_worker_unavailable", "Current triton executable cannot be launched as a background worker.") }
        process.executableURL = executable
        process.arguments = ["device", "recording", "_worker", "--session", id]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Do not wait: the worker owns its native recorder and closes all parent
        // pipes. It outlives this invocation and has an independent deadline.
        return initial
    }
    let deadline = Date().addingTimeInterval(25)
    while Date() < deadline {
        let current = try store.locked { try store.read(record.sessionID) }
        if current.state != "starting" { return current }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    // A timed-out acknowledgement still has an owned session. Request stop;
    // never silently abandon an unknown helper or report a successful start.
    _ = try await stopDeviceRecording(session: record.sessionID, device: nil)
    throw DeviceRecordingFailure("recording_start_timeout", "Worker did not acknowledge start within 25 seconds.")
}

func inspectDeviceRecording(session: String, device: String?) throws -> DeviceRecordingSession {
    let store = try DeviceRecordingStore()
    return try store.locked {
        let record = try store.read(session)
        try record.assertAccess(owner: getuid(), device: device)
        if ["recording", "stopping"].contains(record.state) {
            guard let pid = record.workerPID, let identity = record.workerIdentity,
                  deviceRecordingIdentityMatches(expected: identity, observed: deviceRecordingProcessIdentity(pid)) else {
                throw DeviceRecordingFailure("recording_worker_identity_lost", "Worker identity is unavailable or changed; no process has been signalled. Preserve private session state for recovery.")
            }
        }
        return record
    }
}

func stopDeviceRecording(session: String, device: String?) async throws -> DeviceRecordingSession {
    let store = try DeviceRecordingStore()
    let record = try inspectDeviceRecording(session: session, device: device)
    if ["completed", "failed"].contains(record.state) { return record }
    try store.locked {
        let request = try store.directory(session).appendingPathComponent("stop")
        try deviceRecordingCheckPath(request.path, allowMissingLeaf: true)
        let fd = open(request.path, O_CREAT | O_WRONLY | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw DeviceRecordingFailure("recording_stop_failed", "Could not safely request stop.") }
        close(fd)
    }
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
        let current = try store.locked { try store.read(session) }
        if ["completed", "failed"].contains(current.state) { return current }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw DeviceRecordingFailure("recording_stop_timeout", "Worker finalization exceeded 30 seconds; state is retained and its own duration watchdog remains active.")
}

func runDeviceRecordingWorker(session: String) async throws {
    _ = setsid()
    let store = try DeviceRecordingStore()
    var record = try store.locked { () -> DeviceRecordingSession in
        var value = try store.read(session)
        guard value.state == "starting", value.workerPID == nil else { throw DeviceRecordingFailure("recording_worker_conflict", "This session already has an owner.") }
        value.workerPID = getpid(); value.workerIdentity = deviceRecordingProcessIdentity(getpid())
        guard value.workerIdentity?.contains(session) == true else { throw DeviceRecordingFailure("recording_worker_identity_unavailable", "Cannot prove worker command identity.") }
        try store.write(value)
        return value
    }
    let staging = try store.directory(session).appendingPathComponent("video.mp4")
    do {
        if record.platform == "ios", record.scope == "real" {
            try await deviceRecordingRunnerSequence(record: &record, store: store, staging: staging)
        } else {
            try await deviceRecordingNativeSession(record: &record, store: store, staging: staging)
        }
        record.actualDurationSeconds = try await deviceRecordingMediaDuration(staging.path)
        guard let actual = record.actualDurationSeconds, actual > 0 else { throw DeviceRecordingFailure("recording_empty_media", "Recorded artifact contains no positive video samples.") }
        try deviceRecordingPublish(staging: staging.path, record: record)
        record.state = "completed"; record.endedAt = Date()
        try store.locked { try store.write(record) }
    } catch {
        record.state = "failed"; record.endedAt = Date()
        record.failureCode = (error as? DeviceRecordingFailure)?.code ?? (error as? IOSRunnerFailure)?.code ?? "recording_failed"
        record.failureMessage = String(describing: error)
        try store.locked { try store.write(record) }
    }
}

private func deviceRecordingNativeSession(record: inout DeviceRecordingSession, store: DeviceRecordingStore, staging: URL) async throws {
    if record.platform == "ios" { try assertIOSSimulatorResizeCaptureAllowed(target: record.rawTarget, environment: [:]) }
    let command = deviceRecordingNativeCommand(session: record, stagingPath: staging.path)
    let process = Process()
    configureHostProcessExecutable(process, command: command)
    process.standardInput = FileHandle.nullDevice; process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
    try process.run()
    record.recorderPID = process.processIdentifier
    record.recorderIdentity = deviceRecordingProcessIdentity(process.processIdentifier)
    let ownedIdentity = record.recorderIdentity
    defer {
        if process.isRunning, let identity = ownedIdentity,
           deviceRecordingIdentityMatches(expected: identity, observed: deviceRecordingProcessIdentity(process.processIdentifier)) {
            // Retained unreaped Process plus creation/command identity prevents
            // PID reuse. Remote Android recorders also have a native deadline.
            kill(process.processIdentifier, SIGKILL)
        }
    }
    record.state = "recording"
    try store.locked { try store.write(record) }
    let deadline = record.startedAt.addingTimeInterval(record.maximumDurationSeconds)
    while process.isRunning, Date() < deadline, !(try store.stopRequested(record.sessionID)) {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    record.state = "stopping"; try store.locked { try store.write(record) }
    if record.platform == "android" { try deviceRecordingAndroidStop(record) }
    else if process.isRunning { process.interrupt() }
    let exitDeadline = Date().addingTimeInterval(10)
    while process.isRunning, Date() < exitDeadline { try await Task.sleep(nanoseconds: 100_000_000) }
    if process.isRunning {
        // The Process object still owns an unreaped live child; identity is
        // additionally checked before escalation. Never kill a persisted PID.
        if let identity = record.recorderIdentity, deviceRecordingIdentityMatches(expected: identity, observed: deviceRecordingProcessIdentity(process.processIdentifier)) {
            process.terminate()
            let termDeadline = Date().addingTimeInterval(2)
            while process.isRunning, Date() < termDeadline { try await Task.sleep(nanoseconds: 50_000_000) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        throw DeviceRecordingFailure("recording_recorder_timeout", "Native recorder did not finalize within ten seconds.")
    }
    if record.platform == "android" {
        let remote = "/data/local/tmp/triton-recording-\(record.sessionID).mp4"
        let pull = try runHostCommand(TKHostCommand(executable: record.adb, arguments: ["-s", record.rawTarget, "pull", remote, staging.path], riskLevel: .evidence, defaultTimeoutSeconds: 10))
        guard pull.exitCode == 0 else { throw DeviceRecordingFailure("recording_pull_failed", "Android recording could not be retrieved; unique remote artifact was retained.") }
        // Remove only this session's UUID-qualified paths after successful pull.
        _ = try runHostCommand(TKHostCommand(executable: record.adb, arguments: ["-s", record.rawTarget, "shell", "rm", "-f", remote, remote + ".pid"], riskLevel: .automation, defaultTimeoutSeconds: 3))
        if let duration = try? await deviceRecordingMediaDuration(staging.path), duration > 0 {
            // Native recording is valid; keep the original artifact.
        } else {
            try await deviceRecordingAndroidSnapshotFallback(record: &record, store: store, staging: staging)
        }
    }
}

private func deviceRecordingAndroidSnapshotFallback(record: inout DeviceRecordingSession, store: DeviceRecordingStore, staging: URL) async throws {
    try? FileManager.default.removeItem(at: staging)
    let writer = try AVAssetWriter(outputURL: staging, fileType: .mp4)
    defer { if writer.status == .writing || writer.status == .unknown { writer.cancelWriting() } }
    var input: AVAssetWriterInput?
    var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    var count = 0
    let started = Date()
    for _ in 0..<3 {
        guard !(try store.stopRequested(record.sessionID)) else { break }
        let result = try runHostCommand(TKAndroidADBCommand.screenshot(serial: record.rawTarget, executable: record.adb), maximumOutputBytes: 8 * 1024 * 1024)
        guard let image = NSImage(data: result.stdoutData), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DeviceRecordingFailure("recording_frame_failed", "Android screenshot fallback returned no verified image.")
        }
        if input == nil {
            let stream = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: cgImage.width, AVVideoHeightKey: cgImage.height])
            stream.expectsMediaDataInRealTime = true
            guard writer.canAdd(stream) else { throw DeviceRecordingFailure("recording_encoder_failed", "Cannot encode Android screenshot dimensions.") }
            writer.add(stream)
            adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: stream, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: cgImage.width, kCVPixelBufferHeightKey as String: cgImage.height, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
            input = stream
            guard writer.startWriting() else { throw DeviceRecordingFailure("recording_encoder_failed", writer.error?.localizedDescription ?? "Encoder refused start.") }
            writer.startSession(atSourceTime: .zero)
            record.state = "recording"
            try store.locked { try store.write(record) }
        }
        guard let input, let adaptor, let pool = adaptor.pixelBufferPool else { throw DeviceRecordingFailure("recording_encoder_failed", "Encoder buffer pool is unavailable.") }
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess, let buffer = pixelBuffer else { throw DeviceRecordingFailure("recording_encoder_failed", "Could not allocate bounded video frame.") }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard context != nil else { throw DeviceRecordingFailure("recording_encoder_failed", "Frame conversion failed.") }
        let timestamp = count == 0 ? CMTime.zero : CMTime(seconds: Date().timeIntervalSince(started), preferredTimescale: 600)
        guard input.isReadyForMoreMediaData, adaptor.append(buffer, withPresentationTime: timestamp) else { throw DeviceRecordingFailure("recording_encoder_failed", writer.error?.localizedDescription ?? "Frame append failed.") }
        count += 1
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    guard count > 1, let input else { throw DeviceRecordingFailure("recording_empty_media", "Android screenshot fallback requires at least two frames.") }
    record.sampleCount = count
    record.state = "stopping"
    try store.locked { try store.write(record) }
    input.markAsFinished()
    writer.finishWriting(completionHandler: {})
    let deadline = Date().addingTimeInterval(10)
    while writer.status == .writing, Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
    guard writer.status == .completed else { throw DeviceRecordingFailure("recording_encoder_failed", writer.error?.localizedDescription ?? "Video finalization failed.") }
}

private func deviceRecordingAndroidStop(_ record: DeviceRecordingSession) throws {
    let remote = "/data/local/tmp/triton-recording-\(record.sessionID).mp4"
    let script = "read p t < \(deviceRecordingShellQuote(remote + ".pid")) || exit 1; case $p in ''|*[!0-9]*) exit 2;; esac; [ -e /proc/$p/stat ] || exit 0; now=$(awk '{print $22}' /proc/$p/stat); [ \"$t\" = \"$now\" ] || exit 3; c=$(tr '\\000' ' ' < /proc/$p/cmdline); case \"$c\" in *screenrecord*triton-recording-\(record.sessionID).mp4*) kill -INT $p;; *) exit 4;; esac"
    let result = try runHostCommand(TKHostCommand(executable: record.adb, arguments: ["-s", record.rawTarget, "shell", script], riskLevel: .automation, defaultTimeoutSeconds: 4))
    guard result.exitCode == 0 else { throw DeviceRecordingFailure("recording_remote_identity_lost", "Remote recorder creation time or unique output identity could not be verified; no unrelated process was signalled.") }
}

private func deviceRecordingPublish(staging: String, record: DeviceRecordingSession) throws {
    try deviceRecordingCheckPath(record.output)
    let fd = open(record.output, O_WRONLY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { throw DeviceRecordingFailure("recording_output_changed", "Reserved output is no longer available.") }
    let destination = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? destination.close() }
    var info = stat()
    guard fstat(fd, &info) == 0, UInt64(info.st_dev) == record.outputDevice, UInt64(info.st_ino) == record.outputInode,
          info.st_uid == record.ownerUID, info.st_nlink == 1, info.st_size == 0 else { throw DeviceRecordingFailure("recording_output_changed", "Reserved output identity changed; no replacement file was overwritten.") }
    let source = try FileHandle(forReadingFrom: URL(fileURLWithPath: staging))
    defer { try? source.close() }
    while let data = try source.read(upToCount: 1024 * 1024), !data.isEmpty { try destination.write(contentsOf: data) }
    try destination.synchronize()
    guard lstat(record.output, &info) == 0, UInt64(info.st_dev) == record.outputDevice, UInt64(info.st_ino) == record.outputInode,
          info.st_mode & S_IFMT == S_IFREG else { throw DeviceRecordingFailure("recording_output_changed", "Artifact path changed while writing; original reservation was used safely.") }
    try FileManager.default.removeItem(atPath: staging)
}

private func deviceRecordingMediaDuration(_ path: String) async throws -> Double {
    let tracks = try await AVURLAsset(url: URL(fileURLWithPath: path)).loadTracks(withMediaType: .video)
    var durations: [Double] = []
    for track in tracks {
        guard let cursor = track.makeSampleCursorAtFirstSampleInDecodeOrder() else { continue }
        var first: CMTime?, end: CMTime?
        repeat {
            let time = cursor.presentationTimeStamp
            guard time.isNumeric else { break }
            first = first.map { CMTimeCompare($0, time) < 0 ? $0 : time } ?? time
            let tail = cursor.currentSampleDuration.isNumeric ? CMTimeAdd(time, cursor.currentSampleDuration) : time
            end = end.map { CMTimeCompare($0, tail) > 0 ? $0 : tail } ?? tail
        } while cursor.stepInDecodeOrder(byCount: 1) > 0
        if let first, let end { durations.append(CMTimeGetSeconds(CMTimeSubtract(end, first))) }
    }
    return try simulatorRecordingActualDuration(containerDurationSeconds: 0, videoTrackDurationSeconds: [], videoSampleDurationSeconds: durations.filter { $0.isFinite && $0 > 0 }.max())
}

private func deviceRecordingRunnerSequence(record: inout DeviceRecordingSession, store: DeviceRecordingStore, staging: URL) async throws {
    let writer = try AVAssetWriter(outputURL: staging, fileType: .mp4)
    defer { if writer.status == .writing || writer.status == .unknown { writer.cancelWriting() } }
    var input: AVAssetWriterInput?, adaptor: AVAssetWriterInputPixelBufferAdaptor?
    var count = 0
    var firstTime: Date?
    let deadline = record.startedAt.addingTimeInterval(record.maximumDurationSeconds)
    while Date() < deadline, !(try store.stopRequested(record.sessionID)) {
        let imagePath = try store.directory(record.sessionID).appendingPathComponent("frame-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: imagePath) }
        let data = try IOSRunnerService().execute(operation: "request", payload: iosRunnerJSON(["device": record.target, "route": "/environment", "body": ["operation": "screen"], "requestID": UUID().uuidString, "screenshotOutput": imagePath.path, "timeout": 5]))
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any], response["ok"] as? Bool == true,
              let image = NSImage(contentsOf: imagePath), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw DeviceRecordingFailure("recording_frame_failed", "Runner screenshot did not return a verified image; no action is retried.") }
        if input == nil {
            let stream = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: cgImage.width, AVVideoHeightKey: cgImage.height])
            stream.expectsMediaDataInRealTime = true
            guard writer.canAdd(stream) else { throw DeviceRecordingFailure("recording_encoder_failed", "Cannot encode Runner image dimensions.") }
            writer.add(stream)
            adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: stream, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: cgImage.width, kCVPixelBufferHeightKey as String: cgImage.height, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
            input = stream
            guard writer.startWriting() else { throw DeviceRecordingFailure("recording_encoder_failed", writer.error?.localizedDescription ?? "Encoder refused start.") }
            writer.startSession(atSourceTime: .zero)
            record.state = "recording"; try store.locked { try store.write(record) }
        }
        guard let adaptor, let input, let pool = adaptor.pixelBufferPool else { throw DeviceRecordingFailure("recording_encoder_failed", "Encoder buffer pool is unavailable.") }
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess, let buffer = pixelBuffer else { throw DeviceRecordingFailure("recording_encoder_failed", "Could not allocate bounded video frame.") }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard context != nil else { throw DeviceRecordingFailure("recording_encoder_failed", "Frame conversion failed.") }
        let readyDeadline = Date().addingTimeInterval(3)
        while !input.isReadyForMoreMediaData, Date() < readyDeadline { try await Task.sleep(nanoseconds: 10_000_000) }
        if firstTime == nil { firstTime = Date() }
        let timestamp = count == 0 ? CMTime.zero : CMTime(seconds: Date().timeIntervalSince(firstTime!), preferredTimescale: 600)
        guard input.isReadyForMoreMediaData, adaptor.append(buffer, withPresentationTime: timestamp) else { throw DeviceRecordingFailure("recording_encoder_failed", writer.error?.localizedDescription ?? "Frame append failed.") }
        count += 1
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    guard count > 1, let input else { writer.cancelWriting(); throw DeviceRecordingFailure("recording_empty_media", "At least two actual Runner screenshots are required to encode video.") }
    record.sampleCount = count; record.state = "stopping"; try store.locked { try store.write(record) }
    input.markAsFinished()
    writer.finishWriting(completionHandler: {})
    let finishDeadline = Date().addingTimeInterval(10)
    while writer.status == .writing, Date() < finishDeadline { try await Task.sleep(nanoseconds: 100_000_000) }
    guard writer.status == .completed else { throw DeviceRecordingFailure("recording_encoder_failed", writer.error?.localizedDescription ?? "Video finalization failed.") }
}
