import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("P1 screen workspace evidence projection")
struct ScreenWorkspaceProjectionTests {
    @Test("project-screens groups observations into run-local screens and tap transitions")
    func projectScreensBuildsScreensAndTransitions() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writePassEvidence()

        let response = try projectScreenWorkspace(evidencePath: fixture.evidence.path)

        #expect(response.ok)
        #expect(response.screenCount == 2)
        #expect(response.transitionCount == 1)
        #expect(response.warningCount == 0)
        #expect(FileManager.default.fileExists(atPath: fixture.evidence.appendingPathComponent("screens.json").path))
        #expect(FileManager.default.fileExists(atPath: fixture.evidence.appendingPathComponent("transitions.json").path))
        #expect(!FileManager.default.fileExists(atPath: fixture.evidence.appendingPathComponent(".tritonmap").path))

        let screens = try JSONDecoder().decode(
            TKScreenWorkspaceScreensDocument.self,
            from: Data(contentsOf: fixture.evidence.appendingPathComponent("screens.json"))
        )
        #expect(screens.schemaVersion == 1)
        #expect(screens.kind == "triton.screen-workspace.screens")
        #expect(screens.source.eventsRef == "run/events.jsonl")
        #expect(screens.screens.map(\.screenID) == ["screen-000", "screen-001"])
        #expect(screens.screens[0].primaryText == "Fixture Login")
        #expect(screens.screens[0].observations.count == 2)
        #expect(screens.screens[0].observations.map(\.phase) == ["after", "before"])
        #expect(screens.screens[0].observations.allSatisfy { !$0.artifacts.screenshot.hasPrefix("../") })
        #expect(screens.screens[1].primaryText == "Fixture Home")

        let transitions = try JSONDecoder().decode(
            TKScreenWorkspaceTransitionsDocument.self,
            from: Data(contentsOf: fixture.evidence.appendingPathComponent("transitions.json"))
        )
        #expect(transitions.schemaVersion == 1)
        #expect(transitions.kind == "triton.screen-workspace.transitions")
        #expect(transitions.source.eventsRef == "run/events.jsonl")
        #expect(transitions.source.screensRef == "screens.json")
        #expect(transitions.transitions.count == 1)
        let transition = try #require(transitions.transitions.first)
        #expect(transition.transitionID == "transition-000")
        #expect(transition.fromScreenID == "screen-000")
        #expect(transition.toScreenID == "screen-001")
        #expect(transition.stepIndex == 2)
        #expect(transition.trigger.type == "tap")
        #expect(transition.trigger.coordinateSpace == "runtime-point")
        #expect(transition.trigger.point?.x == 120)
        #expect(transition.trigger.point?.y == 320)
        #expect(transition.trigger.replayable)

        let manifest = try readEvidenceManifest(from: fixture.evidence.path)
        #expect(manifest.screenWorkspace?.screensPath == "screens.json")
        #expect(manifest.screenWorkspace?.transitionsPath == "transitions.json")
        #expect(manifest.screenWorkspace?.screenCount == 2)
        #expect(manifest.screenWorkspace?.transitionCount == 1)
        #expect(manifest.artifacts.contains { $0.kind == "screen-workspace.screens" && $0.path == "screens.json" })
        #expect(manifest.artifacts.contains { $0.kind == "screen-workspace.transitions" && $0.path == "transitions.json" })

