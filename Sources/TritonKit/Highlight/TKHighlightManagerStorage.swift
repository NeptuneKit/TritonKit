#if canImport(UIKit)
import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

enum TKHighlightRequestContext {
    @TaskLocal static var generation: UInt64?
}

/// Only the reference and cleanup fence cross threads. All manager/UI methods stay on MainActor.
final class TKHighlightManagerStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var manager: TKHighlightSessionManager?
    private var generation: UInt64 = 0
    private var pending = false

    func get() -> TKHighlightSessionManager? {
        lock.lock(); defer { lock.unlock() }
        return manager
    }
    func set(_ value: TKHighlightSessionManager) {
        lock.lock(); defer { lock.unlock() }
        manager = value
    }
    func beginCleanup() -> (TKHighlightSessionManager?, UInt64) {
        lock.lock(); defer { lock.unlock() }
        generation &+= 1
        pending = true
        return (manager, generation)
    }
    var currentGeneration: UInt64 {
        lock.lock(); defer { lock.unlock() }
        return generation
    }
    var requestGeneration: UInt64 {
        lock.lock(); defer { lock.unlock() }
        // Requests received during stop carry a stale token even if cleanup finishes before dispatch.
        return pending ? generation &- 1 : generation
    }
    @MainActor func prepareApply(expectedGeneration: UInt64, create: () -> TKHighlightSessionManager) -> TKHighlightSessionManager? {
        lock.lock(); defer { lock.unlock() }
        guard generation == expectedGeneration, !pending else { return nil }
        if let manager { return manager }
        let value = create()
        manager = value
        return value
    }
    @MainActor func performCleanup(manager: TKHighlightSessionManager?, generation: UInt64) -> TKHighlightReceipt? {
        guard currentGeneration == generation else { return nil }
        let receipt = manager?.shutdown()
        completeCleanup(generation)
        return receipt
    }
    func completeCleanup(_ completedGeneration: UInt64) {
        lock.lock(); defer { lock.unlock() }
        if generation == completedGeneration { pending = false }
    }
    var cleanupPending: Bool {
        lock.lock(); defer { lock.unlock() }
        return pending
    }
}
#endif
