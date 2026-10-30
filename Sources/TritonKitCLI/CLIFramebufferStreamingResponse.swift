import Foundation
import Hummingbird

enum FramebufferImageFormat: String, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
}

protocol FramebufferCaptureSession: AnyObject, Sendable {
    var running: Bool { get }
    /// A capture session keeps one encoded format for its lifetime.
    var imageFormat: FramebufferImageFormat { get }
    func start()
    func stop()
    func getLatestFrameWithVersion() -> (Data, UInt64)?
}

extension FramebufferCaptureSession {
    var imageFormat: FramebufferImageFormat { .jpeg }
}

final class FramebufferStreamSubscription: @unchecked Sendable {
    let session: any FramebufferCaptureSession
    private let lock = NSLock()
    private var release: (@Sendable () -> Void)?

    init(session: any FramebufferCaptureSession, release: @escaping @Sendable () -> Void) {
        self.session = session
        self.release = release
    }

    func cancel() {
        lock.lock()
        let release = self.release
        self.release = nil
        lock.unlock()
        release?()
    }

    deinit { cancel() }
}

final class FramebufferStreamRegistry: @unchecked Sendable {
    private struct Entry {
        let session: any FramebufferCaptureSession
        var subscribers: Int
    }
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    func subscribe(target: String, makeSession: () -> any FramebufferCaptureSession) -> FramebufferStreamSubscription {
        lock.lock()
        let session: any FramebufferCaptureSession
        if var entry = entries[target], entry.session.running {
            entry.subscribers += 1
            entries[target] = entry
            session = entry.session
        } else {
            session = makeSession()
            session.start()
            entries[target] = Entry(session: session, subscribers: 1)
        }
        lock.unlock()
        return FramebufferStreamSubscription(session: session) { [self] in
            unsubscribe(target: target, session: session)
        }
    }

    private func unsubscribe(target: String, session: any FramebufferCaptureSession) {
        lock.lock()
        // A terminal capture may have been replaced while an old HTTP body was unwinding.
        // Release only the generation acquired by this subscription.
        guard var entry = entries[target], entry.session === session else { lock.unlock(); return }
        entry.subscribers -= 1
        if entry.subscribers > 0 {
            entries[target] = entry
            lock.unlock()
        } else {
            entries.removeValue(forKey: target)
            lock.unlock()
            entry.session.stop()
        }
    }
}

func framebufferStreamingResponse(
    request: Request,
    framesPerSecond: Int,
    subscribe: @escaping @Sendable () -> FramebufferStreamSubscription
) -> Response {
    let boundary = "tritonboundary"
    let body = ResponseBody { writer in
        // Hummingbird can fail writing the head without ever executing this body.
        // Acquire only here, and listen for inbound close even before the first frame.
        try await request.body.consumeWithCancellationOnInboundClose { _ in
            try Task.checkCancellation()
            let subscription = subscribe()
            defer { subscription.cancel() }
            var lastSentVersion: UInt64 = 0
            var lastWriteTime = Date().timeIntervalSince1970
            while subscription.session.running {
                try Task.checkCancellation()
                if let (frameData, version) = subscription.session.getLatestFrameWithVersion() {
                    let now = Date().timeIntervalSince1970
                    if version != lastSentVersion || now - lastWriteTime >= 1 {
                        lastSentVersion = version
                        lastWriteTime = now
                        var buffer = ByteBuffer()
                        buffer.writeString("--\(boundary)\r\nContent-Type: \(subscription.session.imageFormat.rawValue)\r\nContent-Length: \(frameData.count)\r\n\r\n")
                        buffer.writeBytes(frameData)
                        buffer.writeString("\r\n")
                        do { try await writer.write(buffer) } catch { break }
                    }
                }
                try await Task.sleep(for: .seconds(1.0 / Double(max(1, framesPerSecond))))
            }
            try? await writer.finish(nil)
        }
    }
    return Response(status: .ok, headers: [
        .contentType: "multipart/x-mixed-replace; boundary=\(boundary)",
        .cacheControl: "no-cache, no-store, must-revalidate",
        .connection: "close",
    ], body: body)
}
