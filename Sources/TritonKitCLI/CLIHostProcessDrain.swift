import Darwin
import Foundation

/// Shared by all streams of one command. The budget starts only after the direct
/// child exits (or its execution timeout has been handled), never at launch.
final class HostPipeDrainDeadline: @unchecked Sendable {
    static let budgetSeconds = 0.25
    private let lock = NSLock()
    private var deadline: UInt64?

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        if deadline == nil {
            deadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
        }
    }

    var expired: Bool {
        lock.lock()
        defer { lock.unlock() }
        return deadline.map { DispatchTime.now().uptimeNanoseconds >= $0 } ?? false
    }
}

enum HostProcessOutputError: Error, CustomStringConvertible, LocalizedError {
    case incomplete(observedBytes: Int)
    case readFailed(code: Int32)

    var code: String {
        switch self {
        case .incomplete: "host_output_incomplete"
        case .readFailed: "host_output_read_failed"
        }
    }

    var description: String {
        switch self {
        case .incomplete(let bytes):
            "Host output did not reach EOF within the \(HostPipeDrainDeadline.budgetSeconds)s post-exit drain budget (observed \(bytes) bytes on this stream). Command was not replayed."
        case .readFailed(let code):
            "Host output read failed: \(String(cString: strerror(code)))"
        }
    }

    var errorDescription: String? { description }
}

/// The worker exclusively owns reading and closing its handle. Nonblocking reads
/// plus short poll intervals let it join without cross-thread FileHandle.close,
/// even when an unrelated descendant retains the pipe's write descriptor.
func drainHostPipe(
    _ pipe: Pipe,
    deadline: HostPipeDrainDeadline,
    consume: (Data) throws -> Void
) throws {
    let input = pipe.fileHandleForReading
    defer { try? input.close() }
    try drainHostDescriptor(input.fileDescriptor, deadline: deadline, consume: consume)
}

func drainHostDescriptor(
    _ fd: Int32,
    deadline: HostPipeDrainDeadline,
    consume: (Data) throws -> Void
) throws {
    let flags = fcntl(fd, F_GETFL)
    guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else {
        throw HostProcessOutputError.readFailed(code: errno)
    }
    let capacity = 64 * 1024
    var buffer = [UInt8](repeating: 0, count: capacity)
    var observedBytes = 0
    while true {
        // Check even while continuously readable, so a descendant cannot keep
        // the worker alive indefinitely by writing without ever closing.
        if deadline.expired {
            throw HostProcessOutputError.incomplete(observedBytes: observedBytes)
        }
        let count = Darwin.read(fd, &buffer, capacity)
        if count == 0 { return } // Only a real zero-byte read establishes EOF.
        if count > 0 {
            observedBytes += count
            try consume(Data(buffer.prefix(count)))
            continue
        }
        let readError = errno
        if readError == EINTR { continue }
        guard readError == EAGAIN || readError == EWOULDBLOCK else {
            throw HostProcessOutputError.readFailed(code: readError)
        }
        var descriptor = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
        let ready = poll(&descriptor, 1, 10)
        if ready < 0 && errno != EINTR {
            throw HostProcessOutputError.readFailed(code: errno)
        }
        if ready > 0 && (descriptor.revents & Int16(POLLNVAL)) != 0 {
            throw HostProcessOutputError.readFailed(code: EBADF)
        }
    }
}

/// A joined worker result. No mutable local result escapes into a concurrent
/// closure, and callers cannot observe a value before the worker has finished.
final class HostPipeDrainTask<Value>: @unchecked Sendable {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var value: Value?

    init(queue: DispatchQueue, work: @escaping @Sendable () -> Value) {
        group.enter()
        queue.async {
            let result = work()
            self.lock.lock()
            self.value = result
            self.lock.unlock()
            self.group.leave()
        }
    }

    @discardableResult
    func wait() -> Value {
        group.wait()
        lock.lock()
        defer { lock.unlock() }
        return value!
    }
}

/// Internal evidence for a failed capture: output completeness and the direct
/// child's exit status are independent facts. Never discard either one.
struct HostProcessOutputFailure: Error, CustomStringConvertible, LocalizedError {
    let cause: HostProcessOutputError
    let result: HostProcessResult
    var artifactBytes: Int? = nil

    var description: String {
        "\(cause)\nexitCode: \(result.exitCode)\nstdoutBytes: \(result.stdoutBytes)\nstderrBytes: \(result.stderrBytes)"
    }

    var errorDescription: String? { description }
}
