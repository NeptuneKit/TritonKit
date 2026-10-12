import Darwin
import Foundation

/// Nonblocking, bounded-memory stderr capture. Stop never waits for inherited
/// child pipe writers to close; a failed helper may leave descendants behind.
final class WebIOSBaguetteStderrDrain: @unchecked Sendable {
    private let lock = NSLock()
    private let done = DispatchSemaphore(value: 0)
    private var stopping = false
    private var data = Data()
    private var bytes = 0
    private let maximumBytes = 16_384

    init(handle: FileHandle) {
        let descriptor = handle.fileDescriptor
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        DispatchQueue(label: "triton.host-hid.stderr").async { [self] in
            defer { try? handle.close(); done.signal() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = read(descriptor, &buffer, buffer.count)
                if count > 0 {
                    lock.lock()
                    bytes += count
                    let remaining = max(0, maximumBytes - data.count)
                    data.append(contentsOf: buffer.prefix(min(remaining, count)))
                    let stop = stopping
                    lock.unlock()
                    if stop { break }
                    continue
                }
                if count == 0 { break }
                if errno != EAGAIN && errno != EINTR { break }
                lock.lock()
                let stop = stopping
                lock.unlock()
                if stop { break }
                var descriptorState = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
                _ = poll(&descriptorState, 1, 25)
            }
        }
    }

    func finish() -> (data: Data, bytes: Int, truncated: Bool) {
        // Give an already exited process's finite buffered output a chance to
        // drain, but do not wait indefinitely for descendant-held pipe handles.
        if done.wait(timeout: .now() + 0.25) == .timedOut {
            lock.lock(); stopping = true; lock.unlock()
            _ = done.wait(timeout: .now() + 0.1)
        }
        lock.lock()
        defer { lock.unlock() }
        return (data, bytes, bytes > data.count || stopping)
    }
}
