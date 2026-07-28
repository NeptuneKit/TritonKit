import CryptoKit
import Foundation
import TritonKitShared

struct TKTestRunExecutionResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let input: String
    let evidenceDir: String
    let normalizedPlan: TKTestNormalizedPlan
    let run: TKTestRunMetadata
    let summary: TKTestRunEventSummary
    let failedStepIndex: Int?
    let failure: TKTestRunFailure?

    init(
        ok: Bool,
        input: String,
        evidenceDir: String,
        normalizedPlan: TKTestNormalizedPlan,
        run: TKTestRunMetadata,
        summary: TKTestRunEventSummary,
        failedStepIndex: Int? = nil,
        failure: TKTestRunFailure? = nil
    ) {
        self.ok = ok
        self.schemaVersion = 1
        self.kind = "triton.test.run-result"
        self.input = input
        self.evidenceDir = evidenceDir
        self.normalizedPlan = normalizedPlan
        self.run = run
        self.summary = summary
        self.failedStepIndex = failedStepIndex
        self.failure = failure
    }
}

struct TKTestRunExecutionContext {
    let evidenceDirectory: URL
    let target: String
    let host: String
    let port: Int
    let runID: String
    let allowVLM: Bool
    let allowRemoteVLM: Bool
    let vlmBaseURL: String?
    let vlmModel: String?
    let vlmModelPath: String?
    let vlmAPIKeyEnv: String?
    let vlmAllowModelDownload: Bool

    init(
        evidenceDirectory: URL,
        target: String,
        host: String,
        port: Int,
        runID: String,
        allowVLM: Bool = false,
        allowRemoteVLM: Bool = false,
        vlmBaseURL: String? = nil,
        vlmModel: String? = nil,
        vlmModelPath: String? = nil,
        vlmAPIKeyEnv: String? = nil,
        vlmAllowModelDownload: Bool = false
    ) {
        self.evidenceDirectory = evidenceDirectory
        self.target = target
        self.host = host
        self.port = port
        self.runID = runID
        self.allowVLM = allowVLM
        self.allowRemoteVLM = allowRemoteVLM
        self.vlmBaseURL = vlmBaseURL
        self.vlmModel = vlmModel
        self.vlmModelPath = vlmModelPath
        self.vlmAPIKeyEnv = vlmAPIKeyEnv
        self.vlmAllowModelDownload = vlmAllowModelDownload
    }
}

struct TKTestRunPublishedScreenshotMetadata: Codable, Equatable {
    let format: String
    let width: Double
    let height: Double
    let scale: Double
    let dataRef: String?
    let imagePath: String
    let bytes: Int
    let sourceFormat: String
}

func testRunPublishedScreenshotMetadata(
    runtimeScreenshot: TKScreenshotResponse,
    artifactData: Data,
    imagePath: String
) -> TKTestRunPublishedScreenshotMetadata {
    TKTestRunPublishedScreenshotMetadata(
        format: "png",
        width: runtimeScreenshot.width,
        height: runtimeScreenshot.height,
        scale: runtimeScreenshot.scale,
        dataRef: nil,
        imagePath: imagePath,
        bytes: artifactData.count,
        sourceFormat: runtimeScreenshot.format.lowercased()
    )
}

struct TKTestRunVLMGroundingOutcome: Equatable {
    let response: TKVLMGroundResponse
}

struct TKTestRunAssertionOutcome: Equatable {
    let status: TKTestRunStatus
    let selector: TKTestRunSelector
}

struct TKTestRunObservationOutcome: Equatable {
    let phase: String
    let artifacts: TKTestRunObservationArtifacts
    let screenCandidate: TKTestRunScreenCandidate
    let changed: Bool?
    let evidenceArtifacts: [TKEvidenceArtifact]

    init(
        phase: String,
        artifacts: TKTestRunObservationArtifacts,
        screenCandidate: TKTestRunScreenCandidate,
        changed: Bool? = nil,
        evidenceArtifacts: [TKEvidenceArtifact] = []
    ) {
        self.phase = phase
        self.artifacts = artifacts
        self.screenCandidate = screenCandidate
        self.changed = changed
        self.evidenceArtifacts = evidenceArtifacts
    }
}

struct TKTestRunPrimitiveOutcome: Equatable {
    let command: [String]
    let status: TKTestRunStatus
    let exitCode: Int
    let durationMs: Int
    let artifacts: [TKEvidenceArtifact]
    let observations: [TKTestRunObservationOutcome]
    let vlmGroundings: [TKTestRunVLMGroundingOutcome]
    let assertion: TKTestRunAssertionOutcome?
    let failure: TKTestRunFailure?

    static func passed(
        command: [String],
        durationMs: Int = 0,
        artifacts: [TKEvidenceArtifact] = [],
        observations: [TKTestRunObservationOutcome] = [],
        vlmGroundings: [TKTestRunVLMGroundingOutcome] = [],
        assertion: TKTestRunAssertionOutcome? = nil
    ) -> TKTestRunPrimitiveOutcome {
        TKTestRunPrimitiveOutcome(
            command: command,
            status: .passed,
            exitCode: 0,
            durationMs: durationMs,
            artifacts: artifacts,
            observations: observations,
            vlmGroundings: vlmGroundings,
            assertion: assertion,
            failure: nil
        )
    }

    static func failed(
        command: [String],
        durationMs: Int = 0,
        exitCode: Int = 1,
        failure: TKTestRunFailure,
        assertion: TKTestRunAssertionOutcome? = nil,
        artifacts: [TKEvidenceArtifact] = [],
        observations: [TKTestRunObservationOutcome] = [],
        vlmGroundings: [TKTestRunVLMGroundingOutcome] = []
    ) -> TKTestRunPrimitiveOutcome {
        TKTestRunPrimitiveOutcome(
            command: command,
            status: .failed,
            exitCode: exitCode,
            durationMs: durationMs,
            artifacts: artifacts,
            observations: observations,
            vlmGroundings: vlmGroundings,
            assertion: assertion,
            failure: failure
        )
    }
}

protocol TKTestRunPrimitiveExecutor {
    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome
}

struct TKTestRunPrimitiveError: Error, Equatable {
    let type: String
    let message: String
}

