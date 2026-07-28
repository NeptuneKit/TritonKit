import Foundation

/// Builds the public Stage 1A summary without redefining the existing report
/// metrics. The receipt fixes the cohort and the supplied analyses preserve
/// global duplicate detection across every receipt slot.
func buildTritonTestReliabilityStage1A(
    receipt: TKTestReliabilityCollectionReceipt,
    analyses: [TKTestReliabilitySampleAnalysis],
    thresholds: TKTestReliabilityThresholds
) -> TKTestReliabilityStage1ASummary {
    let supportedFlows = receipt.flows.filter { $0.classification == .supported }
    let expectedSupportedSlotCount = supportedFlows.reduce(into: 0) { count, flow in
        count += flow.slots.count
    }
    let slotCounts = supportedFlows.map(\.slots.count)
    let expectedRunsPerSupportedFlow = Set(slotCounts).count == 1 ? (slotCounts.first ?? 0) : 0
    let supportedAnalyses = analyses.filter { $0.sample.classification == .supported }
    let completeSupportedAnalyses = supportedAnalyses.filter(\.complete)
    let completeSupportedSlotCount = completeSupportedAnalyses.count
    let completeSupportedSlotCountsByFlow = Dictionary(
        grouping: completeSupportedAnalyses,
        by: { $0.sample.flowID }
    ).mapValues(\.count)
    let outcomeRepeatability = buildTritonTestReliabilityOutcomeRepeatability(
        supportedAnalyses: supportedAnalyses
    )
    let evidenceCompleteness = stage1Metric(
        numerator: completeSupportedSlotCount,
        denominator: expectedSupportedSlotCount,
        notEvaluableWhenEmpty: false
    )

    var blockers: [String] = []
    if evidenceCompleteness.rate < thresholds.minimumEvidenceCompletenessRate {
        blockers.append("evidence_completeness_below_threshold")
    }
    if supportedFlows.count < thresholds.minimumSupportedFlows {
        blockers.append("insufficient_supported_flows")
    }
    if supportedFlows.count < thresholds.minimumSupportedFlows ||
        supportedFlows.contains(where: { flow in
            completeSupportedSlotCountsByFlow[flow.flowID, default: 0] < thresholds.minimumRunsPerFlow
        }) {
        blockers.append("insufficient_supported_runs")
    }
    if outcomeRepeatability.state == .notEvaluable {
        blockers.append("outcome_repeatability_not_evaluable")
    } else if outcomeRepeatability.rate < thresholds.minimumOutcomeRepeatabilityRate {
        blockers.append("outcome_repeatability_below_threshold")
        if outcomeRepeatability.rate < 0.70 {
            blockers.append("stop_expansion")
        }
    }
    return TKTestReliabilityStage1ASummary(
        expectedSupportedFlowCount: supportedFlows.count,
        expectedRunsPerSupportedFlow: expectedRunsPerSupportedFlow,
        expectedSupportedSlotCount: expectedSupportedSlotCount,
        completeSupportedSlotCount: completeSupportedSlotCount,
        evidenceCompleteness: evidenceCompleteness,
        outcomeRepeatability: outcomeRepeatability,
        gate: stage1Gate(blockers)
    )
}

/// Stage 1B is deliberately stricter than the private identity-chain summary:
/// its numerator requires both receipt/control validation and the same core
/// evidence/manifest completeness analysis used by the aggregate report.
func buildTritonTestReliabilityStage1B(
    receipt: TKTestReliabilityCollectionReceipt,
    validReceiptControlSlotCount: Int,
    validNegativeControlCount: Int,
    failureExplainability: TKTestReliabilityMetric,
    thresholds: TKTestReliabilityThresholds
) -> TKTestReliabilityStage1BSummary {
    let expectedReceiptControlSlotCount = receipt.flows.reduce(into: 0) { count, flow in
        count += flow.slots.count
    }
    let expectedNegativeControlCount = receipt.flows.filter {
        $0.classification == .negativeControl
    }.count
    let receiptControlIntegrity = stage1Metric(
        numerator: validReceiptControlSlotCount,
        denominator: expectedReceiptControlSlotCount,
        notEvaluableWhenEmpty: false
    )

    var blockers: [String] = []
    if validReceiptControlSlotCount != expectedReceiptControlSlotCount {
        blockers.append("receipt_control_integrity_incomplete")
    }
    if validNegativeControlCount != expectedNegativeControlCount {
        blockers.append("negative_control_integrity_invalid")
    }
    if thresholds.minimumFailureSamples > 0 {
        if failureExplainability.denominator < thresholds.minimumFailureSamples {
            blockers.append("insufficient_failure_samples")
        } else if failureExplainability.rate < thresholds.minimumFailureExplainabilityRate {
            blockers.append("failure_explainability_below_threshold")
        }
    }
    return TKTestReliabilityStage1BSummary(
        expectedReceiptControlSlotCount: expectedReceiptControlSlotCount,
        expectedNegativeControlCount: expectedNegativeControlCount,
        receiptControlIntegrity: receiptControlIntegrity,
        failureExplainability: failureExplainability,
        gate: stage1Gate(blockers)
    )
}

func buildTritonTestReliabilityStage1Gate(
    stage1A: TKTestReliabilityStage1ASummary,
    stage1B: TKTestReliabilityStage1BSummary
) -> TKTestReliabilityGate {
    stage1Gate(stage1A.gate.blockerCodes + stage1B.gate.blockerCodes)
}

private func stage1Metric(
    numerator: Int,
    denominator: Int,
    notEvaluableWhenEmpty: Bool
) -> TKTestReliabilityMetric {
    guard denominator > 0 else {
        return TKTestReliabilityMetric(
            state: notEvaluableWhenEmpty ? .notEvaluable : .measured,
            numerator: numerator,
            denominator: denominator,
            rate: 0
        )
    }
    return TKTestReliabilityMetric(
        state: .measured,
        numerator: numerator,
        denominator: denominator,
        rate: Double(numerator) / Double(denominator)
    )
}

private func stage1Gate(_ blockers: [String]) -> TKTestReliabilityGate {
    let uniqueBlockers = Array(Set(blockers)).sorted()
    return TKTestReliabilityGate(
        status: uniqueBlockers.isEmpty ? .passed : .blocked,
        blockerCodes: uniqueBlockers
    )
}
