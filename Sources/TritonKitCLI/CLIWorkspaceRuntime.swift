import Foundation
import TritonKitShared

struct TKWorkspaceRunRequest {
    let runsDirectory: String
    let runID: String?
    let target: String
    let app: String
    let goal: String
    let actionPolicy: String
    let dryModelFixture: Bool

    init(
        runsDirectory: String,
        runID: String?,
        target: String,
        app: String,
        goal: String,
        actionPolicy: String,
        dryModelFixture: Bool = false
    ) {
        self.runsDirectory = runsDirectory
        self.runID = runID
        self.target = target
        self.app = app
        self.goal = goal
        self.actionPolicy = actionPolicy
        self.dryModelFixture = dryModelFixture
    }
}

struct TKWorkspaceRunResponse: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let runID: String
    let goal: String
    let status: String
    let target: TKWorkspaceRunTarget
    let app: String
    let ai: TKWorkspaceRunAI
    let paths: TKWorkspaceRunPaths
    let nextActions: [TKWorkspaceNextAction]

    init(
        schemaVersion: Int = 1,
        kind: String = "triton.workspace.run",
        runID: String,
        goal: String,
        status: String,
        target: TKWorkspaceRunTarget,
        app: String,
        ai: TKWorkspaceRunAI,
        paths: TKWorkspaceRunPaths,
        nextActions: [TKWorkspaceNextAction]
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.runID = runID
        self.goal = goal
        self.status = status
        self.target = target
        self.app = app
        self.ai = ai
        self.paths = paths
        self.nextActions = nextActions
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case goal
        case status
        case target
        case app
        case ai
        case paths
        case nextActions
    }
}

struct TKWorkspaceRunTarget: Codable, Equatable {
    let id: String
    let platform: String
    let scope: String
    let capabilities: [String]
}

struct TKWorkspaceRunAI: Codable, Equatable {
    let llmEnabled: Bool
    let vlmEnabled: Bool
    let actionPolicy: String
    let providersReady: Bool
    let providerStatus: String
}

struct TKWorkspaceRunPaths: Codable, Equatable {
    let runDir: String
    let events: String
    let report: String
}

struct TKWorkspaceNextAction: Codable, Equatable {
    let code: String
    let message: String
}

struct TKWorkspaceInspectResponse: Codable, Equatable {
    let kind: String
    let run: TKWorkspaceRunResponse
    let summary: TKTestRunEventSummary
    let latestBootstrap: TKTestRunEvent?
}

struct TKWorkspaceExportFlowResponse: Codable, Equatable {
    let kind: String
    let runID: String
    let output: String
    let stepCount: Int

    enum CodingKeys: String, CodingKey {
        case kind
        case runID = "runId"
        case output
        case stepCount
    }
}

func runWorkspaceRun(_ request: TKWorkspaceRunRequest) throws -> TKWorkspaceRunResponse {
    let runID = try normalizedWorkspaceRunID(request.runID ?? defaultWorkspaceRunID())
    let runDir = workspaceRunDirectory(runID: runID, runsDirectory: request.runsDirectory)
    let paths = TKWorkspaceRunPaths(
        runDir: runDir.path,
        events: runDir.appendingPathComponent("events.jsonl").path,
        report: runDir.appendingPathComponent("report.json").path
    )
    let target = TKWorkspaceRunTarget(
        id: request.target,
        platform: "unknown",
        scope: "current",
        capabilities: ["screenshot", "hierarchy", "input"]
    )
    let nextActions = [
        TKWorkspaceNextAction(
            code: "configure_ai_provider",
            message: "LLM/VLM are enabled by default; configure a local or approved provider before autonomous actions."
        ),
    ]
    let response = TKWorkspaceRunResponse(
        runID: runID,
        goal: request.goal,
        status: "stopped",
        target: target,
        app: request.app,
        ai: TKWorkspaceRunAI(
            llmEnabled: true,
            vlmEnabled: true,
            actionPolicy: request.actionPolicy,
            providersReady: false,
            providerStatus: "missing"
        ),
        paths: paths,
        nextActions: nextActions
    )

    try createWorkspaceRunDirectories(runDir)
    try writeWorkspaceRunConfig(response, to: runDir.appendingPathComponent("config.yaml"))
    try writeWorkspaceRunArtifacts(response, runDir: runDir)
    if request.dryModelFixture {
        try writeWorkspaceDryDecisionArtifacts(runDir: runDir)
    }
    try writeWorkspaceRun(response, to: runDir.appendingPathComponent("run.json"))
    var events = workspaceSkeletonEvents(runID: runID, runDir: runDir)
    if request.dryModelFixture {
        events.insert(contentsOf: workspaceDryDecisionEvents(runID: runID), at: events.index(before: events.endIndex))
    }
    try writeWorkspaceEvents(events, to: runDir.appendingPathComponent("events.jsonl"))
    try writeWorkspaceRun(response, to: runDir.appendingPathComponent("report.json"))
    return response
}

