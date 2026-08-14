import Foundation

// MARK: - Target Lease Wire Contract
//
// An opt-in, auditable reservation of a concrete iOS Simulator target for a
// bounded TTL. The `triton serve` process is the shared-state holder; agent
// workflows acquire a lease with an opaque owner label, pass the returned
// lease id as `--lease <id>` to mutating host/runtime commands, and resolve
// conflicts with the stable `target_lease_conflict` envelope instead of
// silently changing another flow's foreground state.
//
// The feature is opt-in: when no lease is held and no `--lease` token is
// passed, mutating commands behave exactly as before.

public let TKTargetLeaseKind = "triton.target-lease"
public let TKTargetLeaseDefaultTTLSeconds = 300
public let TKTargetLeaseMinTTLSeconds = 30
public let TKTargetLeaseMaxTTLSeconds = 86_400

/// One held target lease. `id` is the opaque lease token callers must pass
/// back as `--lease <id>` on mutating commands.
public struct TKTargetLease: Codable, Equatable, Sendable {
    public let id: String
    public let target: String
    public let owner: String
    public let acquiredAt: Date
    public let expiresAt: Date
    public let ttlSeconds: Int
    /// Read-only observation commands are exempt from lease conflicts; this
    /// policy flag is surfaced in envelopes for local diagnostics/audit.
    public let readonlyObservationAllowed: Bool
    public let kind: String

    public init(
        id: String,
        target: String,
        owner: String,
        acquiredAt: Date,
        expiresAt: Date,
        ttlSeconds: Int,
        readonlyObservationAllowed: Bool = true,
        kind: String = TKTargetLeaseKind
    ) {
        self.id = id
        self.target = target
        self.owner = owner
        self.acquiredAt = acquiredAt
        self.expiresAt = expiresAt
        self.ttlSeconds = ttlSeconds
        self.readonlyObservationAllowed = readonlyObservationAllowed
        self.kind = kind
    }
}

public struct TKTargetLeaseAcquireRequest: Codable, Equatable, Sendable {
    public let target: String
    public let owner: String
    public let ttlSeconds: Int?
    public let readonlyObservationAllowed: Bool?

    public init(target: String, owner: String, ttlSeconds: Int?, readonlyObservationAllowed: Bool?) {
        self.target = target
        self.owner = owner
        self.ttlSeconds = ttlSeconds
        self.readonlyObservationAllowed = readonlyObservationAllowed
    }
}

/// Shared by acquire and takeover responses. `status` is one of
/// `acquired`, `already_held`, or `taken_over`.
public struct TKTargetLeaseAcquireResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let status: String
    public let target: String
    public let lease: TKTargetLease?
    public let previousOwner: String?

    public init(ok: Bool, status: String, target: String, lease: TKTargetLease?, previousOwner: String? = nil) {
        self.ok = ok
        self.status = status
        self.target = target
        self.lease = lease
        self.previousOwner = previousOwner
    }
}

public struct TKTargetLeaseStatusResponse: Codable, Equatable, Sendable {
    /// `held`, `expired`, or `none`.
    public let ok: Bool
    public let target: String
    public let status: String
    public let lease: TKTargetLease?

    public init(ok: Bool, target: String, status: String, lease: TKTargetLease?) {
        self.ok = ok
        self.target = target
        self.status = status
        self.lease = lease
    }
}

public struct TKTargetLeaseReleaseRequest: Codable, Equatable, Sendable {
    public let target: String
    public let leaseID: String

    public init(target: String, leaseID: String) {
        self.target = target
        self.leaseID = leaseID
    }
}

public struct TKTargetLeaseReleaseResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let released: Bool
    /// `released` or `none`.
    public let status: String
    public let target: String
    public let lease: TKTargetLease?

    public init(ok: Bool, released: Bool, status: String, target: String, lease: TKTargetLease?) {
        self.ok = ok
        self.released = released
        self.status = status
        self.target = target
        self.lease = lease
    }
}

public struct TKTargetLeaseTakeoverRequest: Codable, Equatable, Sendable {
    public let target: String
    public let owner: String
    public let ttlSeconds: Int?
    public let readonlyObservationAllowed: Bool?
    /// Takeover is the explicit displacement action; it must be confirmed.
    public let confirm: Bool

    public init(target: String, owner: String, ttlSeconds: Int?, readonlyObservationAllowed: Bool?, confirm: Bool) {
        self.target = target
        self.owner = owner
        self.ttlSeconds = ttlSeconds
        self.readonlyObservationAllowed = readonlyObservationAllowed
        self.confirm = confirm
    }
}

/// Server-side mutation authorization check. Mutating host/runtime commands
/// POST this with the resolved target and the caller-provided `--lease` token;
/// the server decides atomically so two agents cannot both proceed.
public struct TKTargetLeaseCheckRequest: Codable, Equatable, Sendable {
    public let target: String
    public let leaseID: String

    public init(target: String, leaseID: String) {
        self.target = target
        self.leaseID = leaseID
    }
}

public struct TKTargetLeaseCheckResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let authorized: Bool
    /// `lease_matched` on success.
    public let reason: String
    public let target: String
    public let lease: TKTargetLease?

    public init(ok: Bool, authorized: Bool, reason: String, target: String, lease: TKTargetLease?) {
        self.ok = ok
        self.authorized = authorized
        self.reason = reason
        self.target = target
        self.lease = lease
    }
}

/// Normalize a simulator selector to the lease key both sides agree on.
/// Strips known simulator prefixes and any `/app:<bundle-id>` suffix so an
/// acquire with `sim:<udid>` matches a mutation check with the raw UDID.
public func TKNormalizeTargetLeaseKey(_ target: String) -> String {
    var key = target.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = ["sim:", "host:ios:", "triton:ios-simulator:", "ios:"]
    for prefix in prefixes where key.hasPrefix(prefix) {
        key = String(key.dropFirst(prefix.count))
        break
    }
    if let range = key.range(of: "/app:") {
        key = String(key[..<range.lowerBound])
    }
    return key
}
