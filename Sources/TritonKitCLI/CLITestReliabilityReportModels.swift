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

/// Receipt-backed Stage 1 has two deliberately separate populations: the
/// 60 supported slots and the 61 receipt/control slots. This summary is
/// absent for legacy sample manifests so they cannot look canonical.
struct TKTestReliabilityStage1Summary: Codable, Equatable {
    let stage1A: TKTestReliabilityStage1ASummary
    let stage1B: TKTestReliabilityStage1BSummary
    let gate: TKTestReliabilityGate
}

/// Stage 1A measures only supported flows. Its evidence completeness and
/// repeatability never include the expected negative control.
struct TKTestReliabilityStage1ASummary: Codable, Equatable {
    let expectedSupportedFlowCount: Int
    let expectedRunsPerSupportedFlow: Int
    let expectedSupportedSlotCount: Int
    let completeSupportedSlotCount: Int
    let evidenceCompleteness: TKTestReliabilityMetric
    let outcomeRepeatability: TKTestReliabilityMetric
    let gate: TKTestReliabilityGate
}

/// Stage 1B covers every receipt-declared slot, including the expected
/// negative control. It reports only safe counts and never slot identities.
struct TKTestReliabilityStage1BSummary: Codable, Equatable {
    let expectedReceiptControlSlotCount: Int
    let expectedNegativeControlCount: Int
    let receiptControlIntegrity: TKTestReliabilityMetric
    let failureExplainability: TKTestReliabilityMetric
    let gate: TKTestReliabilityGate
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
    let stage1: TKTestReliabilityStage1Summary?
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
        stage1: TKTestReliabilityStage1Summary? = nil,
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
        self.stage1 = stage1
        self.issueCounts = issueCounts
        self.gate = gate
    }
}