func inspectWorkspaceRun(runID: String, runsDirectory: String) throws -> TKWorkspaceInspectResponse {
    let runID = try normalizedWorkspaceRunID(runID)
    let runDir = workspaceRunDirectory(runID: runID, runsDirectory: runsDirectory)
    let run = try JSONDecoder().decode(
        TKWorkspaceRunResponse.self,
        from: Data(contentsOf: runDir.appendingPathComponent("run.json"))
    )
    let parsed = try TKTestRunEventLogParser().parse(
        Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
    )
    return TKWorkspaceInspectResponse(
        kind: "triton.workspace.inspect",
        run: run,
        summary: parsed.summary,
        latestBootstrap: parsed.events.last { $0.type == .flowBootstrapChecked }
    )
}

func stopWorkspaceRun(runID: String, runsDirectory: String) throws -> TKWorkspaceInspectResponse {
    let runID = try normalizedWorkspaceRunID(runID)
    let runDir = workspaceRunDirectory(runID: runID, runsDirectory: runsDirectory)
    let eventsURL = runDir.appendingPathComponent("events.jsonl")
    let parsed = try TKTestRunEventLogParser().parse(Data(contentsOf: eventsURL))
    if parsed.events.last?.type != .runStopped {
        try appendWorkspaceEvent(.init(
            type: .runStopped,
            runID: runID,
            timestamp: workspaceTimestamp(),
            status: .stopped,
            durationMs: 0
        ), to: eventsURL)
    }
    let runURL = runDir.appendingPathComponent("run.json")
    let run = try JSONDecoder().decode(TKWorkspaceRunResponse.self, from: Data(contentsOf: runURL))
    try writeWorkspaceRun(TKWorkspaceRunResponse(
        runID: run.runID,
        goal: run.goal,
        status: "stopped",
        target: run.target,
        app: run.app,
        ai: run.ai,
        paths: run.paths,
        nextActions: run.nextActions
    ), to: runURL)
    return try inspectWorkspaceRun(runID: runID, runsDirectory: runsDirectory)
}

func exportWorkspaceFlow(runID: String, runsDirectory: String, output: String) throws -> TKWorkspaceExportFlowResponse {
    let inspected = try inspectWorkspaceRun(runID: runID, runsDirectory: runsDirectory)
    let yaml = """
    schemaVersion: 1
    kind: triton.workspace.flow
    runId: \(inspected.run.runID)
    goal: "\(yamlEscaped(inspected.run.goal))"
    app: "\(yamlEscaped(inspected.run.app))"
    steps:
      - action: launchApp
        app: "\(yamlEscaped(inspected.run.app))"
        evidenceRef: events.jsonl#app.ready
      - action: observe
        evidenceRef: events.jsonl#observation.captured
      - action: bootstrapCheck
        evidenceRef: events.jsonl#flow.bootstrap.checked

    """
    let outputURL = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try yaml.write(to: outputURL, atomically: true, encoding: .utf8)
    return TKWorkspaceExportFlowResponse(
        kind: "triton.workspace.export-flow",
        runID: inspected.run.runID,
        output: outputURL.path,
        stepCount: 3
    )
}

