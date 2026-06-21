import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("P1-P2 app map test path graph")
struct AppMapPathGraphTests {
    @Test("map merge auto-projects evidence and builds a replayable smoke path")
    func mergeBuildsPathGraph() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writePassEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)

        let merge = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        #expect(merge.ok)
        #expect(merge.projectedWorkspace)
        #expect(merge.screenCount == 2)
        #expect(merge.transitionCount == 1)
        #expect(merge.pathCount == 1)
        #expect(merge.suiteCount == 1)
        #expect(merge.pathIDs == ["path-fixture-login-home"])
        #expect(FileManager.default.fileExists(atPath: fixture.evidence.appendingPathComponent("screens.json").path))
        #expect(FileManager.default.fileExists(atPath: fixture.evidence.appendingPathComponent("transitions.json").path))
        #expect(FileManager.default.fileExists(atPath: mapURL.appendingPathComponent("app-map.json").path))
        #expect(FileManager.default.fileExists(atPath: mapURL.appendingPathComponent("paths/path-fixture-login-home.json").path))
        #expect(FileManager.default.fileExists(atPath: mapURL.appendingPathComponent("suites/smoke.json").path))
        let index = try JSONDecoder().decode(
            TKAppMapDocument.self,
            from: Data(contentsOf: mapURL.appendingPathComponent("app-map.json"))
        )
        #expect(index.screenCount == 2)
        #expect(index.transitionCount == 1)
        #expect(index.pathCount == 1)
        #expect(index.suiteCount == 1)

        let inspect = try inspectTritonAppMap(mapPath: mapURL.path)
        #expect(inspect.screenCount == 2)
        #expect(inspect.transitionCount == 1)
        #expect(inspect.pathCount == 1)
        #expect(inspect.suiteCount == 1)
        #expect(inspect.health.passCount == 1)
        #expect(inspect.health.failCount == 0)

        let paths = try listTritonAppMapPaths(mapPath: mapURL.path)
        #expect(paths.paths.map(\.pathID) == ["path-fixture-login-home"])
        #expect(paths.paths.first?.replayable == true)
        #expect(paths.paths.first?.confirmed == true)
    }

    @Test("failure evidence merges screens without successful paths")
    func failureMergeDoesNotCreateSuccessTransitionPath() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writeFailureEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)

        let merge = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        #expect(merge.screenCount == 1)
        #expect(merge.transitionCount == 0)
        #expect(merge.pathCount == 0)

        let inspect = try inspectTritonAppMap(mapPath: mapURL.path)
        #expect(inspect.screenCount == 1)
        #expect(inspect.transitionCount == 0)
        #expect(inspect.pathCount == 0)
        #expect(inspect.health.failCount == 1)
    }

    @Test("export-flow writes a P0D-compatible tritontest yaml")
    func exportFlowWritesValidTritonTestYAML() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writePassEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)
        _ = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        let output = fixture.root.appendingPathComponent("fixture-login-home.tritontest.yaml")
        let export = try exportTritonAppMapFlow(
            mapPath: mapURL.path,
            pathID: "path-fixture-login-home",
            output: output.path
        )

        #expect(export.ok)
        #expect(export.pathID == "path-fixture-login-home")
        #expect(export.stepCount == 5)
        let yaml = try String(contentsOf: output, encoding: .utf8)
        let plan = try validateTritonTestContract(yaml: yaml, inputPath: output.path)
        #expect(plan.name == "fixture-login-home")
        #expect(plan.app.bundleId == "com.neptunekit.tritonkit.testfixture")
        #expect(plan.device.platform == "ios-simulator")
        #expect(plan.steps.map(\.type) == ["launch", "takeScreenshot", "assertVisible", "tap", "assertVisible"])
        #expect(plan.steps[2].selector?.text == "Fixture Login")
        #expect(plan.steps[3].point?.x == 120)
        #expect(plan.steps[3].point?.y == 320)
        #expect(plan.steps[4].selector?.text == "Fixture Home")
    }

    @Test("viewer exports static HTML from app map")
    func viewerExportsStaticHTMLFromAppMap() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writePassEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)
        _ = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        let output = fixture.root.appendingPathComponent("app-map.html")
        let viewer = try exportTritonAppMapViewer(mapPath: mapURL.path, output: output.path)

        #expect(viewer.ok)
        #expect(viewer.screenCount == 2)
        #expect(viewer.transitionCount == 1)
        #expect(viewer.pathCount == 1)
        #expect(FileManager.default.fileExists(atPath: output.path))
        let html = try String(contentsOf: output, encoding: .utf8)
        #expect(html.contains("Triton App Map"))
        #expect(html.contains("path-fixture-login-home"))
        #expect(html.contains("Fixture Login"))
        #expect(html.contains("Fixture Home"))
    }

    @Test("merge re-run evidence updates path health without duplicate paths")
    func mergeRerunEvidenceUpdatesPathHealth() throws {
        let first = try ScreenWorkspaceProjectionFixture(runID: "run-first-pass")
        try first.writePassEvidence()
        let mapURL = first.root.appendingPathComponent(".tritonmap", isDirectory: true)
        _ = try mergeTritonAppMap(
            evidencePath: first.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        let second = try ScreenWorkspaceProjectionFixture(runID: "run-second-pass")
        try second.writePassEvidence()
        let secondMerge = try mergeTritonAppMap(
            evidencePath: second.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        #expect(secondMerge.pathIDs == ["path-fixture-login-home"])
        let inspectAfterSecondPass = try inspectTritonAppMap(mapPath: mapURL.path)
        #expect(inspectAfterSecondPass.pathCount == 1)
        #expect(inspectAfterSecondPass.health.observedRuns == 2)
        #expect(inspectAfterSecondPass.health.passCount == 2)
        #expect(inspectAfterSecondPass.health.failCount == 0)

        let pathsAfterSecondPass = try listTritonAppMapPaths(mapPath: mapURL.path)
        let path = try #require(pathsAfterSecondPass.paths.first)
        #expect(pathsAfterSecondPass.pathCount == 1)
        #expect(path.pathID == "path-fixture-login-home")
        #expect(path.health.observedRuns == 2)
        #expect(path.health.passCount == 2)
        #expect(path.health.failCount == 0)

        let failure = try ScreenWorkspaceProjectionFixture(runID: "run-failure-no-transition")
        try failure.writeFailureEvidence()
        let failureMerge = try mergeTritonAppMap(
            evidencePath: failure.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        #expect(failureMerge.pathIDs.isEmpty)
        let inspectAfterFailure = try inspectTritonAppMap(mapPath: mapURL.path)
        #expect(inspectAfterFailure.pathCount == 1)
        #expect(inspectAfterFailure.health.observedRuns == 3)
        #expect(inspectAfterFailure.health.passCount == 2)
        #expect(inspectAfterFailure.health.failCount == 1)

        let pathsAfterFailure = try listTritonAppMapPaths(mapPath: mapURL.path)
        let unchangedPath = try #require(pathsAfterFailure.paths.first)
        #expect(pathsAfterFailure.pathCount == 1)
        #expect(unchangedPath.health.observedRuns == 2)
        #expect(unchangedPath.health.passCount == 2)
        #expect(unchangedPath.health.failCount == 0)
    }

    @Test("path confirmation and suite membership stay explicit")
    func pathConfirmationAndSuiteMembershipStayExplicit() throws {
        let fixture = try ScreenWorkspaceProjectionFixture(runID: "run-candidate-pass")
        try fixture.writePassEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)
        _ = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: false
        )

        let candidatePaths = try listTritonAppMapPaths(mapPath: mapURL.path)
        let candidate = try #require(candidatePaths.paths.first)
        #expect(candidate.pathID == "path-fixture-login-home")
        #expect(candidate.confirmed == false)

        let initialSuite = try inspectTritonAppMapSuite(mapPath: mapURL.path, suiteID: "smoke")
        #expect(initialSuite.suite.paths.isEmpty)

        do {
            _ = try addTritonAppMapSuitePath(mapPath: mapURL.path, suiteID: "smoke", pathID: candidate.pathID)
            Issue.record("unconfirmed path should not be suite-eligible")
        } catch TKAppMapError.unconfirmedPath(let pathID) {
            #expect(pathID == candidate.pathID)
        }

        let confirm = try setTritonAppMapPathConfirmation(mapPath: mapURL.path, pathID: candidate.pathID, confirmed: true)
        #expect(confirm.path.confirmed)
        let suiteAfterConfirmOnly = try inspectTritonAppMapSuite(mapPath: mapURL.path, suiteID: "smoke")
        #expect(suiteAfterConfirmOnly.suite.paths.isEmpty)

        let add = try addTritonAppMapSuitePath(mapPath: mapURL.path, suiteID: "smoke", pathID: candidate.pathID)
        #expect(add.suite.paths == [candidate.pathID])
        #expect(add.paths.map(\.pathID) == [candidate.pathID])

        let remove = try removeTritonAppMapSuitePath(mapPath: mapURL.path, suiteID: "smoke", pathID: candidate.pathID)
        #expect(remove.suite.paths.isEmpty)

        _ = try addTritonAppMapSuitePath(mapPath: mapURL.path, suiteID: "smoke", pathID: candidate.pathID)
        let unconfirm = try setTritonAppMapPathConfirmation(mapPath: mapURL.path, pathID: candidate.pathID, confirmed: false)
        #expect(unconfirm.path.confirmed == false)
        let finalSuite = try inspectTritonAppMapSuite(mapPath: mapURL.path, suiteID: "smoke")
        #expect(finalSuite.suite.paths.isEmpty)
    }

    @Test("suite runner exports runs projects and merges path evidence")
    func suiteRunnerExportsRunsProjectsAndMergesPathEvidence() async throws {
        let fixture = try ScreenWorkspaceProjectionFixture(runID: "run-suite-seed-pass")
        try fixture.writePassEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)
        _ = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        let evidenceRoot = fixture.root.appendingPathComponent("suite-run", isDirectory: true)
        let result = try await runTritonAppMapSuite(
            mapPath: mapURL.path,
            suiteID: "smoke",
            evidenceRoot: evidenceRoot.path,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 19421,
            executor: FakeSuiteRunExecutor()
        )

        #expect(result.ok)
        #expect(result.status == "passed")
        #expect(result.pathCount == 1)
        #expect(result.passedCount == 1)
        #expect(result.failedCount == 0)
        let pathResult = try #require(result.results.first)
        #expect(pathResult.pathID == "path-fixture-login-home")
        #expect(FileManager.default.fileExists(atPath: pathResult.flow))
        #expect(FileManager.default.fileExists(atPath: URL(fileURLWithPath: pathResult.evidenceDir).appendingPathComponent("run/events.jsonl").path))
        #expect(FileManager.default.fileExists(atPath: URL(fileURLWithPath: pathResult.evidenceDir).appendingPathComponent("screens.json").path))
        #expect(FileManager.default.fileExists(atPath: URL(fileURLWithPath: pathResult.evidenceDir).appendingPathComponent("transitions.json").path))

        let inspect = try inspectTritonAppMap(mapPath: mapURL.path)
        #expect(inspect.health.observedRuns == 2)
        #expect(inspect.health.passCount == 2)
        let paths = try listTritonAppMapPaths(mapPath: mapURL.path)
        let path = try #require(paths.paths.first)
        #expect(path.health.observedRuns == 2)
        #expect(path.health.passCount == 2)
    }

    @Test("VLM-assisted evidence marks merged path source")
    func vlmAssistedEvidenceMarksMergedPathSource() throws {
        let deterministic = try ScreenWorkspaceProjectionFixture(runID: "run-deterministic-pass")
        try deterministic.writePassEvidence()
        let mapURL = deterministic.root.appendingPathComponent(".tritonmap", isDirectory: true)
        _ = try mergeTritonAppMap(
            evidencePath: deterministic.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        let initialPaths = try listTritonAppMapPaths(mapPath: mapURL.path)
        let initialPath = try #require(initialPaths.paths.first)
        #expect(initialPath.source == "deterministic")
        #expect(initialPath.health.observedRuns == 1)
        #expect(initialPath.health.passCount == 1)

        let vlm = try ScreenWorkspaceProjectionFixture(runID: "run-vlm-assisted-pass")
        try vlm.writeVLMPassEvidence()
        let merge = try mergeTritonAppMap(
            evidencePath: vlm.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        #expect(merge.pathIDs == ["path-fixture-login-home"])
        let paths = try listTritonAppMapPaths(mapPath: mapURL.path)
        let path = try #require(paths.paths.first)
        #expect(paths.pathCount == 1)
        #expect(path.pathID == "path-fixture-login-home")
        #expect(path.source == "vlm-assisted")
        #expect(path.health.observedRuns == 2)
        #expect(path.health.passCount == 2)
    }

    @Test("map inspect operations expose screens transitions path suite and health gaps")
    func mapInspectOperationsExposeGraphAssets() throws {
        let fixture = try ScreenWorkspaceProjectionFixture(runID: "run-inspect-pass")
        try fixture.writePassEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)
        _ = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        let screens = try listTritonAppMapScreens(mapPath: mapURL.path)
        #expect(screens.screenCount == 2)
        #expect(screens.screens.map(\.primaryText) == ["Fixture Home", "Fixture Login"])

        let transitions = try listTritonAppMapTransitions(mapPath: mapURL.path)
        #expect(transitions.transitionCount == 1)
        #expect(transitions.transitions.first?.trigger.type == "tap")

        let path = try showTritonAppMapPath(mapPath: mapURL.path, pathID: "path-fixture-login-home")
        #expect(path.path.pathID == "path-fixture-login-home")
        #expect(path.screens.count == 2)
        #expect(path.transitions.count == 1)

        let suite = try inspectTritonAppMapSuite(mapPath: mapURL.path, suiteID: "smoke")
        #expect(suite.suite.suiteID == "smoke")
        #expect(suite.suite.paths == ["path-fixture-login-home"])
        #expect(suite.paths.map(\.pathID) == ["path-fixture-login-home"])

        let health = try inspectTritonAppMapHealth(mapPath: mapURL.path)
        #expect(health.health.observedRuns == 1)
        #expect(health.health.passCount == 1)
        #expect(health.failingPathIDs.isEmpty)
        #expect(health.uncoveredScreenIDs.isEmpty)
        #expect(health.uncoveredTransitionIDs.isEmpty)
    }
}

