import Foundation
import TritonKitShared

/// A private, operator-supplied manifest. It intentionally stays separate from evidence so
/// a reliability report can compare runs without publishing paths, target ids, or reset data.
enum TKTestReliabilitySampleClassification: String, Codable, Equatable {
    case supported
    case negativeControl = "negative-control"
}

struct TKTestReliabilitySample: Codable, Equatable {
    let flowID: String
    let classification: TKTestReliabilitySampleClassification
    let evidence: String
    let initialStateID: String
    let resetEvidenceID: String
    let targetToken: String

    init(
        flowID: String,
        classification: TKTestReliabilitySampleClassification = .supported,
        evidence: String,
        initialStateID: String,
        resetEvidenceID: String,
        targetToken: String
    ) {
        self.flowID = flowID
        self.classification = classification
        self.evidence = evidence
        self.initialStateID = initialStateID
        self.resetEvidenceID = resetEvidenceID
        self.targetToken = targetToken
    }
}

struct TKTestReliabilitySampleSet: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let samples: [TKTestReliabilitySample]

    init(samples: [TKTestReliabilitySample]) {
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-sample-set"
        self.samples = samples
    }
}

struct TKTestReliabilityThresholds: Codable, Equatable {
    let minimumSupportedFlows: Int
    let minimumRunsPerFlow: Int
    let minimumFailureSamples: Int
    let minimumEvidenceCompletenessRate: Double
    let minimumFailureExplainabilityRate: Double
    let minimumOutcomeRepeatabilityRate: Double

    init(
        minimumSupportedFlows: Int = 3,
        minimumRunsPerFlow: Int = 20,
        minimumFailureSamples: Int = 1,
        minimumEvidenceCompletenessRate: Double = 0.95,
        minimumFailureExplainabilityRate: Double = 0.90,
        minimumOutcomeRepeatabilityRate: Double = 0.90
    ) {
        self.minimumSupportedFlows = minimumSupportedFlows
        self.minimumRunsPerFlow = minimumRunsPerFlow
        self.minimumFailureSamples = minimumFailureSamples
        self.minimumEvidenceCompletenessRate = minimumEvidenceCompletenessRate
        self.minimumFailureExplainabilityRate = minimumFailureExplainabilityRate
        self.minimumOutcomeRepeatabilityRate = minimumOutcomeRepeatabilityRate
    }
}

enum TKTestReliabilityMetricState: String, Codable, Equatable {
    case measured
    case notEvaluable = "not_evaluable"
}

struct TKTestReliabilityMetric: Codable, Equatable {
    let state: TKTestReliabilityMetricState
    let numerator: Int
    let denominator: Int
    let rate: Double
}

struct TKTestReliabilityFlow: Codable, Equatable {
    let flowID: String
    let sampleCount: Int
    let planDigest: String
}

enum TKTestReliabilityError: Error, Equatable, LocalizedError {
    case invalidSampleSet
    case invalidThresholds

    var errorDescription: String? {
        switch self {
        case .invalidSampleSet:
            return "Reliability samples must use the supported private manifest schema."
        case .invalidThresholds:
            return "Reliability thresholds must be non-negative rates between zero and one."
        }
    }
}

private struct TKTestReliabilitySampleAnalysis {
    let sample: TKTestReliabilitySample
    let complete: Bool
    let evidenceIdentity: String?
    let runID: String?
    let terminalStatus: TKTestRunStatus?
    let planDigest: String?
    let targetIdentityDigest: String?
    let artifactKinds: Set<String>
    let stepStatuses: [String]
    let failureType: String?
    let failureExplainable: Bool?
    let issues: [String]

    var isFailure: Bool {
        guard let terminalStatus else { return false }
        return terminalStatus == .failed || terminalStatus == .blocked
    }

    var repeatabilitySignature: String? {
        guard complete, let terminalStatus, let planDigest else { return nil }
        let components = [
            planDigest,
            terminalStatus.rawValue,
            stepStatuses.joined(separator: ","),
            artifactKinds.sorted().joined(separator: ","),
            failureType ?? "none",
            sample.initialStateID,
            targetIdentityDigest ?? "unavailable",
        ]
        return fnv1a64Hex(Data(components.joined(separator: "|").utf8))
    }

    func addingIssues(_ additionalIssues: [String]) -> Self {
        let combinedIssues = Array(Set(issues + additionalIssues)).sorted()
        return TKTestReliabilitySampleAnalysis(
            sample: sample,
            complete: !combinedIssues.contains(where: reliabilityIssueInvalidatesEvidenceCompleteness),
            evidenceIdentity: evidenceIdentity,
            runID: runID,
            terminalStatus: terminalStatus,
            planDigest: planDigest,
            targetIdentityDigest: targetIdentityDigest,
            artifactKinds: artifactKinds,
            stepStatuses: stepStatuses,
            failureType: failureType,
            failureExplainable: failureExplainable,
            issues: combinedIssues
        )
    }
}

private struct TKTestReliabilityManifestArtifactInventory {
    let paths: Set<String>
    let kindPaths: Set<String>

    init(manifestArtifacts: [TKEvidenceArtifact], root: URL) {
        var paths = Set<String>()
        var kindPaths = Set<String>()
        for artifact in manifestArtifacts {
            guard let url = containedEvidenceRegularFileURL(root: root, relativePath: artifact.path) else {
                continue
            }
            paths.insert(url.path)
            kindPaths.insert(Self.key(kind: artifact.kind, url: url))
        }
        self.paths = paths
        self.kindPaths = kindPaths
    }

    func containsReference(root: URL, relativePath: String) -> Bool {
        guard let url = containedEvidenceEventReferenceURL(root: root, relativePath: relativePath) else {
            return false
        }
        return paths.contains(url.path)
    }

    func containsArtifact(kind: String, root: URL, relativePath: String) -> Bool {
        guard let url = containedEvidenceEventReferenceURL(root: root, relativePath: relativePath) else {
            return false
        }
        return kindPaths.contains(Self.key(kind: kind, url: url))
    }

    private static func key(kind: String, url: URL) -> String {
        "\(kind)\u{0}\(url.path)"
    }
}

func buildTritonTestReliabilityReport(
    samplesPath: String,
    thresholds: TKTestReliabilityThresholds = TKTestReliabilityThresholds()
) throws -> TKTestReliabilityReport {
    let sampleSet = try decodeReliabilitySampleSet(at: samplesPath)
    return try buildTritonTestReliabilityReport(samples: sampleSet.samples, thresholds: thresholds)
}

