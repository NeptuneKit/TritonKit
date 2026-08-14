import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Target lease store state machine")
struct TargetLeaseStoreTests {
    private let udid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("acquire creates a bounded-TTL lease with the caller owner label")
    func acquireCreatesBoundedTTLLease() throws {
        let store = TargetLeaseStore()
        let outcome = try store.acquire(
            target: "sim:\(udid)",
            owner: "agent-a",
            ttlSeconds: 120,
            readonlyObservationAllowed: true,
            now: now
        )

        guard case .acquired(let result) = outcome else {
            Issue.record("expected acquired, got \(outcome)")
            return
        }
        #expect(result.status == "acquired")
        #expect(result.lease.target == udid)
        #expect(result.lease.owner == "agent-a")
        #expect(result.lease.ttlSeconds == 120)
        #expect(result.lease.acquiredAt == now)
        #expect(result.lease.expiresAt == now.addingTimeInterval(120))
        #expect(result.lease.readonlyObservationAllowed)
        #expect(result.lease.kind == "triton.target-lease")
        #expect(result.lease.id.isEmpty == false)
    }

    @Test("acquire defaults the TTL when omitted")
    func acquireDefaultsTTL() throws {
        let store = TargetLeaseStore()
        let outcome = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: nil, readonlyObservationAllowed: nil, now: now)

