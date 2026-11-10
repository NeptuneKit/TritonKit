import CryptoKit
import Foundation

public enum TKActionDigestAlgorithm: String, Codable, Equatable, Sendable {
    case sha256
    case hmacSHA256 = "hmac-sha256"
}

public enum TKActionArgumentsDigestError: Error, Equatable, Sendable {
    case hmacKeyRequired
}

/// A versioned digest of canonicalized action arguments. Raw arguments are never retained.
public struct TKActionArgumentsDigest: Codable, Equatable, Sendable {
    public static let currentCanonicalizationVersion = "tk-action-args-v1"

    public let digest: String
    public let algorithm: TKActionDigestAlgorithm
    public let canonicalizationVersion: String
    public let redactionProfile: String

    public init(
        digest: String,
        algorithm: TKActionDigestAlgorithm,
        canonicalizationVersion: String = TKActionArgumentsDigest.currentCanonicalizationVersion,
        redactionProfile: String = "none"
    ) {
        self.digest = digest
        self.algorithm = algorithm
        self.canonicalizationVersion = canonicalizationVersion
        self.redactionProfile = redactionProfile
    }

    public static func make(
        arguments: [String: TKJSONValue],
        algorithm: TKActionDigestAlgorithm = .sha256,
        key: Data? = nil,
        canonicalizationVersion: String = currentCanonicalizationVersion,
        redactionProfile: String = "none"
    ) throws -> Self {
        let envelope: [String: TKJSONValue] = [
            "arguments": .object(arguments),
            "canonicalizationVersion": .string(canonicalizationVersion),
            "redactionProfile": .string(redactionProfile)
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)

        let digestData: Data
        switch algorithm {
        case .sha256:
            digestData = Data(SHA256.hash(data: data))
        case .hmacSHA256:
            guard let key, !key.isEmpty else {
                throw TKActionArgumentsDigestError.hmacKeyRequired
            }
            let symmetricKey = SymmetricKey(data: key)
            digestData = Data(HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey))
        }

        return Self(
            digest: digestData.map { String(format: "%02x", $0) }.joined(),
            algorithm: algorithm,
            canonicalizationVersion: canonicalizationVersion,
            redactionProfile: redactionProfile
        )
    }
}

public enum TKActionPolicyDecision: String, Codable, Equatable, Sendable {
    case allow
    case deny
    case approvalRequired = "approval_required"
    case unsupported
    case unavailable
}

public enum TKActionContextValidationError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion
    case actionIDRequired
    case targetRequired
    case operationRequired
    case argsDigestRequired
    case leaseOwnerWithoutLease
}

/// The identity and precondition snapshot shared by one mutating action.
public struct TKActionContext: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var actionID: String
    public var runID: String?
    public var stepID: String?
    public var sessionID: String?
    public var target: String
    public var targetIdentity: String?
    public var operation: String
    public var provider: String?
    public var environmentID: String?
    public var leaseID: String?
    public var leaseOwner: String?
    public var leaseExpiresAt: String?
    public var argsDigest: String
    public var argsDigestAlgorithm: TKActionDigestAlgorithm
    public var argsCanonicalizationVersion: String
    public var argsRedactionProfile: String
    public var observationID: String?
    public var observationRevision: String?
    public var runtimeInstanceID: String?
    public var coordinateSpace: String?
    public var observationCapturedAt: String?
    public var policyDecision: TKActionPolicyDecision
    public var approvalID: String?
    public var approvalBindingDigest: String?
    public var admissionID: String?
    public var createdAt: String

    public init(
        schemaVersion: Int = TKActionContext.currentSchemaVersion,
        actionID: String,
        runID: String? = nil,
        stepID: String? = nil,
        sessionID: String? = nil,
        target: String,
        targetIdentity: String? = nil,
        operation: String,
        provider: String? = nil,
        environmentID: String? = nil,
        argsDigest: String,
        argsDigestAlgorithm: TKActionDigestAlgorithm = .sha256,
        argsCanonicalizationVersion: String = TKActionArgumentsDigest.currentCanonicalizationVersion,
        argsRedactionProfile: String = "none",
        leaseID: String? = nil,
        leaseOwner: String? = nil,
        leaseExpiresAt: String? = nil,
        observationID: String? = nil,
        observationRevision: String? = nil,
        runtimeInstanceID: String? = nil,
        coordinateSpace: String? = nil,
        observationCapturedAt: String? = nil,
        policyDecision: TKActionPolicyDecision = .allow,
        approvalID: String? = nil,
        approvalBindingDigest: String? = nil,
        admissionID: String? = nil,
        createdAt: String
    ) {
        self.schemaVersion = schemaVersion
        self.actionID = actionID
        self.runID = runID
        self.stepID = stepID
        self.sessionID = sessionID
        self.target = target
        self.targetIdentity = targetIdentity
        self.operation = operation
        self.provider = provider
        self.environmentID = environmentID
        self.leaseID = leaseID
        self.leaseOwner = leaseOwner
        self.leaseExpiresAt = leaseExpiresAt
        self.argsDigest = argsDigest
        self.argsDigestAlgorithm = argsDigestAlgorithm
        self.argsCanonicalizationVersion = argsCanonicalizationVersion
        self.argsRedactionProfile = argsRedactionProfile
        self.observationID = observationID
        self.observationRevision = observationRevision
        self.runtimeInstanceID = runtimeInstanceID
        self.coordinateSpace = coordinateSpace
        self.observationCapturedAt = observationCapturedAt
        self.policyDecision = policyDecision
        self.approvalID = approvalID
        self.approvalBindingDigest = approvalBindingDigest
        self.admissionID = admissionID
        self.createdAt = createdAt
    }

    public func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public func contextDigest() throws -> String {
        let data = try canonicalData()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else { throw TKActionContextValidationError.unsupportedSchemaVersion }
        guard !actionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionContextValidationError.actionIDRequired }
        guard !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionContextValidationError.targetRequired }
        guard !operation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionContextValidationError.operationRequired }
        guard !argsDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionContextValidationError.argsDigestRequired }
        if leaseID == nil, leaseOwner != nil || leaseExpiresAt != nil {
            throw TKActionContextValidationError.leaseOwnerWithoutLease
        }
    }
}