/// Internal receipt-backed callers derive this list from an immutable receipt
/// rather than serializing a mutable v1 sample-set file. The public v1
/// `--samples` command still uses the overload above unchanged.
func buildTritonTestReliabilityReport(
    samples: [TKTestReliabilitySample],
    thresholds: TKTestReliabilityThresholds = TKTestReliabilityThresholds()
) throws -> TKTestReliabilityReport {
    try buildTritonTestReliabilityReport(
        samples: samples,
        thresholds: thresholds,
        gateAuthority: .legacyDiagnostic
    )
}

func buildTritonTestReliabilityReceiptReport(
    samples: [TKTestReliabilitySample],
    thresholds: TKTestReliabilityThresholds = TKTestReliabilityThresholds()
) throws -> TKTestReliabilityReport {
    try buildTritonTestReliabilityReport(
        samples: samples,
        thresholds: thresholds,
        gateAuthority: .receiptBacked
    )
}

private func buildTritonTestReliabilityReport(
    samples: [TKTestReliabilitySample],
    thresholds: TKTestReliabilityThresholds,
    gateAuthority: TKTestReliabilityGateAuthority
) throws -> TKTestReliabilityReport {
    try validateReliabilityThresholds(thresholds)
    var analyses = samples.map(analyzeReliabilitySample)
    analyses = markDuplicateReliabilitySamples(analyses)
    var issueCounts: [String: Int] = [:]
    for analysis in analyses {
        for issue in analysis.issues {
            issueCounts[issue, default: 0] += 1
        }
    }

    let evidenceCompleteness = reliabilityMetric(
        numerator: analyses.filter(\.complete).count,
        denominator: analyses.count,
        notEvaluableWhenEmpty: false
    )
    let failedAnalyses = analyses.filter(\.isFailure)
    let failureExplainability = reliabilityMetric(
        numerator: failedAnalyses.filter {
            $0.complete && $0.failureExplainable == true
        }.count,
        denominator: failedAnalyses.count,
        notEvaluableWhenEmpty: true
    )

    let supportedAnalyses = analyses.filter { $0.sample.classification == .supported }
    let repeatability = buildOutcomeRepeatability(
        supportedAnalyses: supportedAnalyses,
        issueCounts: &issueCounts
    )
    let flows = buildReliabilityFlows(from: analyses)
    var gate = buildReliabilityGate(
        thresholds: thresholds,
        evidenceCompleteness: evidenceCompleteness,
        failureExplainability: failureExplainability,
        outcomeRepeatability: repeatability,
        supportedAnalyses: supportedAnalyses
    )
    if gateAuthority == .legacyDiagnostic {
        gate = TKTestReliabilityGate(
            status: .blocked,
            blockerCodes: Array(Set(gate.blockerCodes + ["receipt_required"])).sorted()
        )
    }
    return TKTestReliabilityReport(
        gateAuthority: gateAuthority,
        thresholds: thresholds,
        evidenceCompleteness: evidenceCompleteness,
        failureExplainability: failureExplainability,
        outcomeRepeatability: repeatability,
        flows: flows,
        issueCounts: issueCounts,
        gate: gate
    )
}

private func validateReliabilityThresholds(_ thresholds: TKTestReliabilityThresholds) throws {
    guard thresholds.minimumSupportedFlows >= 0,
          thresholds.minimumRunsPerFlow >= 0,
          thresholds.minimumFailureSamples >= 0,
          [
              thresholds.minimumEvidenceCompletenessRate,
              thresholds.minimumFailureExplainabilityRate,
              thresholds.minimumOutcomeRepeatabilityRate,
          ].allSatisfy({ (0...1).contains($0) }) else {
        throw TKTestReliabilityError.invalidThresholds
    }
}

private func decodeReliabilitySampleSet(at path: String) throws -> TKTestReliabilitySampleSet {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let sampleSet = try? JSONDecoder().decode(TKTestReliabilitySampleSet.self, from: data),
          sampleSet.schemaVersion == 1,
          sampleSet.kind == "triton.test.reliability-sample-set",
          !sampleSet.samples.isEmpty,
          sampleSet.samples.allSatisfy(reliabilitySampleIsValid) else {
        throw TKTestReliabilityError.invalidSampleSet
    }
    return sampleSet
}