private final class FakeSuiteRunExecutor: TKTestRunPrimitiveExecutor {
    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        switch step.type {
        case "launch":
            return .passed(command: ["triton", "list", "--json"])
        case "takeScreenshot":
            return .passed(
                command: ["triton", "screenshot", "--json"],
                observations: [observation(runID: context.runID, stepIndex: step.index, phase: "after", text: "Fixture Login")]
            )
        case "assertVisible":
            let text = step.selector?.text ?? ""
            return .passed(
                command: ["triton", "assert", "text-exists", text, "--json"],
                assertion: TKTestRunAssertionOutcome(
                    status: .passed,
                    selector: TKTestRunSelector(text: TKTestRunTextSelector(value: text, match: "exact", source: "ax"))
                )
            )
        case "tap":
            return .passed(
                command: ["triton", "tap", "--json"],
                observations: [
                    observation(runID: context.runID, stepIndex: step.index, phase: "before", text: "Fixture Login"),
                    observation(runID: context.runID, stepIndex: step.index, phase: "after", text: "Fixture Home", changed: true),
                ]
            )
        default:
            throw TKTestRunPrimitiveError(type: "unsupported_step", message: "Unexpected suite step: \(step.type)")
        }
    }

    private func observation(
        runID: String,
        stepIndex: Int,
        phase: String,
        text: String,
        changed: Bool? = nil
    ) -> TKTestRunObservationOutcome {
        let slug = text.replacingOccurrences(of: " ", with: "-").lowercased()
        return TKTestRunObservationOutcome(
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
            changed: changed
        )
    }
}
