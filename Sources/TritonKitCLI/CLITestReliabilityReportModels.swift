import Foundation

enum TKTestReliabilityGateStatus: String, Codable, Equatable {
    case passed
    case blocked
}

enum TKTestReliabilityGateAuthority: String, Codable, Equatable {
    case legacyDiagnostic = "legacy-diagnostic"
    case receiptBacked = "receipt-backed"
}

struct TKTestReliabilityGate: Codable, Equatable {
    let status: TKTestReliabilityGateStatus
    let blockerCodes: [String]
}

/// Safe aggregate only: this intentionally contains no receipt digest,
/// target identity, artifact path, or component hash.
struct TKTestReliabilityIdentityChainSummary: Codable, Equatable {
    let state: TKTestReliabilityIdentityChainState
    let expectedSlotCount: Int
    let validSlotCount: Int
    let missingSlotCount: Int
    let invalidSlotCount: Int
    let receiptAnchorVerified: Bool

    static let notApplicable = TKTestReliabilityIdentityChainSummary(
        state: .notApplicable,
        expectedSlotCount: 0,
        validSlotCount: 0,
        missingSlotCount: 0,
        invalidSlotCount: 0,
        receiptAnchorVerified: false
    )
}

struct TKTestReliabilityReport: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let gateAuthority: TKTestReliabilityGateAuthority
    let eligibleForStage1Gate: Bool
    let thresholds: TKTestReliabilityThresholds
    let evidenceCompleteness: TKTestReliabilityMetric
    let failureExplainability: TKTestReliabilityMetric
    let outcomeRepeatability: TKTestReliabilityMetric
    let flows: [TKTestReliabilityFlow]
    let identityChain: TKTestReliabilityIdentityChainSummary
    let issueCounts: [String: Int]
    let gate: TKTestReliabilityGate

    init(
        gateAuthority: TKTestReliabilityGateAuthority,
        thresholds: TKTestReliabilityThresholds,
        evidenceCompleteness: TKTestReliabilityMetric,
        failureExplainability: TKTestReliabilityMetric,
        outcomeRepeatability: TKTestReliabilityMetric,
        flows: [TKTestReliabilityFlow],
        identityChain: TKTestReliabilityIdentityChainSummary = .notApplicable,
        issueCounts: [String: Int],
        gate: TKTestReliabilityGate
    ) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-report"
        self.gateAuthority = gateAuthority
        self.eligibleForStage1Gate = gateAuthority == .receiptBacked
        self.thresholds = thresholds
        self.evidenceCompleteness = evidenceCompleteness
        self.failureExplainability = failureExplainability
        self.outcomeRepeatability = outcomeRepeatability
        self.flows = flows
        self.identityChain = identityChain
        self.issueCounts = issueCounts
        self.gate = gate
    }
}