private func reliabilitySampleIsValid(_ sample: TKTestReliabilitySample) -> Bool {
    guard sample.flowID.range(of: #"^[a-z0-9][a-z0-9-]{0,63}$"#, options: .regularExpression) != nil else {
        return false
    }
    return !sample.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func analyzeReliabilitySample(_ sample: TKTestReliabilitySample) -> TKTestReliabilitySampleAnalysis {
    let root = evidenceBundleRoot(from: sample.evidence)
    let evidenceIdentity = root.resolvingSymlinksInPath().standardizedFileURL.path
    var issues: [String] = []
    var artifactKinds = Set<String>()
    var terminalStatus: TKTestRunStatus?
    var planDigest: String?
    var normalizedPlan: TKTestNormalizedPlan?
    var targetIdentityDigest: String?
    var stepStatuses: [String] = []
    var failureType: String?
    var failureExplainable: Bool?
    var eventRunID: String?

    if sample.initialStateID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("missing_initial_state_id")
    }
    if sample.resetEvidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("missing_reset_evidence_id")
    }
    if sample.targetToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("missing_target_token")
    }

    guard let manifest = try? readEvidenceManifest(from: sample.evidence) else {
        return reliabilityAnalysis(sample: sample, issues: ["missing_manifest"])
    }
    if manifest.partial {
        issues.append("partial_evidence")
    }
    if !manifest.skipped.isEmpty {
        issues.append("skipped_evidence")
    }
    if manifest.target?.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
        issues.append("missing_manifest_target")
    }
    let normalizedPlanArtifacts = manifest.artifacts.filter {
        $0.kind == "test.normalized-plan" && $0.path == "normalized-plan.json"
    }
    if normalizedPlanArtifacts.isEmpty {
        issues.append("missing_normalized_plan_artifact")
    } else if normalizedPlanArtifacts.count != 1 {
        issues.append("invalid_normalized_plan_artifact")
    }
    let runtimeTargetArtifacts = manifest.artifacts.filter {
        $0.kind == "runtime.target" && $0.path == "runtime-target.json"
    }
    if runtimeTargetArtifacts.isEmpty {
        issues.append("missing_runtime_target_artifact")
    } else if runtimeTargetArtifacts.count != 1 {
        issues.append("invalid_runtime_target_artifact")
    }
    let manifestArtifactInventory = TKTestReliabilityManifestArtifactInventory(
        manifestArtifacts: manifest.artifacts,
        root: root
    )
    for artifact in manifest.artifacts {
        artifactKinds.insert(artifact.kind)
        guard containedEvidenceRegularFileURL(root: root, relativePath: artifact.path) != nil else {
            issues.append("missing_manifest_artifact")
            continue
        }
    }

    if let normalizedPlanURL = containedEvidenceRegularFileURL(root: root, relativePath: "normalized-plan.json"),
       let data = try? Data(contentsOf: normalizedPlanURL),
       let plan = try? JSONDecoder().decode(TKTestNormalizedPlan.self, from: data) {
        if plan.schemaVersion == 1,
           plan.kind == "triton.test.normalized-plan",
           plan.device.platform == "ios-simulator",
           reliabilityNormalizedPlanStepsAreCanonical(plan) {
            planDigest = fnv1a64Hex(data)
            normalizedPlan = plan
        } else if plan.device.platform != "ios-simulator" {
            issues.append("unsupported_reliability_platform")
        } else if plan.schemaVersion == 1,
                  plan.kind == "triton.test.normalized-plan" {
            issues.append("invalid_normalized_plan_steps")
        } else {
            issues.append("invalid_normalized_plan")
        }
    } else {
        issues.append("missing_normalized_plan")
    }

    let runtimeTarget = reliabilityRuntimeTarget(root: root)
    if runtimeTarget == nil {
        issues.append("missing_runtime_target")
    }
    if runtimeTarget != nil,
       let runtimeTargetArtifact = runtimeTargetArtifacts.first,
       runtimeTargetArtifact.target != runtimeTarget?.id {
        issues.append("runtime_target_artifact_mismatch")
    }
    if let plan = normalizedPlan,
       let manifestTarget = manifest.target,
       let runtimeTarget {
        let runtimePlatform = runtimeTarget.platform.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let simulatorUDID = runtimeTarget.simulatorUDID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let planBundleID = plan.app.bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        let runtimeBundleID = runtimeTarget.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let manifestBundleID = manifestTarget.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        if runtimePlatform != "ios" || simulatorUDID?.isEmpty != false {
            issues.append("invalid_ios_simulator_runtime_target")
        }
        if planBundleID.isEmpty {
            issues.append("missing_plan_bundle")
        }
        if runtimeBundleID?.isEmpty != false {
            issues.append("missing_runtime_target_bundle")
        }
        if manifestBundleID?.isEmpty != false {
            issues.append("missing_manifest_target_bundle")
        }
        if !runtimeTarget.connected {
            issues.append("disconnected_runtime_target")
        }
        if !manifestTarget.connected {
            issues.append("disconnected_manifest_target")
        }
        let canonicalTargetID: String? = simulatorUDID.flatMap { simulatorUDID -> String? in
            guard !simulatorUDID.isEmpty,
                  let bundleIdentifier = runtimeBundleID,
                  !bundleIdentifier.isEmpty else {
                return nil
            }
            return TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: simulatorUDID,
                bundleIdentifier: bundleIdentifier
            )
        }
        let simulatorIDMatches = simulatorUDID?.isEmpty == false
            && TKIOSSimulatorUDID(fromTargetID: runtimeTarget.id) == simulatorUDID
        let targetIDIsCanonical = canonicalTargetID.map { $0 == runtimeTarget.id } ?? false
        if simulatorUDID?.isEmpty == false, !simulatorIDMatches {
            issues.append("runtime_target_simulator_mismatch")
        }
        if !targetIDIsCanonical {
            issues.append("noncanonical_runtime_target_id")
        }
        if manifestTarget.id != runtimeTarget.id {
            issues.append("runtime_manifest_target_mismatch")
        }
        if runtimeBundleID != planBundleID {
            issues.append("runtime_plan_bundle_mismatch")
        }
        if manifestBundleID != planBundleID {
            issues.append("plan_manifest_bundle_mismatch")
        }
        if runtimePlatform == "ios",
           simulatorUDID?.isEmpty == false,
           runtimeTarget.connected,
           manifestTarget.connected,
           simulatorIDMatches,
           targetIDIsCanonical,
           manifestTarget.id == runtimeTarget.id,
           !planBundleID.isEmpty,
           runtimeBundleID == planBundleID,
           manifestBundleID == planBundleID {
            targetIdentityDigest = fnv1a64Hex(Data([
                manifestTarget.id,
                runtimeTarget.id,
                runtimeBundleID ?? "",
                runtimePlatform,
                simulatorUDID ?? "",
                planBundleID,
                plan.device.platform,
            ].joined(separator: "|").utf8))
        }
    }

    let runManifest = manifest.run
    if runManifest == nil {
        issues.append("missing_run_manifest")
    } else if runManifest?.status != .completed {
        issues.append("incomplete_run_manifest")
    }
    if runManifest?.summary == nil {
        issues.append("missing_run_summary")
    } else if runManifest?.summary?.runID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
        issues.append("missing_run_summary_id")
    } else if runManifest?.summary?.verdict == nil {
        issues.append("missing_run_verdict")
    }
    let metadata: TKTestRunMetadata?
    if let metadataURL = runManifest.flatMap({ containedEvidenceRegularFileURL(root: root, relativePath: $0.metaPath) }),
       let data = try? Data(contentsOf: metadataURL),
       let decoded = try? JSONDecoder().decode(TKTestRunMetadata.self, from: data) {
        metadata = decoded
    } else {
        metadata = nil
        issues.append("missing_run_metadata")
    }

    var parsedEvents: [TKTestRunEvent] = []
    if let eventsURL = runManifest.flatMap({ containedEvidenceRegularFileURL(root: root, relativePath: $0.eventsPath) }),
       let data = try? Data(contentsOf: eventsURL),
       let parsed = try? TKTestRunEventLogParser().parse(data) {
        parsedEvents = parsed.events
        let sequence = validateReliabilityEventSequence(parsed.events)
        terminalStatus = sequence.terminalStatus
        eventRunID = parsed.events.first?.runID
        issues.append(contentsOf: sequence.issues)
        issues.append(contentsOf: reliabilityEventArtifactIssues(
            parsed.events,
            root: root,
            manifestArtifacts: manifestArtifactInventory
        ))
        if let metadata, let terminalStatus, metadata.status != terminalStatus {
            issues.append("run_status_mismatch")
        }
        if let metadata,
           let eventRunID = parsed.events.first?.runID,
           metadata.runID != eventRunID {
            issues.append("run_id_mismatch")
        }
        if let expectedEventCount = runManifest?.eventCount {
            if expectedEventCount != parsed.summary.eventCount {
                issues.append("run_event_count_mismatch")
            }
        } else {
            issues.append("missing_run_event_count")
        }
        if let expectedObservationCount = runManifest?.observationCount {
            if expectedObservationCount != parsed.summary.observationCount {
                issues.append("run_observation_count_mismatch")
            }
        } else {
            issues.append("missing_run_observation_count")
        }
        if let expectedStepCount = runManifest?.summary?.stepCount,
           expectedStepCount != parsed.summary.stepCount {
            issues.append("run_step_count_mismatch")
        }
        if let summary = runManifest?.summary,
           let eventRunID = parsed.events.first?.runID,
           let summaryRunID = summary.runID,
           summaryRunID != eventRunID {
            issues.append("run_summary_id_mismatch")
        }
        if let terminalStatus,
           let expectedVerdict = reliabilityEvidenceVerdict(for: terminalStatus),
           let actualVerdict = runManifest?.summary?.verdict,
           actualVerdict != expectedVerdict {
            issues.append("run_verdict_mismatch")
        }
        if let terminalStatus, manifest.ok != (terminalStatus == .passed) {
            issues.append("manifest_status_mismatch")
        }
        if let normalizedPlan {
            issues.append(contentsOf: reliabilityPlanEventCoverageIssues(
                plan: normalizedPlan,
                events: parsed.events,
                terminalStatus: terminalStatus,
                root: root,
                manifestArtifacts: manifestArtifactInventory
            ))
        }
        stepStatuses = parsed.events.compactMap { event in
            guard event.type == .stepFinished,
                  let stepIndex = event.stepIndex,
                  let status = event.status else {
                return nil
            }
            return "\(stepIndex):\(status.rawValue)"
        }.sorted()
    } else {
        issues.append("invalid_run_events")
    }

    if terminalStatus == .failed || terminalStatus == .blocked {
        let terminalFailure = reliabilityTerminalFailure(from: parsedEvents, status: terminalStatus)
        let failure = terminalFailure?.failure
        failureType = failure?.type
        let hasRecovery = failureType.flatMap(reliabilityRecoveryID(for:)) != nil
        let hasArtifactRefs = !(failure?.artifactRefs ?? []).isEmpty
        let artifactRefsExist = hasArtifactRefs && (failure?.artifactRefs.allSatisfy {
            containedEvidenceEventReferenceURL(root: root, relativePath: $0) != nil
        } ?? false)
        let artifactRefsAreDeclared = artifactRefsExist && (failure?.artifactRefs.allSatisfy {
            manifestArtifactInventory.containsReference(root: root, relativePath: $0)
        } ?? false)
        let artifactRefsBelongToTerminalStep = artifactRefsAreDeclared
            && terminalFailure.map {
                reliabilityTerminalFailureArtifactsBelongToTerminalStep(
                    $0,
                    events: parsedEvents,
                    root: root,
                    manifestArtifacts: manifestArtifactInventory
                )
            } == true
        if !hasRecovery {
            issues.append("missing_failure_recovery")
        }
        if !artifactRefsExist {
            issues.append("missing_failure_artifact_ref")
        } else if !artifactRefsAreDeclared {
            issues.append("undeclared_failure_artifact_ref")
        } else if !artifactRefsBelongToTerminalStep {
            issues.append("terminal_failure_artifact_step_mismatch")
        }
        if failure == nil {
            issues.append("missing_terminal_failure_record")
        }
        failureExplainable = hasRecovery && artifactRefsBelongToTerminalStep
    }

    return reliabilityAnalysis(
        sample: sample,
        evidenceIdentity: evidenceIdentity,
        runID: eventRunID,
        terminalStatus: terminalStatus,
        planDigest: planDigest,
        targetIdentityDigest: targetIdentityDigest,
        artifactKinds: artifactKinds,
        stepStatuses: stepStatuses,
        failureType: failureType,
        failureExplainable: failureExplainable,
        issues: issues
    )
}

