import Foundation
import Darwin

struct FramebufferFrameworkPlan: Equatable {
    let developerDirectory: String
    let coreSimulator: String
    let simulatorKit: String
}

func framebufferFrameworkPlan(
    developerDirectory: String?,
    fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
) -> FramebufferFrameworkPlan? {
    guard let raw = developerDirectory?.trimmingCharacters(in: .whitespacesAndNewlines), raw.hasPrefix("/") else { return nil }
    let selected = URL(fileURLWithPath: raw, isDirectory: true)
    let developer = selected.pathExtension == "app" ? selected.appendingPathComponent("Contents/Developer") : selected
    guard let simulatorKit = simulatorKitFrameworkCandidates(developerDirectory: developer.path).first(where: { fileExists($0.path) })?.path else { return nil }
    let contents = developer.deletingLastPathComponent()
    let coreCandidates = [
        contents.appendingPathComponent("SharedFrameworks/CoreSimulator.framework/CoreSimulator").path,
        contents.appendingPathComponent("SharedFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator").path,
        developer.appendingPathComponent("Library/PrivateFrameworks/CoreSimulator.framework/CoreSimulator").path,
        developer.appendingPathComponent("Library/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator").path,
        // CoreSimulator is installed system-wide by Xcode; never search another Xcode bundle.
        "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",
        "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator",
    ]
    guard let coreSimulator = coreCandidates.first(where: fileExists) else { return nil }
    return .init(developerDirectory: developer.path, coreSimulator: coreSimulator, simulatorKit: simulatorKit)
}

/// ObjC private classes cannot be unloaded or replaced safely in a server.
final class FramebufferFrameworkLoader {
    private var pinnedPlan: FramebufferFrameworkPlan?
    private var loaded = false
    func load(_ plan: FramebufferFrameworkPlan, load: (String) -> Bool) -> Bool {
        if let pinnedPlan, pinnedPlan != plan { return false }
        if loaded { return true }
        guard load(plan.coreSimulator) else { return false }
        pinnedPlan = plan
        loaded = load(plan.simulatorKit)
        return loaded
    }
}

struct FramebufferCaptureResult {
    let stdout: Data
    let stderr: Data
    let exitStatus: Int32
}

/// One session owns one helper at a time. Both pipes are drained without blocking;
/// stop permanently closes this runner, so no cancelled session can relaunch.
final class FramebufferCaptureProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var active: Process?
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        let process = active
        lock.unlock()
        if let process, process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }

    func run(executable: String, arguments: [String], timeout: TimeInterval = 5, maximumOutputBytes: Int = 16 * 1024 * 1024) -> FramebufferCaptureResult? {
        guard timeout.isFinite, timeout > 0, maximumOutputBytes > 0 else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let output = Pipe(), error = Pipe()
        process.standardOutput = output
        process.standardError = error
        let capture = FramebufferCaptureBuffer(maximumBytes: maximumOutputBytes)
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        let outputFD = output.fileHandleForReading.fileDescriptor
        let errorFD = error.fileHandleForReading.fileDescriptor
        _ = fcntl(outputFD, F_SETFL, fcntl(outputFD, F_GETFL) | O_NONBLOCK)
        _ = fcntl(errorFD, F_SETFL, fcntl(errorFD, F_GETFL) | O_NONBLOCK)
        func drain(_ fd: Int32, stderr: Bool) {
            var bytes = [UInt8](repeating: 0, count: 16384)
            // Alternate pipes and check the deadline even for a continuous writer.
            for _ in 0..<64 {
                guard !capture.exceeded else { break }
                let count = read(fd, &bytes, bytes.count)
                guard count > 0 else { break }
                capture.append(Data(bytes.prefix(count)), stderr: stderr)
            }
        }
        defer {
            try? output.fileHandleForReading.close()
            try? error.fileHandleForReading.close()
            process.terminationHandler = nil
            lock.lock()
            if active === process { active = nil }
            lock.unlock()
        }
        lock.lock()
        guard !cancelled, active == nil else { lock.unlock(); return nil }
        active = process
        do { try process.run() } catch { active = nil; lock.unlock(); return nil }
        lock.unlock()
        let deadline = Date().addingTimeInterval(timeout)
        var exited = false
        while Date() < deadline {
            drain(outputFD, stderr: false)
            drain(errorFD, stderr: true)
            if finished.wait(timeout: .now() + 0.02) == .success {
                drain(outputFD, stderr: false)
                drain(errorFD, stderr: true)
                exited = true
                break
            }
            lock.lock(); let stopped = cancelled; lock.unlock()
            if stopped || capture.exceeded { break }
        }
        lock.lock(); let stopped = cancelled; lock.unlock()
        guard exited, !stopped, !capture.exceeded else {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            _ = finished.wait(timeout: .now() + 0.5)
            return nil
        }
        // Nonblocking reads also bound shutdown when descendants inherit pipes.
        return capture.result(exitStatus: process.terminationStatus)
    }
}

private final class FramebufferCaptureBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var output = Data(), error = Data()
    private var overflow = false
    init(maximumBytes: Int) { self.maximumBytes = maximumBytes }
    var exceeded: Bool { lock.lock(); defer { lock.unlock() }; return overflow }
    func append(_ data: Data, stderr: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard !overflow else { return }
        guard data.count <= maximumBytes - output.count - error.count else { overflow = true; return }
        if stderr { error.append(data) } else { output.append(data) }
    }
    func result(exitStatus: Int32) -> FramebufferCaptureResult? {
        lock.lock(); defer { lock.unlock() }
        return overflow ? nil : .init(stdout: output, stderr: error, exitStatus: exitStatus)
    }
}
