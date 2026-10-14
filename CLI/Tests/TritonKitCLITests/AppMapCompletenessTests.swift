import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("SP-196 AppMap bounded discovery and execution completeness", .serialized)
struct AppMapCompletenessTests {
    @Test func listingPagesAreStableAndPreserveEvidence() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writePassEvidence()
        let map = fixture.root.appendingPathComponent("fixture.tritonmap")
        _ = try mergeTritonAppMap(evidencePath: fixture.evidence.path, into: map.path, confirm: true)
        let full = try listTritonAppMapScreens(mapPath: map.path)
        let first = try listTritonAppMapScreens(mapPath: map.path, offset: 0, limit: 1)
        let last = try listTritonAppMapScreens(mapPath: map.path, offset: 1, limit: 1)
        #expect(first.screenCount == 2)
        #expect(first.totalCount == 2 && first.returnedCount == 1 && first.truncated)
        #expect(first.nextOffset == 1)
        #expect(last.nextOffset == nil && last.truncated)
        #expect(first.screens + last.screens == full.screens)
        #expect(first.screens.first?.stateVariants == full.screens.first?.stateVariants)
        #expect(try listTritonAppMapScreens(mapPath: map.path, offset: Int.max, limit: 1).screens.isEmpty)
        let paths = try listTritonAppMapPaths(mapPath: map.path, limit: 1)
        let transitions = try listTritonAppMapTransitions(mapPath: map.path, limit: 1)
        #expect(paths.pathCount == paths.totalCount && paths.returnedCount == paths.paths.count)
        #expect(transitions.transitionCount == transitions.totalCount)
        #expect(paths.paths.first?.suggestedCommands.isEmpty == false)
    }


    @Test func defaultPageAdvertisesRemainingItemsWithoutDroppingEvidence() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writePassEvidence()
        let map = fixture.root.appendingPathComponent("fixture.tritonmap")
        _ = try mergeTritonAppMap(evidencePath: fixture.evidence.path, into: map.path, confirm: true)
        let directory = map.appendingPathComponent("screens")
        let originals = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: originals[0])) as? [String: Any])
        let variants = object["stateVariants"] as? [[String: Any]]
        for index in 0..<105 {
            object["screenId"] = String(format: "stable-%03d", index)
            try JSONSerialization.data(withJSONObject: object).write(to: directory.appendingPathComponent("scrambled-\(104-index).json"))
        }
        for original in originals { try FileManager.default.removeItem(at: original) }
        let page = try listTritonAppMapScreens(mapPath: map.path)
        #expect(page.totalCount == 105 && page.screenCount == 105 && page.returnedCount == 100)
        #expect(page.nextOffset == 100 && page.truncated)
        #expect(page.screens.first?.screenID == "stable-000")
        #expect(page.screens.last?.screenID == "stable-099")
        #expect(page.screens.first?.stateVariants.first?.evidenceRefs.isEmpty == false)
        let tail = try listTritonAppMapScreens(mapPath: map.path, offset: 100, limit: 1000)
        #expect(tail.returnedCount == 5 && tail.truncated && tail.nextOffset == nil)
        #expect(variants?.count == tail.screens.first?.stateVariants.count)
    }

    @Test func listingInvalidPageFailsBeforeMapDiscovery() throws {
        for (offset, limit) in [(-1, 100), (0, 0), (0, 1001)] {
            do {
                _ = try listTritonAppMapPaths(mapPath: "/missing-fixture-map", offset: offset, limit: limit)
                Issue.record("Invalid page accepted")
            } catch { #expect(appMapFailureCode(error) == "invalid_app_map_page") }
        }
        let paths = try AppMap.Paths.parse(["fixture.tritonmap", "--offset", "2", "--limit", "7"])
        #expect(paths.offset == 2 && paths.limit == 7)
        #expect(try AppMap.Screens.parse(["fixture.tritonmap"]).limit == 100)
    }

    @Test func emptySuiteRejectsBeforeEvidenceOrExecutor() async throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writePassEvidence()
        let map = fixture.root.appendingPathComponent("fixture.tritonmap")
        _ = try mergeTritonAppMap(evidencePath: fixture.evidence.path, into: map.path, confirm: false)
        let evidence = fixture.root.appendingPathComponent("suite-evidence")
        let executor = CompletenessExecutor(status: .passed)
        do {
            _ = try await runTritonAppMapSuite(mapPath: map.path, suiteID: "smoke", evidenceRoot: evidence.path, target: "fixture", host: "127.0.0.1", port: 19421, executor: executor)
            Issue.record("Empty suite passed")
        } catch { #expect(appMapFailureCode(error) == "empty_app_map_suite") }
        #expect(!FileManager.default.fileExists(atPath: evidence.path))
        #expect(executor.calls == 0)
    }

    @Test(arguments: [TKTestRunStatus.failed, .blocked])
    func allOptionalFailuresNeverPass(status: TKTestRunStatus) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executor = CompletenessExecutor(status: status)
        let response = try await runTritonTest(input: "fixture", evidenceDirectory: directory.path, target: "fixture", host: "127.0.0.1", port: 19421, executor: executor, normalizedPlanOverride: plan(steps: [step(optional: true)]))
        #expect(!response.ok && response.run.status == .blocked)
        #expect(response.failure?.type == "no_successful_steps")
        #expect(response.summary.status == .blocked)
        #expect(executor.calls == 1)
    }

    @Test func emptyOverrideNeverPasses() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executor = CompletenessExecutor(status: .passed)
        let response = try await runTritonTest(input: "fixture", evidenceDirectory: directory.path, target: "fixture", host: "127.0.0.1", port: 19421, executor: executor, normalizedPlanOverride: plan(steps: []))
        #expect(!response.ok && response.failure?.type == "no_successful_steps")
        #expect(response.summary.status == .blocked && response.summary.stepCount == 0)
        let events = try TKTestRunEventLogParser().parse(Data(contentsOf: directory.appendingPathComponent("run/events.jsonl")))
        #expect(events.events.last?.failure?.type == "no_successful_steps")
        let report = try buildTritonTestReport(input: directory.path)
        #expect(report.summary.status == .blocked)
        #expect(report.failure?.type == "no_successful_steps")
        #expect(executor.calls == 0)
    }

    private func plan(steps: [TKTestPlanStep]) -> TKTestNormalizedPlan {
        .init(name: "fixture", app: .init(bundleId: "fixture"), device: .init(platform: "ios-simulator"), settings: .init(strict: true, timeoutMs: 100, retry: .init(count: 0, intervalMs: 0)), steps: steps)
    }
    private func step(optional: Bool) -> TKTestPlanStep {
        .init(index: 0, id: "fixture-step", kind: "action", type: "launch", optional: optional, timeoutMs: nil, point: nil, selector: nil)
    }
}

private final class CompletenessExecutor: TKTestRunPrimitiveExecutor {
    let status: TKTestRunStatus
    var calls = 0
    init(status: TKTestRunStatus) { self.status = status }
    func execute(step: TKTestPlanStep, plan: TKTestNormalizedPlan, context: TKTestRunExecutionContext) async throws -> TKTestRunPrimitiveOutcome {
        calls += 1
        return .init(command: ["fixture"], status: status, exitCode: status == .passed ? 0 : 1, durationMs: 0, artifacts: [], observations: [], vlmGroundings: [], assertion: nil, failure: status == .passed ? nil : .init(type: "fixture_failure", message: "Fixture primitive did not pass"))
    }
}
