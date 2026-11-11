import Foundation

public enum TKActionDelivery: String, Codable, Equatable, Sendable {
    case notStarted = "not_started"
    case submitted
    case delivered
    case unknown
}

public enum TKActionOutcome: String, Codable, Equatable, Sendable {
    case pending
    case settled
    case uncertain
    case stale
    case blocked
    case cancelled
    case stopped
    case failed
}

public enum TKActionPostcondition: String, Codable, Equatable, Sendable {
    case notRequested = "not_requested"
    case verified
    case unverified
    case failed
    case unavailable
}

public enum TKActionEvidencePersistence: String, Codable, Equatable, Sendable {
    case notRequested = "not_requested"
    case queued
    case written
    case partial
    case failed
}

/// Provider-neutral receipt shared by runner and device-action projections.
public struct TKActionReceipt: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let actionID: String
    public let operation: String
    public let target: String
    public let leaseID: String?
    public let admissionID: String?
    public let contextDigest: String?
    public let generation: UInt64?
    public let delivery: TKActionDelivery
    public let outcome: TKActionOutcome
    public let executed: Bool?
    public let originalStatus: String?
    public let terminalStatus: String?
    public let postcondition: TKActionPostcondition
    public let evidencePersistence: TKActionEvidencePersistence
    public let evidenceRefs: [String]
    public let failureCode: String?
    public let recoveryCommands: [String]

    public init(
        schemaVersion: Int = TKActionReceipt.currentSchemaVersion,
        actionID: String,
        operation: String,
        target: String,
        leaseID: String? = nil,
        admissionID: String? = nil,
        contextDigest: String? = nil,
        generation: UInt64? = nil,
        delivery: TKActionDelivery,
        outcome: TKActionOutcome,
        executed: Bool?,
        originalStatus: String? = nil,
        terminalStatus: String? = nil,
        postcondition: TKActionPostcondition = .notRequested,
        evidencePersistence: TKActionEvidencePersistence = .notRequested,
        evidenceRefs: [String] = [],
        failureCode: String? = nil,
        recoveryCommands: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.actionID = actionID
        self.operation = operation
        self.target = target
        self.leaseID = leaseID
        self.admissionID = admissionID
        self.contextDigest = contextDigest
        self.generation = generation
        self.delivery = delivery
        self.outcome = outcome
        self.executed = executed
        self.originalStatus = originalStatus
        self.terminalStatus = terminalStatus
        self.postcondition = postcondition
        self.evidencePersistence = evidencePersistence
        self.evidenceRefs = evidenceRefs
        self.failureCode = failureCode
        self.recoveryCommands = recoveryCommands
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion,
              !actionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !operation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw TKActionReceiptValidationError.invalidIdentity
        }
        if outcome == .uncertain {
            guard delivery == .unknown && executed == nil else {
                throw TKActionReceiptValidationError.uncertainMustRemainUnknown
            }
        }
        if delivery == .notStarted {
            guard executed == false else { throw TKActionReceiptValidationError.notStartedMustBeFalse }
        }
    }
}

public enum TKActionReceiptValidationError: Error, Equatable, Sendable {
    case invalidIdentity
    case uncertainMustRemainUnknown
    case notStartedMustBeFalse
}

public struct TKActionAdmissionHandle: Codable, Equatable, Sendable {
    public let context: TKActionContext
    public let contextDigest: String
    public let admission: TKActionAdmission
    public let generation: TKActionGenerationToken

    public init(context: TKActionContext, contextDigest: String, admission: TKActionAdmission, generation: TKActionGenerationToken) {
        self.context = context
        self.contextDigest = contextDigest
        self.admission = admission
        self.generation = generation
    }
}

public enum TKActionAdmissionCoordinatorError: Error, Equatable, Sendable {
    case invalidContext(TKActionContextValidationError)
    case staleGeneration
    case policyNotAllowed(TKActionPolicyDecision)
    case admission(TKActionAdmissionError)
}

/// Shared P0 coordinator for context digest, one-time admission and generation.
public final class TKActionAdmissionCoordinator: @unchecked Sendable {
    public let admissions: TKActionAdmissionStore
    public let generations: TKActionGenerationStore
    private let now: () -> Date

    public init(
        admissions: TKActionAdmissionStore = TKActionAdmissionStore(),
        generations: TKActionGenerationStore = TKActionGenerationStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.admissions = admissions
        self.generations = generations
        self.now = now
    }

    public func admit(context: TKActionContext, ttlSeconds: Int? = nil) throws -> TKActionAdmissionHandle {
        do { try context.validate() } catch let error as TKActionContextValidationError {
            throw TKActionAdmissionCoordinatorError.invalidContext(error)
        } catch {
            throw TKActionAdmissionCoordinatorError.invalidContext(.actionIDRequired)
        }
        guard context.policyDecision == .allow else {
            throw TKActionAdmissionCoordinatorError.policyNotAllowed(context.policyDecision)
        }
        let ttl = ttlSeconds ?? TKActionAdmissionStore.defaultTTLSeconds
        guard (TKActionAdmissionStore.minTTLSeconds...TKActionAdmissionStore.maxTTLSeconds).contains(ttl) else {
            throw TKActionAdmissionCoordinatorError.admission(.invalidTTL)
        }
        let digest: String
        do { digest = try context.contextDigest() } catch {
            throw TKActionAdmissionCoordinatorError.invalidContext(.argsDigestRequired)
        }
        do {
            let issued = try admissions.issue(
                actionID: context.actionID,
                contextDigest: digest,
                target: context.target,
                leaseID: context.leaseID,
                now: now(),
                ttlSeconds: ttlSeconds
            )
            let consumed = try admissions.consume(
                admissionID: issued.admissionID,
                contextDigest: digest,
                target: context.target,
                leaseID: context.leaseID,
                now: now()
            )
            let generation = generations.begin(target: context.target, actionID: context.actionID)
            return TKActionAdmissionHandle(
                context: context,
                contextDigest: digest,
                admission: consumed,
                generation: generation
            )
        } catch let error as TKActionAdmissionError {
            throw TKActionAdmissionCoordinatorError.admission(error)
        }
    }

    public func isCurrent(_ handle: TKActionAdmissionHandle) -> Bool {
        generations.isCurrent(handle.generation)
    }

    public func receipt(
        _ handle: TKActionAdmissionHandle,
        delivery: TKActionDelivery,
        outcome: TKActionOutcome,
        executed: Bool?,
        originalStatus: String? = nil,
        terminalStatus: String? = nil,
        postcondition: TKActionPostcondition = .notRequested,
        evidencePersistence: TKActionEvidencePersistence = .notRequested,
        evidenceRefs: [String] = [],
        failureCode: String? = nil,
        recoveryCommands: [String] = []
    ) throws -> TKActionReceipt {
        guard isCurrent(handle) else { throw TKActionAdmissionCoordinatorError.staleGeneration }
        let receipt = TKActionReceipt(
            actionID: handle.context.actionID,
            operation: handle.context.operation,
            target: handle.context.target,
            leaseID: handle.context.leaseID,
            admissionID: handle.admission.admissionID,
            contextDigest: handle.contextDigest,
            generation: handle.generation.generation,
            delivery: delivery,
            outcome: outcome,
            executed: executed,
            originalStatus: originalStatus,
            terminalStatus: terminalStatus,
            postcondition: postcondition,
            evidencePersistence: evidencePersistence,
            evidenceRefs: evidenceRefs,
            failureCode: failureCode,
            recoveryCommands: recoveryCommands
        )
        try receipt.validate()
        return receipt
    }
}