private func reliabilityAnalysis(
    sample: TKTestReliabilitySample,
    evidenceIdentity: String? = nil,
    runID: String? = nil,
    terminalStatus: TKTestRunStatus? = nil,
    planDigest: String? = nil,
    targetIdentityDigest: String? = nil,
    artifactKinds: Set<String> = [],
    stepStatuses: [String] = [],
    failureType: String? = nil,
    failureExplainable: Bool? = nil,
    issues: [String]
) -> TKTestReliabilitySampleAnalysis {
    TKTestReliabilitySampleAnalysis(
        sample: sample,
        complete: !issues.contains(where: reliabilityIssueInvalidatesEvidenceCompleteness),
        evidenceIdentity: evidenceIdentity,
        runID: runID,
        terminalStatus: terminalStatus,
        planDigest: planDigest,
        targetIdentityDigest: targetIdentityDigest,
        artifactKinds: artifactKinds,
        stepStatuses: stepStatuses,
        failureType: failureType,
        failureExplainable: failureExplainable,
        issues: issues
    )
}

private func markDuplicateReliabilitySamples(
    _ analyses: [TKTestReliabilitySampleAnalysis]
) -> [TKTestReliabilitySampleAnalysis] {
    var additionalIssues = Array(repeating: [String](), count: analyses.count)

    func markDuplicates<Value: Hashable>(
        code: String,
        value: (TKTestReliabilitySampleAnalysis) -> Value?
    ) {
        let grouped = Dictionary(grouping: analyses.indices.compactMap { index -> (Int, Value)? in
            guard let identity = value(analyses[index]) else { return nil }
            return (index, identity)
        }, by: \.1)
        for entries in grouped.values where entries.count > 1 {
            for (index, _) in entries {
                additionalIssues[index].append(code)
            }
        }
    }

    markDuplicates(code: "duplicate_evidence_bundle") { $0.evidenceIdentity }
    markDuplicates(code: "duplicate_reset_evidence_id") { analysis in
        let resetEvidenceID = analysis.sample.resetEvidenceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return resetEvidenceID.isEmpty ? nil : resetEvidenceID
    }
    markDuplicates(code: "duplicate_run_id") { $0.runID }

    return analyses.enumerated().map { index, analysis in
        analysis.addingIssues(additionalIssues[index])
    }
}