        let summary = try summarizeEvidenceBundle(input: fixture.evidence.path)
        #expect(summary.screenWorkspace?.screenCount == 2)
        #expect(summary.screenWorkspace?.transitionCount == 1)
    }

    @Test("project-screens can project a failing evidence bundle without transitions")
    func projectScreensBuildsFailureScreenWithoutTransition() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writeFailureEvidence()

        let response = try projectScreenWorkspace(evidencePath: fixture.evidence.path)

        #expect(response.screenCount == 1)
        #expect(response.transitionCount == 0)

        let screens = try JSONDecoder().decode(
            TKScreenWorkspaceScreensDocument.self,
            from: Data(contentsOf: fixture.evidence.appendingPathComponent("screens.json"))
        )
        #expect(screens.screens.count == 1)
        #expect(screens.screens[0].primaryText == "Fixture Login")

        let transitions = try JSONDecoder().decode(
            TKScreenWorkspaceTransitionsDocument.self,
            from: Data(contentsOf: fixture.evidence.appendingPathComponent("transitions.json"))
        )
        #expect(transitions.transitions.isEmpty)

        let summary = try summarizeEvidenceBundle(input: fixture.evidence.path)
        #expect(summary.screenWorkspace?.screenCount == 1)
        #expect(summary.screenWorkspace?.transitionCount == 0)
    }

    @Test("project-screens rejects run logs without observation.captured events")
    func projectScreensRequiresObservationEvents() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writeNoObservationEvidence()

        do {
            _ = try projectScreenWorkspace(evidencePath: fixture.evidence.path)
            Issue.record("projection should reject evidence without observations")
        } catch let error as TKScreenWorkspaceProjectionError {
            #expect(error.detail.code == "missing_observation_events")
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.evidence.appendingPathComponent("screens.json").path))
        #expect(!FileManager.default.fileExists(atPath: fixture.evidence.appendingPathComponent("transitions.json").path))
    }
}

struct ScreenWorkspaceProjectionFixture {
    let root: URL
    let evidence: URL
    let runID: String

