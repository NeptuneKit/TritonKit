import Foundation
import Testing
@testable import TritonKitCLI

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