private func reliabilityIssueInvalidatesEvidenceCompleteness(_ issue: String) -> Bool {
    [
        "missing_manifest",
        "partial_evidence",
        "skipped_evidence",
        "missing_initial_state_id",
        "missing_reset_evidence_id",
        "missing_target_token",
        "missing_manifest_target",
        "missing_normalized_plan_artifact",
        "invalid_normalized_plan_artifact",
        "missing_runtime_target_artifact",
        "invalid_runtime_target_artifact",
        "runtime_target_artifact_mismatch",
        "missing_manifest_artifact",
        "missing_normalized_plan",
        "invalid_normalized_plan",
        "invalid_normalized_plan_steps",
        "unsupported_reliability_platform",
        "missing_runtime_target",
        "invalid_ios_simulator_runtime_target",
        "missing_plan_bundle",
        "missing_runtime_target_bundle",
        "missing_manifest_target_bundle",
        "disconnected_runtime_target",
        "disconnected_manifest_target",
        "runtime_target_simulator_mismatch",
        "noncanonical_runtime_target_id",
        "runtime_manifest_target_mismatch",
        "runtime_plan_bundle_mismatch",
        "plan_manifest_bundle_mismatch",
        "missing_run_manifest",
        "missing_run_metadata",
        "incomplete_run_manifest",
        "missing_run_summary",
        "missing_run_summary_id",
        "missing_run_verdict",
        "invalid_run_events",
        "missing_terminal_status",
        "invalid_run_sequence",
        "non_terminal_run_status",
        "missing_event_artifact",
        "undeclared_event_artifact",
        "missing_observation_artifact",
        "undeclared_observation_artifact",
        "observation_artifact_kind_mismatch",
        "observation_artifact_step_mismatch",
        "run_id_mismatch",
        "run_status_mismatch",
        "run_event_count_mismatch",
        "missing_run_event_count",
        "run_observation_count_mismatch",
        "missing_run_observation_count",
        "run_step_count_mismatch",
        "run_summary_id_mismatch",
        "run_verdict_mismatch",
        "manifest_status_mismatch",
        "plan_step_coverage_mismatch",
        "missing_step_observation",
        "duplicate_evidence_bundle",
        "duplicate_reset_evidence_id",
        "duplicate_run_id",
        "missing_failure_recovery",
        "missing_failure_artifact_ref",
        "undeclared_failure_artifact_ref",
        "terminal_failure_artifact_step_mismatch",
        "missing_terminal_failure_record",
    ].contains(issue)
}

private func validateReliabilityEventSequence(_ events: [TKTestRunEvent]) -> (terminalStatus: TKTestRunStatus?, issues: [String]) {
    guard let first = events.first else {
        return (nil, ["missing_terminal_status"])
    }
    var issues: [String] = []
    if first.type != .runStarted {
        issues.append("invalid_run_sequence")
    }
    if events.dropFirst().contains(where: { $0.type == .runStarted })
        || events.contains(where: { $0.type == .runPaused || $0.type == .runStopped }) {
        issues.append("invalid_run_sequence")
    }
    if first.runID.isEmpty || events.contains(where: { $0.runID != first.runID }) {
        issues.append("run_id_mismatch")
    }
    let terminalEvents = events.enumerated().filter { $0.element.type == .runFinished }
    guard terminalEvents.count == 1,
          let terminal = terminalEvents.first,
          terminal.offset == events.count - 1,
          let status = terminal.element.status else {
        issues.append("missing_terminal_status")
        return (nil, issues)
    }
    guard status == .passed || status == .failed || status == .blocked else {
        issues.append("non_terminal_run_status")
        return (status, issues)
    }
    return (status, issues)
}

private struct TKTestReliabilityEventArtifactCreation {
    let stepIndex: Int
    let offset: Int
}

private struct TKTestReliabilityEventArtifactTimeline {
    let commandOffsetsByStep: [Int: [Int]]
    let creationsByKindAndPath: [String: [TKTestReliabilityEventArtifactCreation]]
}

private func reliabilityArtifactReferenceKey(
    kind: String,
    root: URL,
    reference: String
) -> String? {
    guard let url = containedEvidenceEventReferenceURL(root: root, relativePath: reference) else {
        return nil
    }
    return "\(kind)\u{0}\(url.path)"
}

private func reliabilityEventArtifactTimeline(
    _ events: [TKTestRunEvent],
    root: URL,
    manifestArtifacts: TKTestReliabilityManifestArtifactInventory
) -> TKTestReliabilityEventArtifactTimeline {
    var commandOffsetsByStep: [Int: [Int]] = [:]
    var creationsByKindAndPath: [String: [TKTestReliabilityEventArtifactCreation]] = [:]
    for (offset, event) in events.enumerated() {
        if event.type == .commandExecuted, let stepIndex = event.stepIndex {
            commandOffsetsByStep[stepIndex, default: []].append(offset)
        }
        guard event.type == .artifactCreated,
              let stepIndex = event.stepIndex,
              let kind = event.artifactKind,
              let reference = event.ref,
              manifestArtifacts.containsArtifact(kind: kind, root: root, relativePath: reference),
              let key = reliabilityArtifactReferenceKey(kind: kind, root: root, reference: reference) else {
            continue
        }
        creationsByKindAndPath[key, default: []].append(
            TKTestReliabilityEventArtifactCreation(stepIndex: stepIndex, offset: offset)
        )
    }
    return TKTestReliabilityEventArtifactTimeline(
        commandOffsetsByStep: commandOffsetsByStep,
        creationsByKindAndPath: creationsByKindAndPath
    )
}

private func reliabilityObservationReferencesHaveDeclaredKinds(
    _ event: TKTestRunEvent,
    root: URL,
    manifestArtifacts: TKTestReliabilityManifestArtifactInventory
) -> Bool {
    guard let artifacts = event.artifacts else {
        return false
    }
    return reliabilityObservationArtifactReferences(artifacts).allSatisfy { expected in
        guard let reference = expected.reference,
              !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return manifestArtifacts.containsArtifact(
            kind: expected.kind,
            root: root,
            relativePath: reference
        )
    }
}

