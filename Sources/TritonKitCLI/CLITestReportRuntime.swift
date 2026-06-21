import Foundation
import TritonKitShared

func buildTritonTestReport(input: String) throws -> TKTestReportResponse {
    let root = evidenceBundleRoot(from: input)
    _ = try readEvidenceManifest(from: input)

    let eventsURL = root.appendingPathComponent("run/events.jsonl")
    guard FileManager.default.fileExists(atPath: eventsURL.path) else {
        throw RuntimeError("Missing test run event log at \(eventsURL.path)")
    }

    let parsed = try TKTestRunEventLogParser().parse(Data(contentsOf: eventsURL))
    let runMetadata = try readTestRunMetadata(from: root)
    let artifacts = collectReportArtifacts(from: parsed.events)
    let steps = buildReportSteps(from: parsed.events)
    let failure = parsed.events.first { $0.type == .failureRecorded }?.failure
    let summary = TKTestReportSummary(
        status: parsed.summary.status ?? runMetadata?.status,
        eventCount: parsed.summary.eventCount,
        stepCount: parsed.summary.stepCount,
        assertionCount: parsed.summary.assertionCount,
        artifactCount: parsed.summary.artifactCount,
        observationCount: parsed.summary.observationCount,
        failureCount: parsed.summary.failureCount,
        screenshotCount: countScreenshotReferences(events: parsed.events),
        overlayCount: artifacts.filter { $0.kind == "vlm.overlay" }.count
    )

    return TKTestReportResponse(
        evidenceDir: root.path,
        run: runMetadata.map(reportRun),
        summary: summary,
        failure: failure,
        steps: steps,
        artifacts: artifacts,
        suggestedCommands: [
            "triton evidence summary \(shellQuotedEvidencePath(root.path)) --json",
            "triton evidence project-workspace \(shellQuotedEvidencePath(root.path)) --json",
        ]
    )
}

private struct TKMutableTestReportStep {
    var stepIndex: Int
    var stepId: String?
    var stepType: String?
    var status: TKTestRunStatus?
    var durationMs: Int?
    var command: [String]?
    var exitCode: Int?
    var assertion: TKTestReportAssertion?
    var failure: TKTestRunFailure?
    var observations: [TKTestReportObservation] = []
    var artifacts: [TKTestReportArtifact] = []
    var vlmGrounding: TKVLMGroundResponse?

    func frozen() -> TKTestReportStep {
        TKTestReportStep(
            stepIndex: stepIndex,
            stepId: stepId,
            stepType: stepType,
            status: status,
            durationMs: durationMs,
            command: command,
            exitCode: exitCode,
            assertion: assertion,
            failure: failure,
            observations: observations,
            artifacts: artifacts,
            vlmGrounding: vlmGrounding
        )
    }
}

private func buildReportSteps(from events: [TKTestRunEvent]) -> [TKTestReportStep] {
    var builders: [Int: TKMutableTestReportStep] = [:]

    func builder(for index: Int) -> TKMutableTestReportStep {
        builders[index] ?? TKMutableTestReportStep(stepIndex: index)
    }

    for event in events {
        guard let stepIndex = event.stepIndex else { continue }
        var current = builder(for: stepIndex)
        switch event.type {
        case .stepStarted:
            current.stepId = event.stepID
            current.stepType = event.stepType
        case .commandExecuted:
            current.command = event.command
            current.status = event.status
            current.exitCode = event.exitCode
        case .artifactCreated:
            if let kind = event.artifactKind, let ref = event.ref {
                current.artifacts.append(TKTestReportArtifact(kind: kind, ref: ref, sha256: event.sha256))
            }
        case .assertionResult:
            if let status = event.status, let selector = event.selector {
                current.assertion = TKTestReportAssertion(status: status, selector: selector)
                current.status = status
            }
        case .observationCaptured:
            if let phase = event.phase,
               let artifacts = event.artifacts,
               let candidate = event.screenCandidate {
                current.observations.append(TKTestReportObservation(
                    phase: phase,
                    changed: event.changed,
                    artifacts: artifacts,
                    screenCandidate: candidate
                ))
            }
        case .vlmGrounding:
            current.vlmGrounding = event.vlmGrounding
        case .stepFinished:
            current.stepId = event.stepID ?? current.stepId
            current.status = event.status
            current.durationMs = event.durationMs
        case .failureRecorded:
            current.failure = event.failure
            current.status = .failed
        default:
            break
        }
        builders[stepIndex] = current
    }

    return builders.keys.sorted().compactMap { builders[$0]?.frozen() }
}

private func collectReportArtifacts(from events: [TKTestRunEvent]) -> [TKTestReportArtifact] {
    var seen = Set<String>()
    var artifacts: [TKTestReportArtifact] = []
    for event in events where event.type == .artifactCreated {
        guard let kind = event.artifactKind, let ref = event.ref else { continue }
        let key = "\(kind)::\(ref)"
        guard seen.insert(key).inserted else { continue }
        artifacts.append(TKTestReportArtifact(kind: kind, ref: ref, sha256: event.sha256))
    }
    return artifacts
}

private func countScreenshotReferences(events: [TKTestRunEvent]) -> Int {
    var refs = Set<String>()
    for event in events {
        if event.type == .artifactCreated,
           event.artifactKind == "screenshot",
           let ref = event.ref {
            refs.insert(ref)
        }
        if event.type == .observationCaptured,
           let ref = event.artifacts?.screenshot {
            refs.insert(ref)
        }
    }
    return refs.count
}

private func readTestRunMetadata(from evidenceRoot: URL) throws -> TKTestRunMetadata? {
    let runURL = evidenceRoot.appendingPathComponent("run/run.json")
    guard FileManager.default.fileExists(atPath: runURL.path) else {
        return nil
    }
    return try JSONDecoder().decode(TKTestRunMetadata.self, from: Data(contentsOf: runURL))
}

private func reportRun(_ metadata: TKTestRunMetadata) -> TKTestReportRun {
    TKTestReportRun(
        runId: metadata.runID,
        source: metadata.source,
        status: metadata.status,
        startedAt: metadata.startedAt,
        endedAt: metadata.endedAt,
        durationMs: metadata.durationMs,
        planRef: metadata.planRef
    )
}