public enum TKActionAdmissionState: String, Codable, Equatable, Sendable {
    case issued
    case consumed
    case cancelled
    case expired
}

public enum TKActionAdmissionError: Error, Equatable, Sendable {
    case invalidTTL
    case actionIDRequired
    case contextDigestRequired
    case targetRequired
    case admissionIDRequired
    case duplicateAdmissionID
    case admissionNotFound
    case bindingMismatch
    case expired
    case alreadyConsumed
    case cancelled
}

public struct TKActionAdmission: Codable, Equatable, Sendable {
    public let admissionID: String
    public let actionID: String
    public let contextDigest: String
    public let target: String
    public let leaseID: String?
    public let issuedAt: Date
    public let expiresAt: Date
    public private(set) var state: TKActionAdmissionState
    public private(set) var consumedAt: Date?
    public private(set) var cancelledAt: Date?
    public private(set) var cancelReason: String?

    fileprivate mutating func markExpired() {
        state = .expired
    }

    fileprivate mutating func markConsumed(at date: Date) {
        state = .consumed
        consumedAt = date
    }

    fileprivate mutating func markCancelled(at date: Date, reason: String) {
        state = .cancelled
        cancelledAt = date
        cancelReason = reason
    }

    fileprivate init(
        admissionID: String,
        actionID: String,
        contextDigest: String,
        target: String,
        leaseID: String?,
        issuedAt: Date,
        expiresAt: Date,
        state: TKActionAdmissionState = .issued,
        consumedAt: Date? = nil,
        cancelledAt: Date? = nil,
        cancelReason: String? = nil
    ) {
        self.admissionID = admissionID
        self.actionID = actionID
        self.contextDigest = contextDigest
        self.target = target
        self.leaseID = leaseID
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.state = state
        self.consumedAt = consumedAt
        self.cancelledAt = cancelledAt
        self.cancelReason = cancelReason
    }
}

/// Thread-safe, deterministic one-time admission state machine.
public struct TKActionGenerationToken: Codable, Equatable, Sendable {
    public let target: String
    public let actionID: String
    public let generation: UInt64

    public init(target: String, actionID: String, generation: UInt64) {
        self.target = target
        self.actionID = actionID
        self.generation = generation
    }
}

/// Thread-safe target generation guard. A late result is accepted only for the
/// latest token of the normalized target and action.
public final class TKActionGenerationStore: @unchecked Sendable {
    private struct Current: Sendable {
        let actionID: String
        let generation: UInt64
    }

    private let lock = NSLock()
    private var generations: [String: Current] = [:]

    public init() {}