private func reliabilityObservationHasStepBoundArtifact(
    _ event: TKTestRunEvent,
    eventOffset: Int,
    root: URL,
    manifestArtifacts: TKTestReliabilityManifestArtifactInventory,
    timeline: TKTestReliabilityEventArtifactTimeline
) -> Bool {
    guard let stepIndex = event.stepIndex,
          reliabilityObservationReferencesHaveDeclaredKinds(
              event,
              root: root,
              manifestArtifacts: manifestArtifacts
          ) else {
        return false
    }
    let commandOffsets = timeline.commandOffsetsByStep[stepIndex] ?? []
    guard !commandOffsets.isEmpty,
          let artifacts = event.artifacts else {
        return false
    }
    return reliabilityObservationArtifactReferences(artifacts).allSatisfy { expected in
        guard let reference = expected.reference,
              let key = reliabilityArtifactReferenceKey(
                  kind: expected.kind,
                  root: root,
                  reference: reference
              ),
              let creations = timeline.creationsByKindAndPath[key] else {
            return false
        }
        return creations.contains { creation in
            creation.stepIndex == stepIndex
                && creation.offset < eventOffset
                && commandOffsets.contains(where: { $0 < creation.offset })
        }
    }
}

private func reliabilityEventArtifactIssues(
    _ events: [TKTestRunEvent],
    root: URL,
    manifestArtifacts: TKTestReliabilityManifestArtifactInventory
) -> [String] {
    var missingEventArtifact = false
    var undeclaredEventArtifact = false
    var missingObservationArtifact = false
    var undeclaredObservationArtifact = false
    var observationArtifactKindMismatch = false
    var observationArtifactStepMismatch = false
    let timeline = reliabilityEventArtifactTimeline(
        events,
        root: root,
        manifestArtifacts: manifestArtifacts
    )
    for (offset, event) in events.enumerated() {
        if event.type == .artifactCreated,
           let kind = event.artifactKind,
           let ref = event.ref {
            if containedEvidenceEventReferenceURL(root: root, relativePath: ref) == nil {
                missingEventArtifact = true
            } else if !manifestArtifacts.containsArtifact(kind: kind, root: root, relativePath: ref) {
                undeclaredEventArtifact = true
            }
        }
        if event.type == .observationCaptured {
            guard let artifacts = event.artifacts else {
                missingObservationArtifact = true
                continue
            }
            let expectedArtifacts = reliabilityObservationArtifactReferences(artifacts)
            if expectedArtifacts.contains(where: { $0.reference?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false }) {
                missingObservationArtifact = true
                continue
            }
            for expected in expectedArtifacts {
                guard let reference = expected.reference else { continue }
                if containedEvidenceEventReferenceURL(root: root, relativePath: reference) == nil {
                    missingObservationArtifact = true
                } else if !manifestArtifacts.containsReference(root: root, relativePath: reference) {
                    undeclaredObservationArtifact = true
                } else if !manifestArtifacts.containsArtifact(
                    kind: expected.kind,
                    root: root,
                    relativePath: reference
                ) {
                    observationArtifactKindMismatch = true
                }
            }
            if reliabilityObservationReferencesHaveDeclaredKinds(
                event,
                root: root,
                manifestArtifacts: manifestArtifacts
            ) && !reliabilityObservationHasStepBoundArtifact(
                event,
                eventOffset: offset,
                root: root,
                manifestArtifacts: manifestArtifacts,
                timeline: timeline
            ) {
                observationArtifactStepMismatch = true
            }
        }
    }
    var issues: [String] = []
    if missingEventArtifact {
        issues.append("missing_event_artifact")
    }
    if undeclaredEventArtifact {
        issues.append("undeclared_event_artifact")
    }
    if missingObservationArtifact {
        issues.append("missing_observation_artifact")
    }
    if undeclaredObservationArtifact {
        issues.append("undeclared_observation_artifact")
    }
    if observationArtifactKindMismatch {
        issues.append("observation_artifact_kind_mismatch")
    }
    if observationArtifactStepMismatch {
        issues.append("observation_artifact_step_mismatch")
    }
    return issues
}

private func reliabilityObservationArtifactReferences(
    _ artifacts: TKTestRunObservationArtifacts
) -> [(kind: String, reference: String?)] {
    [
        (kind: "screenshot", reference: artifacts.screenshot),
        (kind: "accessibility", reference: artifacts.ax),
        (kind: "hierarchy", reference: artifacts.hierarchy),
    ]
}

struct TKTestReliabilityTerminalFailure {
    let failure: TKTestRunFailure
    let stepIndex: Int
    let commandOffset: Int
    let failureOffset: Int
}

func reliabilityTerminalFailure(
    from events: [TKTestRunEvent],
    status: TKTestRunStatus?
) -> TKTestReliabilityTerminalFailure? {
    guard status == .failed || status == .blocked else {
        return nil
    }
    let indexedEvents = Array(events.enumerated())
    guard let terminalFinish = indexedEvents.last(where: {
        $0.element.type == .stepFinished && $0.element.status != .passed
    }),
          terminalFinish.element.status == status,
          let stepIndex = terminalFinish.element.stepIndex else {
        return nil
    }
    let starts = indexedEvents.filter {
        $0.element.type == .stepStarted
            && $0.element.stepIndex == stepIndex
            && $0.offset < terminalFinish.offset
    }
    let commands = indexedEvents.filter {
        $0.element.type == .commandExecuted
            && $0.element.stepIndex == stepIndex
            && $0.element.status == status
            && $0.offset < terminalFinish.offset
    }
    guard starts.count == 1,
          commands.count == 1,
          let start = starts.first,
          let command = commands.first,
          start.offset < command.offset,
          command.offset < terminalFinish.offset else {
        return nil
    }
    let failures = indexedEvents.filter {
        $0.element.type == .failureRecorded
            && $0.element.stepIndex == stepIndex
            && $0.element.failure != nil
            && command.offset < $0.offset
            && $0.offset < terminalFinish.offset
    }
    guard failures.count == 1 else {
        return nil
    }
    guard let failure = failures[0].element.failure else {
        return nil
    }
    return TKTestReliabilityTerminalFailure(
        failure: failure,
        stepIndex: stepIndex,
        commandOffset: command.offset,
        failureOffset: failures[0].offset
    )
}

