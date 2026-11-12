import Foundation

public extension TKActionReceipt {
    /// Persistence is a side channel; changing it never rewrites provider facts.
    func recordingEvidence(_ persistence: TKActionEvidencePersistence, refs: [String]) -> TKActionReceipt {
        TKActionReceipt(schemaVersion: schemaVersion, actionID: actionID, operation: operation,
            target: target, leaseID: leaseID, admissionID: admissionID, contextDigest: contextDigest,
            generation: generation, delivery: delivery, outcome: outcome, executed: executed,
            originalStatus: originalStatus, terminalStatus: terminalStatus, postcondition: postcondition,
            evidencePersistence: persistence, evidenceRefs: refs, failureCode: failureCode,
            recoveryCommands: recoveryCommands)
    }

    func evidenceMetadata(refs: [String]? = nil) -> TKActionEvidenceMetadata {
        TKActionEvidenceMetadata(actionID: actionID, admissionID: admissionID,
            contextDigest: contextDigest, delivery: delivery.rawValue, outcome: outcome.rawValue,
            executed: executed, originalStatus: originalStatus, terminalStatus: terminalStatus,
            postcondition: postcondition.rawValue, evidenceRefs: refs ?? evidenceRefs)
    }
}