        guard case .acquired(let result) = outcome else {
            Issue.record("expected acquired, got \(outcome)")
            return
        }
        #expect(result.lease.ttlSeconds == 300)
        #expect(result.lease.expiresAt == now.addingTimeInterval(300))
    }

    @Test("acquire rejects out-of-range TTL and empty owner")
    func acquireValidatesTTLAndOwner() {
        let store = TargetLeaseStore()

        #expect(throws: TargetLeaseStoreValidationError.self) {
            _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 10, readonlyObservationAllowed: nil, now: now)
        }
        #expect(throws: TargetLeaseStoreValidationError.self) {
            _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 100_000, readonlyObservationAllowed: nil, now: now)
        }
        #expect(throws: TargetLeaseStoreValidationError.self) {
            _ = try store.acquire(target: udid, owner: "   ", ttlSeconds: nil, readonlyObservationAllowed: nil, now: now)
        }
        #expect(throws: TargetLeaseStoreValidationError.self) {
            _ = try store.acquire(target: "  ", owner: "agent-a", ttlSeconds: nil, readonlyObservationAllowed: nil, now: now)
        }
    }

    @Test("acquire conflicts when another owner holds the lease")
    func acquireConflictsWhenHeldByOtherOwner() throws {
        let store = TargetLeaseStore()
        _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)

        let outcome = try store.acquire(target: udid, owner: "agent-b", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)

        guard case .conflict(let current) = outcome else {
            Issue.record("expected conflict, got \(outcome)")
            return
        }
        #expect(current.owner == "agent-a")
        #expect(current.id.isEmpty == false)
    }

    @Test("same owner re-acquire is idempotent already_held")
    func sameOwnerReacquireIsAlreadyHeld() throws {
        let store = TargetLeaseStore()
        let first = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)
        guard case .acquired(let firstResult) = first else {
            Issue.record("expected acquired, got \(first)")
            return
        }

        let second = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)

        guard case .acquired(let secondResult) = second else {
            Issue.record("expected acquired, got \(second)")
            return
        }
        #expect(secondResult.status == "already_held")
        #expect(secondResult.lease.id == firstResult.lease.id)
    }

    @Test("acquire replaces an expired lease")
    func acquireReplacesExpiredLease() throws {
        let store = TargetLeaseStore()
        _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 30, readonlyObservationAllowed: nil, now: now)

        let later = now.addingTimeInterval(60)
        let outcome = try store.acquire(target: udid, owner: "agent-b", ttlSeconds: 300, readonlyObservationAllowed: nil, now: later)

        guard case .acquired(let result) = outcome else {
            Issue.record("expected acquired after expiry, got \(outcome)")
            return
        }
        #expect(result.status == "acquired")
        #expect(result.lease.owner == "agent-b")
    }

    @Test("status reports none, held, and expired")
    func statusReportsNoneHeldExpired() throws {
        let store = TargetLeaseStore()

        let none = store.status(target: udid, now: now)
        #expect(none.status == "none")
        #expect(none.lease == nil)

        _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 30, readonlyObservationAllowed: nil, now: now)
        let held = store.status(target: udid, now: now)
        #expect(held.status == "held")
        #expect(held.lease?.owner == "agent-a")

        let expired = store.status(target: udid, now: now.addingTimeInterval(60))
        #expect(expired.status == "expired")
        #expect(expired.lease?.owner == "agent-a")
    }

    @Test("release removes a matching lease and is a no-op when none is held")
    func releaseRemovesMatchingLease() throws {
        let store = TargetLeaseStore()
        let acquired = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)
        guard case .acquired(let result) = acquired else {
            Issue.record("expected acquired, got \(acquired)")
            return
        }

        let released = store.release(target: udid, leaseID: result.lease.id, now: now)
        guard case .released(let lease) = released else {
            Issue.record("expected released, got \(released)")
            return
        }
        #expect(lease.id == result.lease.id)
        #expect(store.status(target: udid, now: now).status == "none")

        let none = store.release(target: udid, leaseID: "missing", now: now)
        #expect(none == .none)
    }

    @Test("release with a mismatched token conflicts and keeps the lease")
    func releaseWithMismatchedTokenConflicts() throws {
        let store = TargetLeaseStore()
        _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)

        let outcome = store.release(target: udid, leaseID: "wrong-token", now: now)

        guard case .conflict(let current) = outcome else {
            Issue.record("expected conflict, got \(outcome)")
            return
        }
        #expect(current.owner == "agent-a")
        #expect(store.status(target: udid, now: now).status == "held")
    }

    @Test("takeover without confirm conflicts with a takeover-required signal")
    func takeoverWithoutConfirmConflicts() throws {
        let store = TargetLeaseStore()
        _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)

        let outcome = try store.takeover(target: udid, owner: "agent-b", ttlSeconds: 300, readonlyObservationAllowed: nil, confirm: false, now: now)

        guard case .conflict(let current) = outcome else {
            Issue.record("expected conflict, got \(outcome)")
            return
        }
        #expect(current.owner == "agent-a")
    }

    @Test("takeover with confirm displaces the previous owner")
    func takeoverWithConfirmDisplacesPreviousOwner() throws {
        let store = TargetLeaseStore()
        let first = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)
        guard case .acquired(let firstResult) = first else {
            Issue.record("expected acquired, got \(first)")
            return
        }

        let outcome = try store.takeover(target: udid, owner: "agent-b", ttlSeconds: 120, readonlyObservationAllowed: false, confirm: true, now: now)

        guard case .acquired(let result) = outcome else {
            Issue.record("expected acquired takeover, got \(outcome)")
            return
        }
        #expect(result.status == "taken_over")
        #expect(result.previousOwner == "agent-a")
        #expect(result.lease.owner == "agent-b")
        #expect(result.lease.id != firstResult.lease.id)
    }

    @Test("takeover by the same owner is already_held")
    func takeoverBySameOwnerIsAlreadyHeld() throws {
        let store = TargetLeaseStore()
        _ = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)

        let outcome = try store.takeover(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, confirm: true, now: now)

        guard case .acquired(let result) = outcome else {
            Issue.record("expected acquired, got \(outcome)")
            return
        }
        #expect(result.status == "already_held")
    }

    @Test("check authorizes a matching unexpired lease")
    func checkAuthorizesMatchingLease() throws {
        let store = TargetLeaseStore()
        let acquired = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)
        guard case .acquired(let result) = acquired else {
            Issue.record("expected acquired, got \(acquired)")
            return
        }

        let decision = store.check(target: "sim:\(udid)", leaseID: result.lease.id, now: now)

        guard case .authorized(let lease) = decision else {
            Issue.record("expected authorized, got \(decision)")
            return
        }
        #expect(lease.owner == "agent-a")
    }

    @Test("check conflicts for other owner, expired lease, and no lease")
    func checkConflictsForOtherOwnerExpiredAndNoLease() throws {
        let store = TargetLeaseStore()
        let acquired = try store.acquire(target: udid, owner: "agent-a", ttlSeconds: 30, readonlyObservationAllowed: nil, now: now)
        guard case .acquired(let result) = acquired else {
            Issue.record("expected acquired, got \(acquired)")
            return
        }

        let otherOwner = store.check(target: udid, leaseID: "some-other-token", now: now)
        guard case .conflict(let reason, let current) = otherOwner, reason == "held_by_other" else {
            Issue.record("expected held_by_other conflict, got \(otherOwner)")
            return
        }
        #expect(current?.owner == "agent-a")

        let expired = store.check(target: udid, leaseID: result.lease.id, now: now.addingTimeInterval(60))
        guard case .conflict(let expiredReason, _) = expired, expiredReason == "lease_expired" else {
            Issue.record("expected lease_expired conflict, got \(expired)")
            return
        }

        let noLease = store.check(target: "E5D4C3B2-A1F0-4B6A-8C9D-0E1F2A3B4C5D", leaseID: "missing", now: now)
        guard case .conflict(let noLeaseReason, _) = noLease, noLeaseReason == "lease_not_held" else {
            Issue.record("expected lease_not_held conflict, got \(noLease)")
            return
        }
    }

    @Test("store normalizes acquire and check selectors to the same key")
    func storeNormalizesSelectorsToTheSameKey() throws {
        let store = TargetLeaseStore()
        let acquired = try store.acquire(target: "triton:ios-simulator:\(udid)/app:com.example.app", owner: "agent-a", ttlSeconds: 300, readonlyObservationAllowed: nil, now: now)
        guard case .acquired(let result) = acquired else {
            Issue.record("expected acquired, got \(acquired)")
            return
        }

        #expect(result.lease.target == udid)
        let decision = store.check(target: "sim:\(udid)", leaseID: result.lease.id, now: now)
        guard case .authorized = decision else {
            Issue.record("expected authorized after normalization, got \(decision)")
            return
        }
    }
}