private func reliabilityTerminalFailureArtifactsBelongToTerminalStep(
    _ terminalFailure: TKTestReliabilityTerminalFailure,
    events: [TKTestRunEvent],
    root: URL,
    manifestArtifacts: TKTestReliabilityManifestArtifactInventory
) -> Bool {
    let createdArtifactPaths = Set(events.enumerated().compactMap { entry -> String? in
        guard entry.offset > terminalFailure.commandOffset,
              entry.offset < terminalFailure.failureOffset,
              entry.element.type == .artifactCreated,
              entry.element.stepIndex == terminalFailure.stepIndex,
              let kind = entry.element.artifactKind,
              let reference = entry.element.ref,
              manifestArtifacts.containsArtifact(kind: kind, root: root, relativePath: reference),
              let url = containedEvidenceEventReferenceURL(root: root, relativePath: reference) else {
            return nil
        }
        return url.path
    })
    return !terminalFailure.failure.artifactRefs.isEmpty
        && terminalFailure.failure.artifactRefs.allSatisfy { reference in
            guard let url = containedEvidenceEventReferenceURL(root: root, relativePath: reference) else {
                return false
            }
            return createdArtifactPaths.contains(url.path)
        }
}

private func reliabilityPlanEventCoverageIssues(
    plan: TKTestNormalizedPlan,
    events: [TKTestRunEvent],
    terminalStatus: TKTestRunStatus?,
    root: URL,
    manifestArtifacts: TKTestReliabilityManifestArtifactInventory
) -> [String] {
    guard terminalStatus == .passed || terminalStatus == .failed || terminalStatus == .blocked else {
        return []
    }
    let orderedSteps = plan.steps.sorted { $0.index < $1.index }
    guard !orderedSteps.isEmpty else {
        return ["plan_step_coverage_mismatch"]
    }
    let indexedEvents = Array(events.enumerated())
    let expectedSteps: [TKTestPlanStep]
    if terminalStatus == .passed {
        expectedSteps = orderedSteps
    } else if let terminalEvent = indexedEvents.last(where: {
        $0.element.type == .stepFinished && $0.element.status != .passed
    }), let stepIndex = terminalEvent.element.stepIndex,
              let position = orderedSteps.firstIndex(where: { $0.index == stepIndex }) {
        expectedSteps = Array(orderedSteps.prefix(through: position))
    } else {
        return ["plan_step_coverage_mismatch"]
    }

    let expectedIndexes = Set(expectedSteps.map(\.index))
    let terminalFailureStepIndex = terminalStatus == .passed ? nil : expectedSteps.last?.index
    let trackedEventTypes: Set<TKTestRunEventType> = [
        .stepStarted,
        .commandExecuted,
        .artifactCreated,
        .assertionResult,
        .observationCaptured,
        .vlmGrounding,
        .failureRecorded,
        .stepFinished,
    ]
    var coverageMismatch = false
    var missingObservation = false
    let timeline = reliabilityEventArtifactTimeline(
        events,
        root: root,
        manifestArtifacts: manifestArtifacts
    )

    for step in expectedSteps {
        let started = indexedEvents.filter {
            $0.element.type == .stepStarted && $0.element.stepIndex == step.index
        }
        let commands = indexedEvents.filter {
            $0.element.type == .commandExecuted && $0.element.stepIndex == step.index
        }
        let finished = indexedEvents.filter {
            $0.element.type == .stepFinished && $0.element.stepIndex == step.index
        }
        guard started.count == 1,
              commands.count == 1,
              finished.count == 1,
              let start = started.first,
              let command = commands.first,
              let finish = finished.first,
              start.element.stepID == step.id,
              start.element.stepType == step.type,
              finish.element.stepID == step.id,
              command.element.status == finish.element.status,
              start.offset < command.offset,
              command.offset < finish.offset else {
            coverageMismatch = true
            continue
        }

        if terminalStatus == .passed {
            if !step.optional, finish.element.status != .passed {
                coverageMismatch = true
            }
        } else if let terminalFailureStepIndex {
            if step.index == terminalFailureStepIndex {
                if step.optional || finish.element.status != terminalStatus {
                    coverageMismatch = true
                }
            } else if !step.optional, finish.element.status != .passed {
                coverageMismatch = true
            }
        }

        if reliabilityStepRequiresObservation(step) {
            let observations = indexedEvents.filter {
                    $0.element.type == .observationCaptured
                    && $0.element.stepIndex == step.index
                    && reliabilityObservationHasStepBoundArtifact(
                        $0.element,
                        eventOffset: $0.offset,
                        root: root,
                        manifestArtifacts: manifestArtifacts,
                        timeline: timeline
                    )
                    && command.offset < $0.offset
                    && $0.offset < finish.offset
            }
            if observations.isEmpty {
                missingObservation = true
            }
        }
    }

    if indexedEvents.contains(where: { entry in
        guard trackedEventTypes.contains(entry.element.type),
              let stepIndex = entry.element.stepIndex else {
            return false
        }
        return !expectedIndexes.contains(stepIndex)
    }) {
        coverageMismatch = true
    }

    var issues: [String] = []
    if coverageMismatch {
        issues.append("plan_step_coverage_mismatch")
    }
    if missingObservation {
        issues.append("missing_step_observation")
    }
    return issues
}

private func reliabilityNormalizedPlanStepsAreCanonical(_ plan: TKTestNormalizedPlan) -> Bool {
    let orderedSteps = plan.steps.sorted { $0.index < $1.index }
    guard !orderedSteps.isEmpty else {
        return false
    }
    var stepIDs = Set<String>()
    for (expectedIndex, step) in orderedSteps.enumerated() {
        guard step.index == expectedIndex,
              !step.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              stepIDs.insert(step.id).inserted,
              let expectedKind = reliabilityExpectedPlanStepKind(for: step.type),
              step.kind == expectedKind else {
            return false
        }
    }
    return true
}

private func reliabilityExpectedPlanStepKind(for type: String) -> String? {
    switch type {
    case "launch", "stop", "tap", "input", "press", "swipe", "scrollUntilVisible":
        return "action"
    case "takeScreenshot", "extractTextWithAI":
        return "observation"
    case "assertVisible", "assertNotVisible", "assertWithAI", "assertNoDefectsWithAI", "assertScreenshot":
        return "assertion"
    default:
        return nil
    }
}

private func reliabilityStepRequiresObservation(_ step: TKTestPlanStep) -> Bool {
    switch step.type {
    case "takeScreenshot", "tap", "input", "press", "swipe", "scrollUntilVisible",
         "assertWithAI", "assertNoDefectsWithAI", "extractTextWithAI", "assertScreenshot":
        return true
    case "launch", "stop", "assertVisible", "assertNotVisible":
        return false
    default:
        return true
    }
}