private func createWorkspaceRunDirectories(_ runDir: URL) throws {
    for relativePath in [
        "",
        "evidence/screenshots",
        "evidence/hierarchy",
        "evidence/model",
        "evidence/actions",
        "atlas",
    ] {
        try FileManager.default.createDirectory(
            at: relativePath.isEmpty ? runDir : runDir.appendingPathComponent(relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

private func writeWorkspaceRunArtifacts(_ run: TKWorkspaceRunResponse, runDir: URL) throws {
    try writeWorkspaceJSONArtifact([
        "target": run.target.id,
        "platform": run.target.platform,
        "scope": run.target.scope,
        "capabilities": run.target.capabilities,
    ], to: runDir.appendingPathComponent("evidence/model/target.json"))
    try writeWorkspaceJSONArtifact([
        "llmEnabled": run.ai.llmEnabled,
        "vlmEnabled": run.ai.vlmEnabled,
        "providersReady": run.ai.providersReady,
        "providerStatus": run.ai.providerStatus,
    ], to: runDir.appendingPathComponent("evidence/model/provider-check.json"))
    try writeWorkspaceJSONArtifact([
        "app": run.app,
        "ready": false,
        "mode": "dry-skeleton",
    ], to: runDir.appendingPathComponent("evidence/actions/app-ready.json"))
    try "workspace dry screenshot placeholder\n".write(
        to: runDir.appendingPathComponent("evidence/screenshots/0000.txt"),
        atomically: true,
        encoding: .utf8
    )
    try writeWorkspaceJSONArtifact(["nodes": []], to: runDir.appendingPathComponent("evidence/hierarchy/0000.json"))
    try writeWorkspaceJSONArtifact(["ax": []], to: runDir.appendingPathComponent("evidence/hierarchy/0000-ax.json"))
    try writeWorkspaceJSONArtifact([
        "state": "provider_missing",
        "ready": false,
        "evidenceId": "ev_0000",
        "proposal": "stop",
    ], to: runDir.appendingPathComponent("evidence/model/bootstrap-000.json"))
    try writeWorkspaceJSONArtifact([
        "screens": [],
        "states": [],
        "transitions": [],
        "coverage": ["status": "empty"],
    ], to: runDir.appendingPathComponent("atlas/atlas.json"))
}

private func writeWorkspaceDryDecisionArtifacts(runDir: URL) throws {
    let command = ["triton", "act", "tap", "Continue", "--json"]
    try writeWorkspaceJSONArtifact([
        "summary": "Dry fixture selected a single tap candidate.",
        "command": command,
        "confidence": 0.5,
        "usedVLM": true,
    ], to: runDir.appendingPathComponent("evidence/model/decision-000.json"))
    try writeWorkspaceJSONArtifact([
        "allowed": true,
        "reason": "dry fixture command is low-risk and single-step",
        "command": command,
    ], to: runDir.appendingPathComponent("evidence/model/policy-000.json"))
    try writeWorkspaceJSONArtifact([
        "ok": true,
        "mode": "dry-fixture",
        "command": command,
    ], to: runDir.appendingPathComponent("evidence/actions/action-000.json"))
    try writeWorkspaceJSONArtifact([
        "status": "failed",
        "reason": "dry fixture simulates expected screen missing",
    ], to: runDir.appendingPathComponent("evidence/model/verify-000.json"))
    try writeWorkspaceJSONArtifact([
        "failureCode": "expected_screen_missing",
        "kind": "selector_drift",
        "proposal": "stop",
    ], to: runDir.appendingPathComponent("evidence/model/recovery-000.json"))
    try """
    {"deltaId":"atlas_delta_0000","kind":"transition","confidence":0.5}
    """.write(to: runDir.appendingPathComponent("atlas/deltas.jsonl"), atomically: true, encoding: .utf8)
    try """
    schemaVersion: 1
    kind: triton.workspace.flow
    steps:
      - action: tap
        evidenceRef: events.jsonl#action.executed

    """.write(to: runDir.appendingPathComponent("flow.tritonflow.yaml"), atomically: true, encoding: .utf8)
}

private func workspaceSkeletonEvents(runID: String, runDir: URL) -> [TKTestRunEvent] {
    let now = workspaceTimestamp()
    return [
        .runStarted(runID: runID, timestamp: now),
        .init(type: .targetResolved, runID: runID, timestamp: now, ref: "evidence/model/target.json"),
        .init(type: .providerChecked, runID: runID, timestamp: now, ref: "evidence/model/provider-check.json", phase: "missing"),
        .init(type: .appReady, runID: runID, timestamp: now, ref: "evidence/actions/app-ready.json", phase: "dry-skeleton"),
        .observationCaptured(
            runID: runID,
            stepIndex: 0,
            phase: "initial",
            artifacts: TKTestRunObservationArtifacts(
                screenshot: "evidence/screenshots/0000.txt",
                ax: "evidence/hierarchy/0000-ax.json",
                hierarchy: "evidence/hierarchy/0000.json"
            ),
            screenCandidate: TKTestRunScreenCandidate(
                screenshotSha256: "placeholder-screenshot",
                axTextHash: "placeholder-ax",
                hierarchySha256: "placeholder-hierarchy",
                visibleTexts: []
            ),
            changed: false,
            timestamp: now
        ),
        .init(
            type: .flowBootstrapChecked,
            runID: runID,
            timestamp: now,
            stepIndex: 0,
            ref: "evidence/model/bootstrap-000.json",
            phase: "provider_missing"
        ),
        .init(type: .runStopped, runID: runID, timestamp: now, status: .stopped, durationMs: 0),
    ]
}

private func workspaceDryDecisionEvents(runID: String) -> [TKTestRunEvent] {
    let now = workspaceTimestamp()
    let command = ["triton", "act", "tap", "Continue", "--json"]
    return [
        .init(type: .modelDecided, runID: runID, timestamp: now, stepIndex: 1, command: command, ref: "evidence/model/decision-000.json"),
        .init(type: .policyChecked, runID: runID, timestamp: now, stepIndex: 1, command: command, status: .passed, ref: "evidence/model/policy-000.json"),
        .init(type: .actionExecuted, runID: runID, timestamp: now, stepIndex: 1, command: command, status: .passed, exitCode: 0),
        .init(type: .verifyChecked, runID: runID, timestamp: now, stepIndex: 1, status: .failed, ref: "evidence/model/verify-000.json"),
        .init(
            type: .flowRecoveryDetected,
            runID: runID,
            timestamp: now,
            stepIndex: 1,
            failure: TKTestRunFailure(
                type: "expected_screen_missing",
                message: "Dry fixture simulates selector drift after action.",
                artifactRefs: ["evidence/model/verify-000.json"]
            ),
            phase: "selector_drift"
        ),
        .init(type: .flowRecoveryProposed, runID: runID, timestamp: now, stepIndex: 1, command: ["stop"], ref: "evidence/model/recovery-000.json"),
        .init(
            type: .flowRecoveryRejected,
            runID: runID,
            timestamp: now,
            stepIndex: 1,
            failure: TKTestRunFailure(
                type: "dry_fixture_stop",
                message: "Dry fixture does not execute recovery actions.",
                artifactRefs: ["evidence/model/recovery-000.json"]
            )
        ),
        .init(type: .atlasUpdated, runID: runID, timestamp: now, stepIndex: 1, ref: "atlas/deltas.jsonl"),
        .init(type: .flowUpdated, runID: runID, timestamp: now, ref: "flow.tritonflow.yaml"),
    ]
}

private func writeWorkspaceRun(_ run: TKWorkspaceRunResponse, to url: URL) throws {
    try encodeCompactJSON(run).write(to: url, atomically: true, encoding: .utf8)
}

private func writeWorkspaceEvents(_ events: [TKTestRunEvent], to url: URL) throws {
    let text = try events.map(encodeCompactJSON).joined(separator: "\n") + "\n"
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private func appendWorkspaceEvent(_ event: TKTestRunEvent, to url: URL) throws {
    let line = try encodeCompactJSON(event) + "\n"
    let handle = try FileHandle(forWritingTo: url)
    defer { handle.closeFile() }
    handle.seekToEndOfFile()
    handle.write(Data(line.utf8))
}

private func writeWorkspaceRunConfig(_ run: TKWorkspaceRunResponse, to url: URL) throws {
    let yaml = """
    llm:
      enabled: true
    vlm:
      enabled: true
    runner:
      actionPolicy: \(run.ai.actionPolicy)
    provider:
      status: \(run.ai.providerStatus)

    """
    try yaml.write(to: url, atomically: true, encoding: .utf8)
}

private func writeWorkspaceJSONArtifact(_ value: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
}

private func workspaceRunDirectory(runID: String, runsDirectory: String) -> URL {
    URL(fileURLWithPath: runsDirectory, isDirectory: true)
        .appendingPathComponent(runID, isDirectory: true)
}

private func normalizedWorkspaceRunID(_ raw: String) throws -> String {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty,
          value.range(of: #"^[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil,
          !value.contains("..")
    else {
        throw RuntimeError("Invalid workspace run id: \(raw)")
    }
    return value
}

private func defaultWorkspaceRunID() -> String {
    "run_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
}

private func workspaceTimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

private func yamlEscaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}