    public func begin(target: String, actionID: String) -> TKActionGenerationToken {
        let key = TKNormalizeTargetLeaseKey(target)
        lock.lock()
        defer { lock.unlock() }
        let next = (generations[key]?.generation ?? 0) &+ 1
        generations[key] = Current(actionID: actionID, generation: next)
        return TKActionGenerationToken(target: key, actionID: actionID, generation: next)
    }

    public func isCurrent(_ token: TKActionGenerationToken) -> Bool {
        let key = TKNormalizeTargetLeaseKey(token.target)
        lock.lock()
        defer { lock.unlock() }
        guard let current = generations[key] else { return false }
        return current.actionID == token.actionID && current.generation == token.generation
    }

    @discardableResult
    public func invalidate(target: String) -> UInt64 {
        let key = TKNormalizeTargetLeaseKey(target)
        lock.lock()
        defer { lock.unlock() }
        let next = (generations[key]?.generation ?? 0) &+ 1
        generations[key] = Current(actionID: "", generation: next)
        return next
    }
}

/// Thread-safe, deterministic one-time admission state machine.
public final class TKActionAdmissionStore: @unchecked Sendable {
    public static let defaultTTLSeconds = 30
    public static let minTTLSeconds = 1
    public static let maxTTLSeconds = 300

    private let lock = NSLock()
    private var admissions: [String: TKActionAdmission] = [:]

    public init() {}

    public func issue(
        actionID: String,
        contextDigest: String,
        target: String,
        leaseID: String?,
        now: Date,
        ttlSeconds: Int? = nil,
        admissionID: String? = nil
    ) throws -> TKActionAdmission {
        guard !actionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionAdmissionError.actionIDRequired }
        guard !contextDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionAdmissionError.contextDigestRequired }
        guard !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionAdmissionError.targetRequired }
        let ttl = ttlSeconds ?? Self.defaultTTLSeconds
        guard (Self.minTTLSeconds...Self.maxTTLSeconds).contains(ttl) else { throw TKActionAdmissionError.invalidTTL }
        let id = admissionID ?? UUID().uuidString.lowercased()
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TKActionAdmissionError.admissionIDRequired }
        let admission = TKActionAdmission(
            admissionID: id,
            actionID: actionID,
            contextDigest: contextDigest,
            target: target,
            leaseID: leaseID,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(TimeInterval(ttl))
        )
        lock.lock()
        defer { lock.unlock() }
        guard admissions[id] == nil else { throw TKActionAdmissionError.duplicateAdmissionID }
        admissions[id] = admission
        return admission
    }

    public func consume(
        admissionID: String,
        contextDigest: String,
        target: String,
        leaseID: String?,
        now: Date
    ) throws -> TKActionAdmission {
        lock.lock()
        defer { lock.unlock() }
        guard var admission = admissions[admissionID] else { throw TKActionAdmissionError.admissionNotFound }
        switch admission.state {
        case .consumed:
            throw TKActionAdmissionError.alreadyConsumed
        case .cancelled:
            throw TKActionAdmissionError.cancelled
        case .expired:
            throw TKActionAdmissionError.expired
        case .issued:
            if admission.expiresAt <= now {
                admission.markExpired()
                admissions[admissionID] = admission
                throw TKActionAdmissionError.expired
            }
        }
        guard admission.contextDigest == contextDigest, admission.target == target, admission.leaseID == leaseID else {
            throw TKActionAdmissionError.bindingMismatch
        }
        admission.markConsumed(at: now)
        admissions[admissionID] = admission
        return admission
    }

    public func cancel(admissionID: String, now: Date, reason: String) throws -> TKActionAdmission {
        lock.lock()
        defer { lock.unlock() }
        guard var admission = admissions[admissionID] else { throw TKActionAdmissionError.admissionNotFound }
        switch admission.state {
        case .consumed:
            throw TKActionAdmissionError.alreadyConsumed
        case .cancelled:
            throw TKActionAdmissionError.cancelled
        case .expired:
            throw TKActionAdmissionError.expired
        case .issued:
            if admission.expiresAt <= now {
                admission.markExpired()
                admissions[admissionID] = admission
                throw TKActionAdmissionError.expired
            }
        }
        admission.markCancelled(at: now, reason: reason)
        admissions[admissionID] = admission
        return admission
    }

    public func get(admissionID: String, now: Date) -> TKActionAdmission? {
        lock.lock()
        defer { lock.unlock() }
        guard var admission = admissions[admissionID] else { return nil }
        if admission.state == .issued, admission.expiresAt <= now {
            admission.markExpired()
            admissions[admissionID] = admission
        }
        return admission
    }
}