func runTritonTest(
    input: String,
    evidenceDirectory: String,
    target: String,
    host: String,
    port: Int,
    executor: TKTestRunPrimitiveExecutor,
    allowVLM: Bool = false,
    allowRemoteVLM: Bool = false,
    vlmBaseURL: String? = nil,
    vlmModel: String? = nil,
    vlmModelPath: String? = nil,
    vlmAPIKeyEnv: String? = nil,
    vlmAllowModelDownload: Bool = false,
    normalizedPlanOverride: TKTestNormalizedPlan? = nil
) async throws -> TKTestRunExecutionResponse {
    let plan: TKTestNormalizedPlan
    if let normalizedPlanOverride {
        plan = normalizedPlanOverride
    } else {
        let inputURL = URL(fileURLWithPath: input)
        let yaml: String
        do {
            yaml = try String(contentsOf: inputURL, encoding: .utf8)
        } catch {
            throw testValidationFailure(
                code: "missing_required_field",
                message: "\(error)",
                path: "$"
            )
        }
        plan = try validateTritonTestContract(yaml: yaml, inputPath: input)
    }
    let evidenceURL = URL(fileURLWithPath: evidenceDirectory, isDirectory: true)
    try prepareEvidenceOutputDirectory(evidenceURL)
    try resetTestRunArtifacts(in: evidenceURL)

    let normalizedPlanArtifact = TKEvidenceArtifact(
        kind: "test.normalized-plan",
        path: "normalized-plan.json",
        contentType: "application/json"
    )
    try prettyEncodedData(plan).write(
        to: evidenceURL.appendingPathComponent(normalizedPlanArtifact.path),
        options: .atomic
    )
    try writeTestRunCoordinateContract(
        screenshot: nil,
        geometry: nil,
        evidenceDirectory: evidenceURL
    )

    var artifacts = [
        normalizedPlanArtifact,
        TKEvidenceArtifact(kind: "test.run.meta", path: "run/run.json", contentType: "application/json"),
        TKEvidenceArtifact(kind: "test.run.events", path: "run/events.jsonl", contentType: "application/jsonl"),
        TKEvidenceArtifact(kind: "coordinate.contract", path: "coordinate-contract.json", contentType: "application/json"),
    ]
    var artifactKeys = Set(artifacts.map(testRunArtifactKey))

    let started = Date()
    let startedAt = testRunTimestamp(started)
    let runID = "run-\(UUID().uuidString.lowercased())"
    let initialRun = TKTestRunMetadata(
        runID: runID,
        source: input,
        status: .running,
        startedAt: startedAt,
        planRef: "../normalized-plan.json"
    )
    let writer = try TKTestRunEventWriter(evidenceDirectory: evidenceURL, run: initialRun)
    try writer.append(.runStarted(runID: runID, timestamp: startedAt))

    let context = TKTestRunExecutionContext(
        evidenceDirectory: evidenceURL,
        target: target,
        host: host,
        port: port,
        runID: runID,
        allowVLM: allowVLM,
        allowRemoteVLM: allowRemoteVLM,
        vlmBaseURL: vlmBaseURL,
        vlmModel: vlmModel,
        vlmModelPath: vlmModelPath,
        vlmAPIKeyEnv: vlmAPIKeyEnv,
        vlmAllowModelDownload: vlmAllowModelDownload
    )

    var finalStatus: TKTestRunStatus = .passed
    var failedStepIndex: Int?
    var finalFailure: TKTestRunFailure?

    for step in plan.steps {
        let stepStart = Date()
        try writer.append(.stepStarted(
            runID: runID,
            stepIndex: step.index,
            stepID: step.id,
            stepType: step.type,
            timestamp: testRunTimestamp(stepStart)
        ))

        let outcome: TKTestRunPrimitiveOutcome
        do {
            outcome = try await executor.execute(step: step, plan: plan, context: context)
        } catch let primitive as TKTestRunPrimitiveError {
            let failure = TKTestRunFailure(type: primitive.type, message: primitive.message)
            outcome = .failed(
                command: ["triton", "test", "run", input, "step", step.type],
                durationMs: testRunElapsedMilliseconds(since: stepStart),
                failure: failure
            )
        } catch {
            let failure = TKTestRunFailure(type: "primitive_failed", message: "\(error)")
            outcome = .failed(
                command: ["triton", "test", "run", input, "step", step.type],
                durationMs: testRunElapsedMilliseconds(since: stepStart),
                failure: failure
            )
        }

        try writer.append(.commandExecuted(
            runID: runID,
            stepIndex: step.index,
            command: outcome.command,
            status: outcome.status,
            exitCode: outcome.exitCode,
            durationMs: outcome.durationMs,
            timestamp: testRunTimestamp()
        ))

        let stepArtifacts = outcome.artifacts + outcome.observations.flatMap(\.evidenceArtifacts)
        for artifact in stepArtifacts where artifactKeys.insert(testRunArtifactKey(artifact)).inserted {
            artifacts.append(artifact)
            try writer.append(.artifactCreated(
                runID: runID,
                stepIndex: step.index,
                kind: artifact.kind,
                ref: testRunEventRef(for: artifact.path),
                timestamp: testRunTimestamp()
            ))
        }

        for observation in outcome.observations {
            try writer.append(.observationCaptured(
                runID: runID,
                stepIndex: step.index,
                phase: observation.phase,
                artifacts: observation.artifacts,
                screenCandidate: observation.screenCandidate,
                changed: observation.changed,
                timestamp: testRunTimestamp()
            ))
        }

        for grounding in outcome.vlmGroundings {
            try writer.append(.vlmGrounding(
                runID: runID,
                stepIndex: step.index,
                grounding: grounding.response,
                timestamp: testRunTimestamp()
            ))
        }

        if let assertion = outcome.assertion {
            try writer.append(.assertionResult(
                runID: runID,
                stepIndex: step.index,
                status: assertion.status,
                selector: assertion.selector,
                timestamp: testRunTimestamp()
            ))
        }

        if outcome.status != .passed {
            let stepFailure = normalizedFailure(outcome.failure, artifacts: stepArtifacts)
            try writer.append(.failureRecorded(
                runID: runID,
                stepIndex: step.index,
                failure: stepFailure,
                timestamp: testRunTimestamp()
            ))
            try writer.append(.stepFinished(
                runID: runID,
                stepIndex: step.index,
                stepID: step.id,
                status: outcome.status,
                durationMs: testRunElapsedMilliseconds(since: stepStart),
                timestamp: testRunTimestamp()
            ))
            if step.optional {
                continue
            }
            finalStatus = outcome.status
            failedStepIndex = step.index
            finalFailure = stepFailure
            break
        }

        try writer.append(.stepFinished(
            runID: runID,
            stepIndex: step.index,
            stepID: step.id,
            status: .passed,
            durationMs: testRunElapsedMilliseconds(since: stepStart),
            timestamp: testRunTimestamp()
        ))
    }

    let duration = testRunElapsedMilliseconds(since: started)
    try writer.append(.runFinished(
        runID: runID,
        status: finalStatus,
        durationMs: duration,
        timestamp: testRunTimestamp()
    ))

    let finalRun = TKTestRunMetadata(
        runID: runID,
        source: input,
        status: finalStatus,
        startedAt: startedAt,
        endedAt: testRunTimestamp(),
        durationMs: duration,
        planRef: "../normalized-plan.json"
    )
    try prettyEncodedData(finalRun).write(to: writer.runURL, options: .atomic)

    let parsed = try TKTestRunEventLogParser().parse(Data(contentsOf: writer.eventsURL))
    let manifest = buildTestRunEvidenceManifest(
        evidenceDirectory: evidenceURL,
        artifacts: artifacts,
        runID: runID,
        status: finalStatus,
        eventCount: parsed.summary.eventCount,
        observationCount: parsed.summary.observationCount,
        stepCount: parsed.summary.stepCount,
        target: testRunTargetArtifact(from: executor),
        createdAt: startedAt
    )
    try prettyEncodedData(manifest).write(
        to: evidenceURL.appendingPathComponent("manifest.json"),
        options: .atomic
    )

    let responseRun = TKTestRunMetadata(
        runID: runID,
        source: input,
        status: finalStatus,
        startedAt: startedAt,
        endedAt: finalRun.endedAt,
        durationMs: duration,
        planRef: "../normalized-plan.json"
    )
    return TKTestRunExecutionResponse(
        ok: finalStatus == .passed,
        input: input,
        evidenceDir: evidenceURL.path,
        normalizedPlan: plan,
        run: responseRun,
        summary: parsed.summary,
        failedStepIndex: failedStepIndex,
        failure: finalFailure
    )
}

