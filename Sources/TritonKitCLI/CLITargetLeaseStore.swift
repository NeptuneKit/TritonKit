import Foundation
import TritonKitShared

// MARK: - Target Lease Store
//
// Pure, thread-safe state machine holding at most one active lease per
// normalized simulator target. All methods take `now` explicitly so tests can
// drive TTL expiry deterministically without real time or servers.

struct TargetLeaseStoreValidationError: Error, Equatable {
    let code: String
    let message: String
    let hint: String?

    init(code: String, message: String, hint: String?) {
        self.code = code
        self.message = message
        self.hint = hint
    }
}

struct TargetLeaseStoreAcquireResult: Equatable {
    /// `acquired`, `already_held`, or `taken_over`.
    let status: String
    let lease: TKTargetLease
    let previousOwner: String?
}

enum TargetLeaseAcquireOutcome: Equatable {
    case acquired(TargetLeaseStoreAcquireResult)
    case conflict(current: TKTargetLease)
}

enum TargetLeaseReleaseOutcome: Equatable {
    case released(TKTargetLease)
    case none
    case conflict(current: TKTargetLease)
}

enum TargetLeaseCheckDecision: Equatable {
    case authorized(TKTargetLease)
    /// `reason` is one of `held_by_other`, `lease_expired`, `lease_not_held`.
    case conflict(reason: String, current: TKTargetLease?)
}

final class TargetLeaseStore: @unchecked Sendable {
    private let lock = NSLock()
    private var leases: [String: TKTargetLease] = [:]

    func acquire(
        target: String,
        owner: String,
        ttlSeconds: Int?,
        readonlyObservationAllowed: Bool?,
        now: Date
    ) throws -> TargetLeaseAcquireOutcome {
        let key = try validatedKey(target: target, owner: owner, ttlSeconds: ttlSeconds)
        let ttl = resolvedTTL(ttlSeconds)
        return lock.withLock {
            guard let existing = leases[key] else {
                return .acquired(makeLease(key: key, owner: owner, ttl: ttl, readonlyObservationAllowed: readonlyObservationAllowed, now: now))
            }
            if existing.expiresAt > now {
                if existing.owner == owner {
                    return .acquired(TargetLeaseStoreAcquireResult(status: "already_held", lease: existing, previousOwner: nil))
                }
                return .conflict(current: existing)
            }
            return .acquired(makeLease(key: key, owner: owner, ttl: ttl, readonlyObservationAllowed: readonlyObservationAllowed, now: now))
        }
    }

    func status(target: String, now: Date) -> (status: String, lease: TKTargetLease?) {
        let key = TKNormalizeTargetLeaseKey(target)
        return lock.withLock {
            guard let lease = leases[key] else {
                return ("none", nil)
            }
            if lease.expiresAt <= now {
                return ("expired", lease)
            }
            return ("held", lease)
        }
    }

    func release(target: String, leaseID: String, now: Date) -> TargetLeaseReleaseOutcome {
        let key = TKNormalizeTargetLeaseKey(target)
        return lock.withLock {
            guard let existing = leases[key] else {
                return .none
            }
            guard existing.id == leaseID else {
                return .conflict(current: existing)
            }
            leases.removeValue(forKey: key)
            return .released(existing)
        }
    }

    func takeover(
        target: String,
        owner: String,
        ttlSeconds: Int?,
        readonlyObservationAllowed: Bool?,
        confirm: Bool,
        now: Date
    ) throws -> TargetLeaseAcquireOutcome {
        let key = try validatedKey(target: target, owner: owner, ttlSeconds: ttlSeconds)
        let ttl = resolvedTTL(ttlSeconds)
        return lock.withLock {
            guard let existing = leases[key], existing.expiresAt > now else {
                return .acquired(makeLease(key: key, owner: owner, ttl: ttl, readonlyObservationAllowed: readonlyObservationAllowed, now: now))
            }
            if existing.owner == owner {
                return .acquired(TargetLeaseStoreAcquireResult(status: "already_held", lease: existing, previousOwner: nil))
            }
            guard confirm else {
                return .conflict(current: existing)
            }
            let made = makeLease(key: key, owner: owner, ttl: ttl, readonlyObservationAllowed: readonlyObservationAllowed, now: now)
            return .acquired(TargetLeaseStoreAcquireResult(status: "taken_over", lease: made.lease, previousOwner: existing.owner))
        }
    }

    func check(target: String, leaseID: String, now: Date) -> TargetLeaseCheckDecision {
        let key = TKNormalizeTargetLeaseKey(target)
        return lock.withLock {
            guard let existing = leases[key] else {
                return .conflict(reason: "lease_not_held", current: nil)
            }
            guard existing.id == leaseID else {
                return .conflict(reason: "held_by_other", current: existing)
            }
            guard existing.expiresAt > now else {
                return .conflict(reason: "lease_expired", current: existing)
            }
            return .authorized(existing)
        }
    }

    /// All currently stored leases (including expired), for audit and tests.
    func allLeases() -> [TKTargetLease] {
        lock.withLock {
            Array(leases.values).sorted { $0.target < $1.target }
        }
    }

    // MARK: - Helpers

    private func validatedKey(target: String, owner: String, ttlSeconds: Int?) throws -> String {
        let key = TKNormalizeTargetLeaseKey(target)
        guard !key.isEmpty else {
            throw TargetLeaseStoreValidationError(
                code: "lease_target_required",
                message: "A target lease requires a non-empty target.",
                hint: "Pass `--target <simulator-udid-or-selector>`."
            )
        }
        guard !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TargetLeaseStoreValidationError(
                code: "lease_owner_required",
                message: "A target lease requires an opaque owner label.",
                hint: "Pass `--owner <label>` so parallel flows can identify the current lease holder."
            )
        }
        if let ttlSeconds {
            guard (TKTargetLeaseMinTTLSeconds...TKTargetLeaseMaxTTLSeconds).contains(ttlSeconds) else {
                throw TargetLeaseStoreValidationError(
                    code: "lease_ttl_out_of_range",
                    message: "Lease TTL must be between \(TKTargetLeaseMinTTLSeconds) and \(TKTargetLeaseMaxTTLSeconds) seconds.",
                    hint: "Pass `--ttl <seconds>` within the bounded range."
                )
            }
        }
        return key
    }

    private func resolvedTTL(_ ttlSeconds: Int?) -> Int {
        ttlSeconds ?? TKTargetLeaseDefaultTTLSeconds
    }

    private func makeLease(
        key: String,
        owner: String,
        ttl: Int,
        readonlyObservationAllowed: Bool?,
        now: Date
    ) -> TargetLeaseStoreAcquireResult {
        let lease = TKTargetLease(
            id: UUID().uuidString.lowercased(),
            target: key,
            owner: owner,
            acquiredAt: now,
            expiresAt: now.addingTimeInterval(TimeInterval(ttl)),
            ttlSeconds: ttl,
            readonlyObservationAllowed: readonlyObservationAllowed ?? true
        )
        leases[key] = lease
        return TargetLeaseStoreAcquireResult(status: "acquired", lease: lease, previousOwner: nil)
    }
}