private func containedEvidenceRegularFileURL(root: URL, relativePath: String, base: URL? = nil) -> URL? {
    guard !relativePath.isEmpty,
          !relativePath.hasPrefix("/") else {
        return nil
    }
    let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
    let candidate = (base ?? root).appendingPathComponent(relativePath).resolvingSymlinksInPath().standardizedFileURL
    guard candidate.path == resolvedRoot.path || candidate.path.hasPrefix(resolvedRoot.path + "/") else {
        return nil
    }
    guard (try? candidate.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
        return nil
    }
    return candidate
}

private func containedEvidenceEventReferenceURL(root: URL, relativePath: String) -> URL? {
    containedEvidenceRegularFileURL(root: root, relativePath: relativePath)
        ?? containedEvidenceRegularFileURL(root: root, relativePath: relativePath, base: root.appendingPathComponent("run", isDirectory: true))
}

private func reliabilityRuntimeTarget(root: URL) -> TKTargetSummary? {
    guard let targetURL = containedEvidenceRegularFileURL(root: root, relativePath: "runtime-target.json"),
          let data = try? Data(contentsOf: targetURL),
          let target = try? JSONDecoder().decode(TKTargetSummary.self, from: data),
          !target.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    return target
}

private func reliabilityEvidenceVerdict(for status: TKTestRunStatus) -> TKEvidenceRunVerdict? {
    switch status {
    case .passed:
        return .success
    case .failed:
        return .failure
    case .blocked:
        return .blocked
    case .running, .paused, .stopped:
        return nil
    }
}

private func reliabilityRecoveryID(for failureType: String) -> String? {
    switch failureType {
    case "launch_failed":
        return "rerun_runtime_preflight"
    case "tap_failed", "input_failed", "press_failed", "swipe_failed", "text_not_found":
        return "inspect_action_observation"
    case "assert_visible_failed", "assert_not_visible_failed", "ai_assertion_failed", "assert_screenshot_failed", "assert_screenshot_baseline_missing":
        return "inspect_assertion_observation"
    case "scroll_until_visible_failed":
        return "inspect_scroll_observation"
    case "vlm_step_not_allowed":
        return "inspect_vlm_policy"
    case "primitive_failed", "stop_not_supported":
        return "inspect_runner_failure"
    default:
        return nil
    }
}

private func reliabilityMetric(
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

private func buildOutcomeRepeatability(
    supportedAnalyses: [TKTestReliabilitySampleAnalysis],
    issueCounts: inout [String: Int]
) -> TKTestReliabilityMetric {
    let grouped = Dictionary(grouping: supportedAnalyses, by: { $0.sample.flowID })
    var numerator = 0
    var denominator = 0
    for flowID in grouped.keys.sorted() {
        let flowAnalyses = grouped[flowID, default: []].filter(\.complete)
        guard let baseline = flowAnalyses.first,
              let baselineSignature = baseline.repeatabilitySignature else {
            continue
        }
        for analysis in flowAnalyses {
            guard let signature = analysis.repeatabilitySignature else { continue }
            denominator += 1
            if signature == baselineSignature {
                numerator += 1
                continue
            }
            if analysis.sample.initialStateID != baseline.sample.initialStateID {
                issueCounts["initial_state_drift", default: 0] += 1
            }
            if analysis.targetIdentityDigest != baseline.targetIdentityDigest {
                issueCounts["target_drift", default: 0] += 1
            }
            if analysis.planDigest != baseline.planDigest {
                issueCounts["plan_digest_drift", default: 0] += 1
            }
            if analysis.artifactKinds != baseline.artifactKinds {
                issueCounts["artifact_taxonomy_drift", default: 0] += 1
            }
        }
    }
    return reliabilityMetric(numerator: numerator, denominator: denominator, notEvaluableWhenEmpty: true)
}

private func buildReliabilityFlows(from analyses: [TKTestReliabilitySampleAnalysis]) -> [TKTestReliabilityFlow] {
    let grouped = Dictionary(grouping: analyses, by: { $0.sample.flowID })
    return grouped.keys.sorted().enumerated().map { offset, flowID in
        let flowAnalyses = grouped[flowID, default: []]
        let digests = flowAnalyses.compactMap(\.planDigest).sorted()
        return TKTestReliabilityFlow(
            flowID: String(format: "flow_%03d", offset + 1),
            sampleCount: flowAnalyses.count,
            planDigest: digests.first ?? "unavailable"
        )
    }
}

private func buildReliabilityGate(
    thresholds: TKTestReliabilityThresholds,
    evidenceCompleteness: TKTestReliabilityMetric,
    failureExplainability: TKTestReliabilityMetric,
    outcomeRepeatability: TKTestReliabilityMetric,
    supportedAnalyses: [TKTestReliabilitySampleAnalysis]
) -> TKTestReliabilityGate {
    var blockers: [String] = []
    if evidenceCompleteness.rate < thresholds.minimumEvidenceCompletenessRate {
        blockers.append("evidence_completeness_below_threshold")
    }
    let completeSupported = supportedAnalyses.filter(\.complete)
    let groups = Dictionary(grouping: completeSupported, by: { $0.sample.flowID })
    if groups.count < thresholds.minimumSupportedFlows {
        blockers.append("insufficient_supported_flows")
    }
    if groups.values.contains(where: { $0.count < thresholds.minimumRunsPerFlow }) || groups.count < thresholds.minimumSupportedFlows {
        blockers.append("insufficient_supported_runs")
    }
    if thresholds.minimumFailureSamples > 0 {
        if failureExplainability.denominator < thresholds.minimumFailureSamples {
            blockers.append("insufficient_failure_samples")
        } else if failureExplainability.rate < thresholds.minimumFailureExplainabilityRate {
            blockers.append("failure_explainability_below_threshold")
        }
    }
    if outcomeRepeatability.state == .notEvaluable {
        blockers.append("outcome_repeatability_not_evaluable")
    } else if outcomeRepeatability.rate < thresholds.minimumOutcomeRepeatabilityRate {
        blockers.append("outcome_repeatability_below_threshold")
        if outcomeRepeatability.rate < 0.70 {
            blockers.append("stop_expansion")
        }
    }
    let uniqueBlockers = Array(Set(blockers)).sorted()
    return TKTestReliabilityGate(
        status: uniqueBlockers.isEmpty ? .passed : .blocked,
        blockerCodes: uniqueBlockers
    )
}