/// Executes a receipt-frozen normalized plan without reopening the mutable
/// source YAML. The ordinary `test run` entry remains the validating YAML
/// path; reliability collection code owns the exclusive evidence reservation
/// before calling this narrow bridge.
func runTritonFrozenTest(
    normalizedPlan: TKTestNormalizedPlan,
    evidenceDirectory: String,
    target: String,
    host: String,
    port: Int,
    executor: TKTestRunPrimitiveExecutor,
    source: String = "reliability-receipt"
) async throws -> TKTestRunExecutionResponse {
    try await runTritonTest(
        input: source,
        evidenceDirectory: evidenceDirectory,
        target: target,
        host: host,
        port: port,
        executor: executor,
        normalizedPlanOverride: normalizedPlan
    )
}

final class TKLiveTestRunPrimitiveExecutor: TKTestRunPrimitiveExecutor {
    private var resolved: (summary: TKTargetSummary, client: TritonKitHTTPClient)?

    /// Receipt-backed reliability samples preflight the exact target before
    /// claiming their one-time slot. Reuse that exact summary/client pairing
    /// so the ordinary resolver cannot later fall back to a same-UDID target.
    func pinReliabilityRuntimeTarget(
        _ summary: TKTargetSummary,
        host: String,
        port: Int
    ) {
        resolved = (
            summary: summary,
            client: TritonKitHTTPClient(host: host, port: port, target: summary.id)
        )
    }

    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        switch step.type {
        case "launch":
            return try await executeLaunch(plan: plan, context: context)
        case "stop":
            return try await executeStop(step: step, plan: plan, context: context)
        case "takeScreenshot":
            return try await executeScreenshot(step: step, plan: plan, context: context)
        case "tap":
            return try await executeTap(step: step, plan: plan, context: context)
        case "input":
            return try await executeInput(step: step, plan: plan, context: context)
        case "press":
            return try await executePress(step: step, plan: plan, context: context)
        case "swipe":
            return try await executeSwipe(step: step, plan: plan, context: context)
        case "assertVisible":
            return try await executeAssertVisible(step: step, plan: plan, context: context, expectedVisible: true)
        case "assertNotVisible":
            return try await executeAssertVisible(step: step, plan: plan, context: context, expectedVisible: false)
        case "scrollUntilVisible":
            return try await executeScrollUntilVisible(step: step, plan: plan, context: context)
        case "assertWithAI", "assertNoDefectsWithAI", "extractTextWithAI":
            return try await executeMockAIStep(step: step, plan: plan, context: context)
        case "assertScreenshot":
            return try await executeAssertScreenshot(step: step, plan: plan, context: context)
        default:
            throw TKTestRunPrimitiveError(type: "unsupported_step", message: "Unsupported runner step: \(step.type)")
        }
    }

    fileprivate var targetSummary: TKTargetSummary? {
        resolved?.summary
    }

    private func executeLaunch(
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        let started = Date()
        let summary = try await resolveRuntime(plan: plan, context: context).summary
        try writeTestRunArtifact(
            try prettyEncodedData(summary),
            relativePath: "runtime-target.json",
            evidenceDirectory: context.evidenceDirectory
        )
        return .passed(
            command: ["triton", "list", "--bundle-id", plan.app.bundleId, "--json"],
            durationMs: testRunElapsedMilliseconds(since: started),
            artifacts: [
                TKEvidenceArtifact(
                    kind: "runtime.target",
                    path: "runtime-target.json",
                    contentType: "application/json",
                    bytes: nil,
                    target: summary.id
                )
            ]
        )
    }

    private func executeStop(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let observation = try? await captureObservation(
            step: step,
            phase: "before",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-before.png",
            metadataPath: "debug/\(step.id)-before-screenshot.json",
            axPath: "debug/\(step.id)-before-ax.json",
            hierarchyPath: "debug/\(step.id)-before-hierarchy.json"
        )
        return .failed(
            command: ["triton", "app", "terminate", "--bundle-id", plan.app.bundleId, "--json"],
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: TKTestRunFailure(
                type: "stop_not_supported",
                message: "test run stop requires host app terminate target selection; embedded runtime-only execution cannot safely terminate the app yet"
            ),
            observations: observation.map { [$0] } ?? []
        )
    }

    private func executeScreenshot(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let screenshotPath = "screenshots/\(step.id).png"
        let metadataPath = "screenshots/\(step.id).json"
        let observation = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: screenshotPath,
            metadataPath: metadataPath,
            axPath: "debug/\(step.id)-after-ax.json",
            hierarchyPath: "debug/\(step.id)-after-hierarchy.json"
        )
        return .passed(
            command: ["triton", "screenshot", "--target", runtime.summary.id, "--output", screenshotPath, "--json"],
            durationMs: testRunElapsedMilliseconds(since: started),
            observations: [observation]
        )
    }

    private func executeTap(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        if step.point == nil, step.target != nil {
            return try await executeVLMTap(step: step, plan: plan, context: context)
        }
        if step.point == nil, step.selector != nil {
            return try await executeTextTap(step: step, plan: plan, context: context)
        }
        guard let point = step.point else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "tap requires point/runtime-point coordinates")
        }
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let before = try await captureObservation(
            step: step,
            phase: "before",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-before.png",
            metadataPath: "debug/\(step.id)-before-screenshot.json",
            axPath: "debug/\(step.id)-before-ax.json",
            hierarchyPath: "debug/\(step.id)-before-hierarchy.json"
        )
        let result = try await executeInputRequest(
            .tap(x: point.x, y: point.y, targetOID: nil, width: nil, height: nil, duration: nil),
            client: runtime.client
        )
        try? await Task.sleep(nanoseconds: 150_000_000)
        var after = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-after.png",
            metadataPath: "debug/\(step.id)-after-screenshot.json",
            axPath: "debug/\(step.id)-after-ax.json",
            hierarchyPath: "debug/\(step.id)-after-hierarchy.json"
        )
        after = after.withChanged(before.screenCandidate != after.screenCandidate)
        let command = [
            "triton", "tap",
            "--target", runtime.summary.id,
            "--x", formatTestRunNumber(point.x),
            "--y", formatTestRunNumber(point.y),
            "--json",
        ]
        if result.ok {
            return .passed(
                command: command,
                durationMs: testRunElapsedMilliseconds(since: started),
                observations: [before, after]
            )
        }
        return .failed(
            command: command,
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: TKTestRunFailure(
                type: "tap_failed",
                message: result.message ?? result.error?.message ?? "Runtime tap command failed"
            ),
            observations: [before, after]
        )
    }

    private func executeTextTap(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let selector = step.selector else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "tap.text requires text selector")
        }
        guard selector.source == "ax", selector.match == "exact" else {
            throw TKTestRunPrimitiveError(type: "unsupported_selector", message: "tap.text only supports source=ax and match=exact")
        }

        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let runSelector = TKTestRunSelector(text: TKTestRunTextSelector(value: selector.text, match: selector.match, source: selector.source))
        let before = try await captureObservation(
            step: step,
            phase: "before",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-before.png",
            metadataPath: "debug/\(step.id)-before-screenshot.json",
            axPath: "debug/\(step.id)-before-ax.json",
            hierarchyPath: "debug/\(step.id)-before-hierarchy.json"
        )

        let command = [
            "triton", "tap",
            selector.text,
            "--target", runtime.summary.id,
            "--json",
        ]

        let inputRequest: TKInputRequest
        do {
            let accessibilityData = try await runtime.client.request(type: "accessibility")
            let axNodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
            guard let node = selectAXNodesByQuery(axNodes, query: selector.text, includeValue: false).first else {
                throw TKTapTargetResolutionFailure(
                    query: selector.text,
                    message: "No exact AX text target matched query: \(selector.text)",
                    candidateCount: 0,
                    nearestCandidates: [],
                    suggestedCommands: tapTargetSuggestedCommands(query: selector.text)
                )
            }
            inputRequest = tapRequest(
                for: node,
                width: nil,
                height: nil,
                duration: nil,
                activationStrategy: .smart
            )
        } catch let failure as TKTapTargetResolutionFailure {
            return .failed(
                command: command,
                durationMs: testRunElapsedMilliseconds(since: started),
                failure: TKTestRunFailure(type: "text_not_found", message: failure.message, selector: runSelector),
                observations: [before]
            )
        }

        let result = try await executeInputRequest(inputRequest, client: runtime.client)
        try? await Task.sleep(nanoseconds: 150_000_000)
        var after = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-after.png",
            metadataPath: "debug/\(step.id)-after-screenshot.json",
            axPath: "debug/\(step.id)-after-ax.json",
            hierarchyPath: "debug/\(step.id)-after-hierarchy.json"
        )
        after = after.withChanged(before.screenCandidate != after.screenCandidate)

        if result.ok {
            return .passed(
                command: command,
                durationMs: testRunElapsedMilliseconds(since: started),
                observations: [before, after]
            )
        }
        return .failed(
            command: command,
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: TKTestRunFailure(
                type: "tap_failed",
                message: result.message ?? result.error?.message ?? "Runtime tap text command failed",
                selector: runSelector
            ),
            observations: [before, after]
        )
    }

    private func executeVLMTap(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let target = step.target, step.grounding == "vlm" else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "tap.target requires grounding=vlm")
        }
        guard context.allowVLM else {
            return .failed(
                command: ["triton", "test", "run", "tap", "--target", target, "--grounding", "vlm"],
                failure: TKTestRunFailure(
                    type: "vlm_step_not_allowed",
                    message: "VLM-assisted tap(target) requires --allow-vlm"
                )
            )
        }

        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let beforeScreenshotPath = "debug/\(step.id)-before.png"
        let before = try await captureObservation(
            step: step,
            phase: "before",
            runtime: runtime,
            context: context,
            screenshotPath: beforeScreenshotPath,
            metadataPath: "debug/\(step.id)-before-screenshot.json",
            axPath: "debug/\(step.id)-before-ax.json",
            hierarchyPath: "debug/\(step.id)-before-hierarchy.json"
        )

        let provider = step.provider ?? "mock"
        let grounding: TKVLMGroundResponse
        do {
            grounding = try groundVLMTarget(
                provider: provider,
                image: context.evidenceDirectory.appendingPathComponent(beforeScreenshotPath).path,
                target: target,
                coordinateContract: context.evidenceDirectory.appendingPathComponent("coordinate-contract.json").path,
                outputDirectory: context.evidenceDirectory.appendingPathComponent("debug/\(step.id)-vlm", isDirectory: true).path,
                baseURL: context.vlmBaseURL,
                model: step.model ?? context.vlmModel,
                modelPath: step.modelPath ?? context.vlmModelPath,
                apiKeyEnv: context.vlmAPIKeyEnv,
                allowRemoteVLM: context.allowRemoteVLM,
                maxTokens: step.maxTokens ?? 64,
                temperature: step.temperature ?? 0,
                seed: step.seed ?? 0,
                promptTemplate: step.promptTemplate ?? "gui-grounding-v1",
                allowModelDownload: step.allowModelDownload ?? context.vlmAllowModelDownload
            )
        } catch let failure as TKVLMGroundingFailure {
            return .failed(
                command: ["triton", "vlm", "ground", "--provider", provider, "--target", target, "--json"],
                durationMs: testRunElapsedMilliseconds(since: started),
                failure: TKTestRunFailure(type: failure.code, message: failure.message),
                observations: [before]
            )
        }

        let point = grounding.point.runtimePoint
        let inputResult = try await executeInputRequest(
            .tap(x: point.x, y: point.y, targetOID: nil, width: nil, height: nil, duration: nil),
            client: runtime.client
        )
        try? await Task.sleep(nanoseconds: 150_000_000)
        var after = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-after.png",
            metadataPath: "debug/\(step.id)-after-screenshot.json",
            axPath: "debug/\(step.id)-after-ax.json",
            hierarchyPath: "debug/\(step.id)-after-hierarchy.json"
        )
        after = after.withChanged(before.screenCandidate != after.screenCandidate)

        let vlmArtifacts = testRunVLMArtifacts(from: grounding, evidenceDirectory: context.evidenceDirectory, target: runtime.summary.id)
        let command = [
            "triton", "test", "run", "tap",
            "--target", target,
            "--grounding", "vlm",
            "--provider", provider,
            step.model.map { "--model=\($0)" },
            step.modelPath.map { "--model-path=\($0)" },
            "--json",
        ].compactMap { $0 }
        let groundingOutcome = TKTestRunVLMGroundingOutcome(response: grounding)
        if inputResult.ok {
            return .passed(
                command: command,
                durationMs: testRunElapsedMilliseconds(since: started),
                artifacts: vlmArtifacts,
                observations: [before, after],
                vlmGroundings: [groundingOutcome]
            )
        }
        return .failed(
            command: command,
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: TKTestRunFailure(
                type: "tap_failed",
                message: inputResult.message ?? inputResult.error?.message ?? "Runtime tap command failed after VLM grounding",
                artifactRefs: vlmArtifacts.map { testRunEventRef(for: $0.path) }
            ),
            artifacts: vlmArtifacts,
            observations: [before, after],
            vlmGroundings: [groundingOutcome]
        )
    }

    private func executeInput(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let text = step.text else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "input requires text")
        }
        return try await executeInputActionWithObservations(
            step: step,
            plan: plan,
            context: context,
            input: .typeText(text),
            command: ["triton", "type", text, "--json"],
            failureType: "input_failed"
        )
    }

    private func executePress(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let button = step.button else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "press requires button")
        }
        return try await executeInputActionWithObservations(
            step: step,
            plan: plan,
            context: context,
            input: .press(button: button),
            command: ["triton", "press", button, "--json"],
            failureType: "press_failed"
        )
    }

    private func executeSwipe(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let from = step.point, let to = step.endPoint else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "swipe requires from/to runtime-point coordinates")
        }
        return try await executeInputActionWithObservations(
            step: step,
            plan: plan,
            context: context,
            input: .swipe(startX: from.x, startY: from.y, endX: to.x, endY: to.y),
            command: [
                "triton", "swipe",
                "--from-x", formatTestRunNumber(from.x),
                "--from-y", formatTestRunNumber(from.y),
                "--to-x", formatTestRunNumber(to.x),
                "--to-y", formatTestRunNumber(to.y),
                "--json",
            ],
            failureType: "swipe_failed"
        )
    }

    private func executeInputActionWithObservations(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext,
        input: TKInputRequest,
        command: [String],
        failureType: String
    ) async throws -> TKTestRunPrimitiveOutcome {
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let before = try await captureObservation(
            step: step,
            phase: "before",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-before.png",
            metadataPath: "debug/\(step.id)-before-screenshot.json",
            axPath: "debug/\(step.id)-before-ax.json",
            hierarchyPath: "debug/\(step.id)-before-hierarchy.json"
        )
        let result = try await executeInputRequest(input, client: runtime.client)
        try? await Task.sleep(nanoseconds: 150_000_000)
        var after = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-after.png",
            metadataPath: "debug/\(step.id)-after-screenshot.json",
            axPath: "debug/\(step.id)-after-ax.json",
            hierarchyPath: "debug/\(step.id)-after-hierarchy.json"
        )
        after = after.withChanged(before.screenCandidate != after.screenCandidate)
        if result.ok {
            return .passed(
                command: command,
                durationMs: testRunElapsedMilliseconds(since: started),
                observations: [before, after]
            )
        }
        return .failed(
            command: command,
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: TKTestRunFailure(
                type: failureType,
                message: result.message ?? result.error?.message ?? "Runtime input command failed"
            ),
            observations: [before, after]
        )
    }

    private func executeMockAIStep(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let observation = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-ai.png",
            metadataPath: "debug/\(step.id)-ai-screenshot.json",
            axPath: "debug/\(step.id)-ai-ax.json",
            hierarchyPath: "debug/\(step.id)-ai-hierarchy.json"
        )
        let extractedText = step.type == "extractTextWithAI"
            ? observation.screenCandidate.visibleTexts.joined(separator: "\n")
            : nil
        let result = TKTestAIResult(
            provider: step.provider ?? "mock",
            stepType: step.type,
            status: .passed,
            prompt: step.prompt,
            extractedText: extractedText,
            screenshot: observation.artifacts.screenshot,
            note: "mock provider uses captured AX visibleTexts and does not call a remote model"
        )
        let resultPath = "debug/\(step.id)-ai-result.json"
        try writeTestRunArtifact(
            try prettyEncodedData(result),
            relativePath: resultPath,
            evidenceDirectory: context.evidenceDirectory
        )
        let artifact = TKEvidenceArtifact(
            kind: step.type == "extractTextWithAI" ? "ai.extraction" : "ai.assertion",
            path: resultPath,
            contentType: "application/json",
            target: runtime.summary.id
        )
        let assertion: TKTestRunAssertionOutcome?
        if step.type == "extractTextWithAI" {
            assertion = nil
        } else {
            assertion = TKTestRunAssertionOutcome(
                status: .passed,
                selector: TKTestRunSelector(text: TKTestRunTextSelector(value: step.prompt ?? step.type, match: "exact", source: "ai"))
            )
        }
        return .passed(
            command: ["triton", "test", "run", step.type, "--provider", step.provider ?? "mock", "--json"],
            durationMs: testRunElapsedMilliseconds(since: started),
            artifacts: [artifact],
            observations: [observation],
            assertion: assertion
        )
    }

    private func executeAssertScreenshot(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let baseline = step.baseline else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "assertScreenshot requires baseline")
        }
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let observation = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-assert-screenshot.png",
            metadataPath: "debug/\(step.id)-assert-screenshot.json",
            axPath: "debug/\(step.id)-assert-screenshot-ax.json",
            hierarchyPath: "debug/\(step.id)-assert-screenshot-hierarchy.json"
        )
        let selector = TKTestRunSelector(text: TKTestRunTextSelector(value: baseline, match: "exact", source: "screenshot"))
        let command = ["triton", "test", "run", "assertScreenshot", "--baseline", baseline, "--json"]
        let baselineURL = URL(fileURLWithPath: baseline)
        guard FileManager.default.fileExists(atPath: baselineURL.path) else {
            let failure = TKTestRunFailure(
                type: "assert_screenshot_baseline_missing",
                message: "Baseline screenshot does not exist: \(baseline)",
                selector: selector,
                artifactRefs: observation.evidenceArtifacts.map { testRunEventRef(for: $0.path) }
            )
            return .failed(
                command: command,
                durationMs: testRunElapsedMilliseconds(since: started),
                failure: failure,
                assertion: TKTestRunAssertionOutcome(status: .failed, selector: selector),
                observations: [observation]
            )
        }
        let baselineHash = try testRunSHA256(Data(contentsOf: baselineURL))
        let passed = baselineHash == observation.screenCandidate.screenshotSha256
        let result = TKTestAIResult(
            provider: "deterministic",
            stepType: step.type,
            status: passed ? .passed : .failed,
            prompt: "baseline=\(baseline); threshold=\(step.threshold ?? 0); cropOn=\(step.cropOn ?? "")",
            screenshot: observation.artifacts.screenshot,
            note: passed ? "screenshot SHA256 matched baseline" : "screenshot SHA256 did not match baseline; pixel threshold diff is not implemented in P14"
        )
        let resultPath = "debug/\(step.id)-assert-screenshot-result.json"
        try writeTestRunArtifact(
            try prettyEncodedData(result),
            relativePath: resultPath,
            evidenceDirectory: context.evidenceDirectory
        )
        let resultArtifact = TKEvidenceArtifact(kind: "screenshot.diff", path: resultPath, contentType: "application/json", target: runtime.summary.id)
        let assertion = TKTestRunAssertionOutcome(status: passed ? .passed : .failed, selector: selector)
        if passed {
            return .passed(
                command: command,
                durationMs: testRunElapsedMilliseconds(since: started),
                artifacts: [resultArtifact],
                observations: [observation],
                assertion: assertion
            )
        }
        return .failed(
            command: command,
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: TKTestRunFailure(
                type: "assert_screenshot_failed",
                message: "Screenshot hash did not match baseline \(baseline)",
                selector: selector,
                artifactRefs: ([resultArtifact] + observation.evidenceArtifacts).map { testRunEventRef(for: $0.path) }
            ),
            assertion: assertion,
            artifacts: [resultArtifact],
            observations: [observation]
        )
    }

    private func executeAssertVisible(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext,
        expectedVisible: Bool
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let testSelector = step.selector else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "\(step.type) requires text selector")
        }
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let status: TKStatusResponse = try await runtime.client.getJSON("/status")
        let accessibilityData = try await runtime.client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        let assertRequest = TKUIAssertRequest(condition: .textExists, query: testSelector.text)
        let result = TKUIAssertEvaluate(
            assertRequest,
            nodes: nodes,
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState
        )
        let passed = expectedVisible ? result.ok : !result.ok
        let selector = TKTestRunSelector(text: TKTestRunTextSelector(
            value: testSelector.text,
            match: testSelector.match,
            source: testSelector.source
        ))
        let assertion = TKTestRunAssertionOutcome(
            status: passed ? .passed : .failed,
            selector: selector
        )
        let command = [
            "triton", "assert", "text-exists", testSelector.text,
            "--target", runtime.summary.id,
            "--json",
        ]
        if passed {
            return .passed(command: command, durationMs: testRunElapsedMilliseconds(since: started), assertion: assertion)
        }

        let assertResultPath = "debug/\(step.id)-assert-result.json"
        try writeTestRunArtifact(
            try prettyEncodedData(result),
            relativePath: assertResultPath,
            evidenceDirectory: context.evidenceDirectory
        )
        let assertArtifact = TKEvidenceArtifact(
            kind: "assert.result",
            path: assertResultPath,
            contentType: "application/json",
            target: runtime.summary.id
        )
        let observation = try await captureObservation(
            step: step,
            phase: "after",
            runtime: runtime,
            context: context,
            screenshotPath: "debug/\(step.id)-failure.png",
            metadataPath: "debug/\(step.id)-failure-screenshot.json",
            axPath: "debug/\(step.id)-ax.json",
            hierarchyPath: "debug/\(step.id)-hierarchy.json"
        )
        let artifacts = [assertArtifact] + observation.evidenceArtifacts

        let failure = TKTestRunFailure(
            type: expectedVisible ? "assert_visible_failed" : "assert_not_visible_failed",
            message: expectedVisible
                ? (result.message ?? "AX exact text not visible: \(testSelector.text)")
                : "AX exact text was visible: \(testSelector.text)",
            selector: selector,
            artifactRefs: artifacts.map { testRunEventRef(for: $0.path) }
        )
        return .failed(
            command: command,
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: failure,
            assertion: assertion,
            artifacts: [assertArtifact],
            observations: [observation]
        )
    }

    private func executeScrollUntilVisible(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        guard let selector = step.selector else {
            throw TKTestRunPrimitiveError(type: "invalid_step", message: "scrollUntilVisible requires text selector")
        }
        let started = Date()
        let runtime = try await resolveRuntime(plan: plan, context: context)
        let maxScrolls = step.maxScrolls ?? 5
        let geometryData = try await runtime.client.request(type: "geometry")
        let geometry = try JSONDecoder().decode(TKGeometryResponse.self, from: geometryData)
        var observations: [TKTestRunObservationOutcome] = []
        let command = [
            "triton", "wait", selector.text,
            "--source", selector.source,
            "--match", selector.match,
            "--json",
        ]
        for attempt in 0...maxScrolls {
            let observation = try await captureObservation(
                step: step,
                phase: attempt == 0 ? "before" : "after",
                runtime: runtime,
                context: context,
                screenshotPath: "debug/\(step.id)-scroll-\(attempt).png",
                metadataPath: "debug/\(step.id)-scroll-\(attempt)-screenshot.json",
                axPath: "debug/\(step.id)-scroll-\(attempt)-ax.json",
                hierarchyPath: "debug/\(step.id)-scroll-\(attempt)-hierarchy.json"
            )
            observations.append(observation)
            if observation.screenCandidate.visibleTexts.contains(selector.text) {
                return .passed(
                    command: command,
                    durationMs: testRunElapsedMilliseconds(since: started),
                    observations: observations,
                    assertion: TKTestRunAssertionOutcome(
                        status: .passed,
                        selector: TKTestRunSelector(text: TKTestRunTextSelector(value: selector.text, match: selector.match, source: selector.source))
                    )
                )
            }
            guard attempt < maxScrolls else { break }
            let swipe = makeScrollInput(direction: step.direction ?? "down", geometry: geometry)
            let inputResult = try await executeInputRequest(swipe, client: runtime.client)
            guard inputResult.ok else {
                return .failed(
                    command: command,
                    durationMs: testRunElapsedMilliseconds(since: started),
                    failure: TKTestRunFailure(
                        type: "scroll_until_visible_failed",
                        message: inputResult.message ?? inputResult.error?.message ?? "Runtime scroll command failed"
                    ),
                    observations: observations
                )
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        let runSelector = TKTestRunSelector(text: TKTestRunTextSelector(value: selector.text, match: selector.match, source: selector.source))
        return .failed(
            command: command,
            durationMs: testRunElapsedMilliseconds(since: started),
            failure: TKTestRunFailure(
                type: "scroll_until_visible_failed",
                message: "AX exact text not visible after \(maxScrolls) scrolls: \(selector.text)",
                selector: runSelector,
                artifactRefs: observations.flatMap(\.evidenceArtifacts).map { testRunEventRef(for: $0.path) }
            ),
            assertion: TKTestRunAssertionOutcome(status: .failed, selector: runSelector),
            observations: observations
        )
    }

    private func makeScrollInput(direction: String, geometry: TKGeometryResponse) -> TKInputRequest {
        let width = max(1, geometry.bounds.width)
        let height = max(1, geometry.bounds.height)
        switch direction {
        case "up":
            return .swipe(startX: width * 0.5, startY: height * 0.35, endX: width * 0.5, endY: height * 0.75)
        case "left":
            return .swipe(startX: width * 0.35, startY: height * 0.5, endX: width * 0.75, endY: height * 0.5)
        case "right":
            return .swipe(startX: width * 0.75, startY: height * 0.5, endX: width * 0.35, endY: height * 0.5)
        default:
            return .swipe(startX: width * 0.5, startY: height * 0.75, endX: width * 0.5, endY: height * 0.35)
        }
    }

    private func resolveRuntime(
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> (summary: TKTargetSummary, client: TritonKitHTTPClient) {
        if let resolved {
            return resolved
        }
        let client = TritonKitHTTPClient(host: context.host, port: context.port)
        let targets: TKTargetsResponse = try await client.getJSON("/targets")
        let summary: TKTargetSummary
        if TKNormalizeTargetID(context.target) == TKLocalTargetID,
           let matchingBundle = targets.targets.first(where: { $0.connected && $0.bundleIdentifier == plan.app.bundleId }) {
            summary = matchingBundle
        } else {
            summary = try TKResolveTargetSummary(context.target, in: targets.targets)
        }
        if let bundleID = summary.bundleIdentifier, bundleID != plan.app.bundleId {
            throw TKTestRunPrimitiveError(
                type: "launch_failed",
                message: "Resolved target \(summary.id) is \(bundleID), expected \(plan.app.bundleId)"
            )
        }
        guard summary.connected else {
            throw TKTestRunPrimitiveError(
                type: "launch_failed",
                message: "Resolved target \(summary.id) is not connected"
            )
        }
        let runtime = (
            summary: summary,
            client: TritonKitHTTPClient(host: context.host, port: context.port, target: summary.id)
        )
        resolved = runtime
        return runtime
    }

    private func captureFailureHierarchy(
        step: TKTestPlanStep,
        runtime: (summary: TKTargetSummary, client: TritonKitHTTPClient),
        context: TKTestRunExecutionContext
    ) async throws -> TKEvidenceArtifact? {
        do {
            let data = try await runtime.client.latestHierarchyData()
            let path = "debug/\(step.id)-hierarchy.json"
            try writeTestRunArtifact(data, relativePath: path, evidenceDirectory: context.evidenceDirectory)
            return TKEvidenceArtifact(
                kind: "hierarchy",
                path: path,
                contentType: "application/json",
                bytes: data.count,
                target: runtime.summary.id
            )
        } catch {
            return nil
        }
    }

    private func captureFailureScreenshot(
        step: TKTestPlanStep,
        runtime: (summary: TKTargetSummary, client: TritonKitHTTPClient),
        context: TKTestRunExecutionContext
    ) async throws -> [TKEvidenceArtifact] {
        do {
            let screenshotData = try await runtime.client.request(type: "screenshot")
            let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
            let imageData = try await screenshotImageData(screenshot, client: runtime.client)
            let screenshotPath = "debug/\(step.id)-failure.png"
            let artifactData = try normalizeRuntimeScreenshotToPNG(
                imageData,
                declaredFormat: screenshot.format,
                outputPath: screenshotPath
            )
            let metadataPath = "debug/\(step.id)-failure-screenshot.json"
            let metadataData = try prettyEncodedData(testRunPublishedScreenshotMetadata(
                runtimeScreenshot: screenshot,
                artifactData: artifactData,
                imagePath: screenshotPath
            ))
            try writeTestRunArtifact(artifactData, relativePath: screenshotPath, evidenceDirectory: context.evidenceDirectory)
            try writeTestRunArtifact(
                metadataData,
                relativePath: metadataPath,
                evidenceDirectory: context.evidenceDirectory
            )
            return [
                TKEvidenceArtifact(kind: "screenshot", path: screenshotPath, contentType: "image/png", bytes: artifactData.count, target: runtime.summary.id),
                TKEvidenceArtifact(kind: "screenshot.metadata", path: metadataPath, contentType: "application/json", bytes: metadataData.count, target: runtime.summary.id),
            ]
        } catch {
            return []
        }
    }

    private func captureObservation(
        step: TKTestPlanStep,
        phase: String,
        runtime: (summary: TKTargetSummary, client: TritonKitHTTPClient),
        context: TKTestRunExecutionContext,
        screenshotPath: String,
        metadataPath: String,
        axPath: String,
        hierarchyPath: String
    ) async throws -> TKTestRunObservationOutcome {
        let screenshotData = try await runtime.client.request(type: "screenshot")
        let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
        let imageData = try await screenshotImageData(screenshot, client: runtime.client)
        let artifactData = try normalizeRuntimeScreenshotToPNG(
            imageData,
            declaredFormat: screenshot.format,
            outputPath: screenshotPath
        )
        let accessibilityData = try await runtime.client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        let hierarchyData = try await runtime.client.latestHierarchyData()
        let geometryData = try await runtime.client.request(type: "geometry")
        let geometry = try JSONDecoder().decode(TKGeometryResponse.self, from: geometryData)
        let metadataData = try prettyEncodedData(testRunPublishedScreenshotMetadata(
            runtimeScreenshot: screenshot,
            artifactData: artifactData,
            imagePath: screenshotPath
        ))

        try writeTestRunArtifact(artifactData, relativePath: screenshotPath, evidenceDirectory: context.evidenceDirectory)
        try writeTestRunArtifact(
            metadataData,
            relativePath: metadataPath,
            evidenceDirectory: context.evidenceDirectory
        )
        try writeTestRunArtifact(accessibilityData, relativePath: axPath, evidenceDirectory: context.evidenceDirectory)
        try writeTestRunArtifact(hierarchyData, relativePath: hierarchyPath, evidenceDirectory: context.evidenceDirectory)
        try writeTestRunCoordinateContract(
            screenshot: screenshot,
            geometry: geometry,
            evidenceDirectory: context.evidenceDirectory
        )

        let visibleTexts = testRunVisibleTexts(from: nodes)
        let screenCandidate = TKTestRunScreenCandidate(
            screenshotSha256: testRunSHA256(artifactData),
            axTextHash: testRunSHA256(Data(visibleTexts.joined(separator: "\n").utf8)),
            hierarchySha256: testRunSHA256(hierarchyData),
            visibleTexts: visibleTexts
        )
        return TKTestRunObservationOutcome(
            phase: phase,
            artifacts: TKTestRunObservationArtifacts(
                screenshot: testRunEventRef(for: screenshotPath),
                ax: testRunEventRef(for: axPath),
                hierarchy: testRunEventRef(for: hierarchyPath)
            ),
            screenCandidate: screenCandidate,
            evidenceArtifacts: [
                TKEvidenceArtifact(kind: "screenshot", path: screenshotPath, contentType: "image/png", bytes: artifactData.count, target: runtime.summary.id),
                TKEvidenceArtifact(kind: "screenshot.metadata", path: metadataPath, contentType: "application/json", bytes: metadataData.count, target: runtime.summary.id),
                TKEvidenceArtifact(kind: "accessibility", path: axPath, contentType: "application/json", bytes: accessibilityData.count, target: runtime.summary.id),
                TKEvidenceArtifact(kind: "hierarchy", path: hierarchyPath, contentType: "application/json", bytes: hierarchyData.count, target: runtime.summary.id),
            ]
        )
    }
}

private func resetTestRunArtifacts(in evidenceURL: URL) throws {
    let runURL = evidenceURL.appendingPathComponent("run", isDirectory: true)
    if FileManager.default.fileExists(atPath: runURL.path) {
        try FileManager.default.removeItem(at: runURL)
    }
}

private func normalizedFailure(_ failure: TKTestRunFailure?, artifacts: [TKEvidenceArtifact]) -> TKTestRunFailure {
    guard let failure else {
        return TKTestRunFailure(
            type: "primitive_failed",
            message: "Step failed without a machine-readable failure payload",
            artifactRefs: artifacts.map { testRunEventRef(for: $0.path) }
        )
    }
    if !failure.artifactRefs.isEmpty || artifacts.isEmpty {
        return failure
    }
    return TKTestRunFailure(
        type: failure.type ?? "primitive_failed",
        message: failure.message,
        selector: failure.selector,
        artifactRefs: artifacts.map { testRunEventRef(for: $0.path) }
    )
}

private func buildTestRunEvidenceManifest(
    evidenceDirectory: URL,
    artifacts: [TKEvidenceArtifact],
    runID: String,
    status: TKTestRunStatus,
    eventCount: Int,
    observationCount: Int,
    stepCount: Int,
    target: TKEvidenceTarget?,
    createdAt: String
) -> TKEvidenceManifest {
    let screenshotPaths = artifacts
        .filter { $0.kind == "screenshot" }
        .map(\.path)
    let debugPaths = artifacts
        .filter { $0.path.hasPrefix("debug/") }
        .map(\.path)
    return TKEvidenceManifest(
        ok: status == .passed,
        name: "triton-test-run",
        createdAt: createdAt,
        output: evidenceDirectory.path,
        artifacts: artifacts,
        target: target,
        cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion),
        run: TKEvidenceRunManifest(
            eventsPath: "run/events.jsonl",
            metaPath: "run/run.json",
            screenshotPaths: screenshotPaths,
            debugArtifactPaths: debugPaths,
            eventCount: eventCount,
            observationCount: observationCount,
            status: .completed,
            summary: TKEvidenceRunSummary(
                runID: runID,
                verdict: testRunEvidenceVerdict(status),
                frictionCount: status == .passed ? 0 : 1,
                stepCount: stepCount
            )
        )
    )
}

private func testRunTargetArtifact(from executor: TKTestRunPrimitiveExecutor) -> TKEvidenceTarget? {
    guard let live = executor as? TKLiveTestRunPrimitiveExecutor,
          let summary = live.targetSummary else {
        return nil
    }
    return TKEvidenceTarget(
        id: summary.id,
        connected: summary.connected,
        appName: summary.appName,
        bundleIdentifier: summary.bundleIdentifier,
        deviceDescription: summary.deviceDescription,
        osDescription: summary.osDescription,
        identityState: summary.identityState ?? (summary.connected ? "connected" : "disconnected"),
        targetConnectionState: summary.connected ? "connected" : "disconnected",
        hierarchyCacheState: summary.hierarchyCacheState
    )
}

private func testRunEvidenceVerdict(_ status: TKTestRunStatus) -> TKEvidenceRunVerdict {
    switch status {
    case .passed:
        return .success
    case .blocked:
        return .blocked
    case .failed, .running, .paused, .stopped:
        return .failure
    }
}

private func writeTestRunArtifact(_ data: Data, relativePath: String, evidenceDirectory: URL) throws {
    let url = evidenceDirectory.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private struct TKTestRunCoordinateContract: Codable, Equatable {
    let schemaVersion: Int
    let canonicalTapSpace: String
    let runtimeScreenshotSpace: TKTestRunRuntimeScreenshotSpace
    let runtimeGeometry: TKTestRunRuntimeGeometrySpace
    let vlmImageSpace: String
    let hostFramebufferSpace: String
}

private struct TKTestRunRuntimeScreenshotSpace: Codable, Equatable {
    let kind: String
    let width: Double
    let height: Double
    let scale: Double
}

private struct TKTestRunRuntimeGeometrySpace: Codable, Equatable {
    let width: Double
    let height: Double
    let scale: Double
    let orientation: String
}

private func writeTestRunCoordinateContract(
    screenshot: TKScreenshotResponse?,
    geometry: TKGeometryResponse?,
    evidenceDirectory: URL
) throws {
    let contract = TKTestRunCoordinateContract(
        schemaVersion: 1,
        canonicalTapSpace: "runtime-point",
        runtimeScreenshotSpace: TKTestRunRuntimeScreenshotSpace(
            kind: "runtime-point-sized-image",
            width: screenshot?.width ?? geometry?.bounds.width ?? 0,
            height: screenshot?.height ?? geometry?.bounds.height ?? 0,
            scale: 1
        ),
        runtimeGeometry: TKTestRunRuntimeGeometrySpace(
            width: geometry?.bounds.width ?? screenshot?.width ?? 0,
            height: geometry?.bounds.height ?? screenshot?.height ?? 0,
            scale: geometry?.scale ?? 1,
            orientation: geometry?.orientation ?? "unknown"
        ),
        vlmImageSpace: "not-supported-in-p0e",
        hostFramebufferSpace: "not-supported-in-p0e"
    )
    try writeTestRunArtifact(
        try prettyEncodedData(contract),
        relativePath: "coordinate-contract.json",
        evidenceDirectory: evidenceDirectory
    )
}

private func testRunVisibleTexts(from nodes: [TKAXNode]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for match in TKWaitVisibleTexts(from: nodes) {
        guard seen.insert(match.text).inserted else { continue }
        result.append(match.text)
        if result.count >= 50 { break }
    }
    return result
}

private func testRunSHA256(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}

private func testRunArtifactKey(_ artifact: TKEvidenceArtifact) -> String {
    "\(artifact.kind)\u{0}\(artifact.path)"
}

private func testRunVLMArtifacts(
    from grounding: TKVLMGroundResponse,
    evidenceDirectory: URL,
    target: String
) -> [TKEvidenceArtifact] {
    [
        TKEvidenceArtifact(
            kind: "vlm.overlay",
            path: testRunRelativePath(grounding.artifacts.overlay, evidenceDirectory: evidenceDirectory),
            contentType: "image/png",
            bytes: testRunFileSize(grounding.artifacts.overlay),
            target: target
        ),
        TKEvidenceArtifact(
            kind: "vlm.request",
            path: testRunRelativePath(grounding.artifacts.request, evidenceDirectory: evidenceDirectory),
            contentType: "application/json",
            bytes: testRunFileSize(grounding.artifacts.request),
            target: target
        ),
        TKEvidenceArtifact(
            kind: "vlm.response",
            path: testRunRelativePath(grounding.artifacts.response, evidenceDirectory: evidenceDirectory),
            contentType: "application/json",
            bytes: testRunFileSize(grounding.artifacts.response),
            target: target
        ),
    ]
}

private func testRunRelativePath(_ path: String, evidenceDirectory: URL) -> String {
    let evidencePath = evidenceDirectory.standardizedFileURL.path
    let artifactPath = URL(fileURLWithPath: path).standardizedFileURL.path
    guard artifactPath.hasPrefix(evidencePath + "/") else {
        return path
    }
    return String(artifactPath.dropFirst(evidencePath.count + 1))
}

private func testRunFileSize(_ path: String) -> Int? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
          let size = attributes[.size] as? NSNumber else {
        return nil
    }
    return size.intValue
}

private extension TKTestRunObservationOutcome {
    func withChanged(_ changed: Bool?) -> TKTestRunObservationOutcome {
        TKTestRunObservationOutcome(
            phase: phase,
            artifacts: artifacts,
            screenCandidate: screenCandidate,
            changed: changed,
            evidenceArtifacts: evidenceArtifacts
        )
    }
}

private func testRunTimestamp(_ date: Date = Date()) -> String {
    ISO8601DateFormatter().string(from: date)
}

private func testRunElapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1_000))
}

private func testRunEventRef(for artifactPath: String) -> String {
    "../\(artifactPath)"
}

private func formatTestRunNumber(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(value)
}