    init(runID: String = "run-screen-workspace") throws {
        self.runID = runID
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tritonkit-screen-workspace-\(UUID().uuidString)", isDirectory: true)
        evidence = root.appendingPathComponent("fixture.tritonevidence", isDirectory: true)
        try FileManager.default.createDirectory(at: evidence.appendingPathComponent("run", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: evidence.appendingPathComponent("debug", isDirectory: true), withIntermediateDirectories: true)
    }

    func writePassEvidence() throws {
        try writeManifest(status: .completed, verdict: .success, eventCount: 10, observationCount: 3)
        try writeNormalizedPlan(includeTap: true)
        try writeEvents([
            .runStarted(runID: runID, timestamp: "2026-06-20T00:00:00Z"),
            .stepStarted(runID: runID, stepIndex: 1, stepID: "step-001", stepType: "takeScreenshot", timestamp: "2026-06-20T00:00:01Z"),
            observation(stepIndex: 1, phase: "after", text: "Fixture Login"),
            .stepFinished(runID: runID, stepIndex: 1, stepID: "step-001", status: .passed, durationMs: 10, timestamp: "2026-06-20T00:00:02Z"),
            .stepStarted(runID: runID, stepIndex: 2, stepID: "step-002", stepType: "tap", timestamp: "2026-06-20T00:00:03Z"),
            .commandExecuted(runID: runID, stepIndex: 2, command: ["triton", "tap", "--target", "fixture", "--x", "120", "--y", "320", "--json"], status: .passed, exitCode: 0, durationMs: 5, timestamp: "2026-06-20T00:00:04Z"),
            observation(stepIndex: 2, phase: "before", text: "Fixture Login"),
            observation(stepIndex: 2, phase: "after", text: "Fixture Home", changed: true),
            .stepFinished(runID: runID, stepIndex: 2, stepID: "step-002", status: .passed, durationMs: 20, timestamp: "2026-06-20T00:00:05Z"),
            .runFinished(runID: runID, status: .passed, durationMs: 30, timestamp: "2026-06-20T00:00:06Z"),
        ])
    }

    func writeFailureEvidence() throws {
        try writeManifest(status: .completed, verdict: .failure, eventCount: 5, observationCount: 1)
        try writeNormalizedPlan(includeTap: false)
        try writeEvents([
            .runStarted(runID: runID, timestamp: "2026-06-20T00:00:00Z"),
            .stepStarted(runID: runID, stepIndex: 1, stepID: "step-001", stepType: "assertVisible", timestamp: "2026-06-20T00:00:01Z"),
            observation(stepIndex: 1, phase: "after", text: "Fixture Login"),
            .failureRecorded(
                runID: runID,
                stepIndex: 1,
                failure: TKTestRunFailure(type: "assert_visible_failed", message: "AX exact text not visible: Definitely Not Existing"),
                timestamp: "2026-06-20T00:00:02Z"
            ),
            .runFinished(runID: runID, status: .failed, durationMs: 12, timestamp: "2026-06-20T00:00:03Z"),
        ])
    }

    func writeNoObservationEvidence() throws {
        try writeManifest(status: .completed, verdict: .success, eventCount: 2, observationCount: 0)
        try writeEvents([
            .runStarted(runID: runID, timestamp: "2026-06-20T00:00:00Z"),
            .runFinished(runID: runID, status: .passed, durationMs: 1, timestamp: "2026-06-20T00:00:01Z"),
        ])
    }

    private func writeManifest(
        status: TKEvidenceRunParseStatus,
        verdict: TKEvidenceRunVerdict,
        eventCount: Int,
        observationCount: Int
    ) throws {
        let manifest = TKEvidenceManifest(
            ok: true,
            createdAt: "2026-06-20T00:00:00Z",
            output: evidence.path,
            artifacts: [
                TKEvidenceArtifact(kind: "test.normalized-plan", path: "normalized-plan.json", contentType: "application/json"),
                TKEvidenceArtifact(kind: "test.run.events", path: "run/events.jsonl", contentType: "application/jsonl"),
            ],
            cli: TKEvidenceCLI(version: "test"),
            run: TKEvidenceRunManifest(
                eventsPath: "run/events.jsonl",
                metaPath: "run/run.json",
                eventCount: eventCount,
                observationCount: observationCount,
                status: status,
                summary: TKEvidenceRunSummary(verdict: verdict)
            )
        )
        try prettyEncodedData(manifest).write(to: evidence.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private func writeNormalizedPlan(includeTap: Bool) throws {
        let steps: [TKTestPlanStep] = includeTap ? [
            TKTestPlanStep(index: 1, id: "step-001", kind: "observation", type: "takeScreenshot", optional: false, timeoutMs: nil, point: nil, selector: nil),
            TKTestPlanStep(index: 2, id: "step-002", kind: "action", type: "tap", optional: false, timeoutMs: nil, point: TKTestPlanPoint(x: 120, y: 320, coordinateSpace: "runtime-point"), selector: nil),
        ] : [
            TKTestPlanStep(index: 1, id: "step-001", kind: "assertion", type: "assertVisible", optional: false, timeoutMs: nil, point: nil, selector: TKTestPlanSelector(text: "Definitely Not Existing", match: "exact", source: "ax")),
        ]
        let plan = TKTestNormalizedPlan(
            name: "Screen workspace fixture",
            app: TKTestPlanApp(bundleId: "com.neptunekit.tritonkit.testfixture"),
            device: TKTestPlanDevice(platform: "ios-simulator"),
            settings: TKTestPlanSettings(strict: true, timeoutMs: 10_000, retry: TKTestPlanRetry(count: 0, intervalMs: 0)),
            steps: steps
        )
        try prettyEncodedData(plan).write(to: evidence.appendingPathComponent("normalized-plan.json"), options: .atomic)
    }

    private func writeEvents(_ events: [TKTestRunEvent]) throws {
        let data = try events
            .map { try String(decoding: prettyEncodedData($0), as: UTF8.self).replacingOccurrences(of: "\n", with: "") }
            .joined(separator: "\n")
            .appending("\n")
            .data(using: .utf8) ?? Data()
        try data.write(to: evidence.appendingPathComponent("run/events.jsonl"), options: .atomic)
    }

    private func observation(
        stepIndex: Int,
        phase: String,
        text: String,
        changed: Bool? = nil
    ) -> TKTestRunEvent {
        let slug = text.replacingOccurrences(of: " ", with: "-").lowercased()
        return .observationCaptured(
            runID: runID,
            stepIndex: stepIndex,
            phase: phase,
            artifacts: TKTestRunObservationArtifacts(
                screenshot: "../debug/step-\(String(format: "%03d", stepIndex))-\(phase).png",
                ax: "../debug/step-\(String(format: "%03d", stepIndex))-\(phase)-ax.json",
                hierarchy: "../debug/step-\(String(format: "%03d", stepIndex))-\(phase)-hierarchy.json"
            ),
            screenCandidate: TKTestRunScreenCandidate(
                screenshotSha256: "screenshot-\(slug)",
                axTextHash: "ax-\(slug)",
                hierarchySha256: "hierarchy-\(slug)",
                visibleTexts: ["fixture.runtime.status", text, text == "Fixture Login" ? "Go Home" : "Back to Login"]
            ),
            changed: changed,
            timestamp: "2026-06-20T00:00:04Z"
        )
    }
}
