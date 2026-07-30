import Foundation

/// Serializes logical WebSocket generations independently from URLSession callbacks.
/// A cancelled URLSession task may still complete after a replacement task starts, so
/// every receive, ping, and async response must prove it belongs to the current generation.
final class RuntimeConnectionLifecycle: @unchecked Sendable {
    typealias Generation = UInt64

    private let lock = NSLock()
    private var generation: Generation = 0
    private var pendingReconnectGeneration: Generation?

    var currentGeneration: Generation {
        lock.withLock { generation }
    }

    var hasPendingReconnect: Bool {
        lock.withLock { pendingReconnectGeneration != nil }
    }

    @discardableResult
    func beginConnection() -> Generation {
        lock.withLock {
            generation &+= 1
            pendingReconnectGeneration = nil
            return generation
        }
    }

    func stop() {
        lock.withLock {
            generation &+= 1
            pendingReconnectGeneration = nil
        }
    }

    func acceptsCallback(for candidate: Generation) -> Bool {
        lock.withLock { candidate == generation }
    }

    @discardableResult
    func scheduleReconnect(for candidate: Generation) -> Bool {
        lock.withLock {
            guard candidate == generation, pendingReconnectGeneration == nil else {
                return false
            }
            pendingReconnectGeneration = candidate
            return true
        }
    }

    @discardableResult
    func consumeReconnect(for candidate: Generation) -> Bool {
        lock.withLock {
            guard candidate == generation, pendingReconnectGeneration == candidate else {
                return false
            }
            pendingReconnectGeneration = nil
            return true
        }
    }
}
