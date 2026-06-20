import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("P0D test runner execution")
struct TestRunExecutionTests {
    @Test("run writes normalized plan, run events, and manifest for a passing minimal plan")
    func passingMinimalPlanWritesEvidence() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: Fixture pass
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - takeScreenshot: {}
              - tap:
                  point:
                    x: 120
                    y: 320
                    coordinateSpace: runtime-point
              - assertVisible:
                  text: Fixture Home
                  source: ax
                  match: exact
            """
        )
        let executor = FakeTestRunExecutor()

        let response = try await runTritonTest(
            input: plan.path,
            evidenceDirectory: temp.evidence.path,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 19421,
            executor: executor
        )

        #expect(response.ok)
        #expect(response.summary.status == .passed)
        #expect(executor.operations == ["launch", "takeScreenshot", "tap", "assertVisible"])
        #expect(FileManager.default.fileExists(atPath: temp.evidence.appendingPathComponent("normalized-plan.json").path))
        #expect(FileManager.default.fileExists(atPath: temp.evidence.appendingPathComponent("run/run.json").path))
        #expect(FileManager.default.fileExists(atPath: temp.evidence.appendingPathComponent("run/events.jsonl").path))

        let events = try TKTestRunEventLogParser().parse(
            Data(contentsOf: temp.evidence.appendingPathComponent("run/events.jsonl"))
        )
        #expect(events.summary.status == .passed)
        #expect(events.events.contains { $0.type == .runStarted })
        #expect(events.events.contains { $0.type == .artifactCreated && $0.artifactKind == "screenshot" })
        #expect(events.events.contains { $0.type == .assertionResult && $0.status == .passed })
        #expect(events.summary.observationCount == 3)
        let observations = events.events.filter { $0.type == .observationCaptured }
        #expect(observations.count == 3)
        #expect(observations.contains { $0.stepIndex == 1 && $0.phase == "after" })
        #expect(observations.contains { $0.stepIndex == 2 && $0.phase == "before" })
        #expect(observations.contains { $0.stepIndex == 2 && $0.phase == "after" })
        #expect(observations.allSatisfy { $0.artifacts?.screenshot != nil })
        #expect(observations.allSatisfy { $0.artifacts?.ax != nil })
        #expect(observations.allSatisfy { $0.artifacts?.hierarchy != nil })
        #expect(observations.allSatisfy { $0.screenCandidate?.screenshotSha256.isEmpty == false })
        #expect(observations.allSatisfy { $0.screenCandidate?.axTextHash.isEmpty == false })
        #expect(observations.allSatisfy { $0.screenCandidate?.hierarchySha256.isEmpty == false })
        #expect(observations.contains { $0.changed == true })
        #expect(FileManager.default.fileExists(atPath: temp.evidence.appendingPathComponent("coordinate-contract.json").path))

        let manifest = try JSONDecoder().decode(
            TKEvidenceManifest.self,
            from: Data(contentsOf: temp.evidence.appendingPathComponent("manifest.json"))
        )
        #expect(manifest.run?.eventsPath == "run/events.jsonl")
        #expect(manifest.run?.metaPath == "run/run.json")
        #expect(manifest.run?.status == .completed)
        #expect(manifest.run?.summary?.verdict == .success)
        #expect(manifest.run?.eventCount == events.summary.eventCount)
        #expect(manifest.run?.observationCount == events.summary.observationCount)
        #expect(manifest.artifacts.contains { $0.kind == "coordinate.contract" && $0.path == "coordinate-contract.json" })

        let evidenceSummary = try summarizeEvidenceBundle(input: temp.evidence.path)
        #expect(evidenceSummary.run?.observationCount == 3)
    }

    @Test("run records machine-readable failure evidence without truncating the run log")
    func assertionFailureWritesFailureEvidence() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: Fixture failure
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - assertVisible:
                  text: Definitely Not Existing
                  source: ax
                  match: exact
            """
        )
        let executor = FakeTestRunExecutor(failingText: "Definitely Not Existing")

        let response = try await runTritonTest(
            input: plan.path,
            evidenceDirectory: temp.evidence.path,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 19421,
            executor: executor
        )

        #expect(!response.ok)
        #expect(response.summary.status == .failed)
        #expect(response.failure?.type == "assert_visible_failed")
        #expect(response.failure?.message.contains("Definitely Not Existing") == true)

        let events = try TKTestRunEventLogParser().parse(
            Data(contentsOf: temp.evidence.appendingPathComponent("run/events.jsonl"))
        )
        #expect(events.summary.status == .failed)
        #expect(events.summary.failureCount == 1)
        #expect(events.summary.observationCount == 1)
        #expect(events.events.contains { $0.type == .failureRecorded && $0.failure?.type == "assert_visible_failed" })
        #expect(events.events.contains { $0.type == .observationCaptured && $0.stepIndex == 1 && $0.screenCandidate?.visibleTexts.isEmpty == false })
        #expect(events.events.contains { $0.type == .runFinished && $0.status == .failed })
        #expect(FileManager.default.fileExists(atPath: temp.evidence.appendingPathComponent("debug/step-001-ax.json").path))
    }

    @Test("unsupported steps remain validation_error and never invoke the primitive executor")
    func unsupportedStepDoesNotTouchDeviceOperations() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: Unsupported step
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - swipe:
                  from:
                    x: 10
                    y: 10
                  to:
                    x: 20
                    y: 20
            """
        )
        let executor = FakeTestRunExecutor()

        do {
            _ = try await runTritonTest(
                input: plan.path,
                evidenceDirectory: temp.evidence.path,
                target: "fixture-target",
                host: "127.0.0.1",
                port: 19421,
                executor: executor
            )
            Issue.record("unsupported step should fail during validation")
        } catch let failure as TKTestValidationFailure {
            #expect(failure.detail.code == "unsupported_step")
        }

        #expect(executor.operations.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: temp.evidence.path))
    }
}

private struct TestRunTempFiles {
    let root: URL
    let evidence: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tritonkit-test-run-\(UUID().uuidString)", isDirectory: true)
        evidence = root.appendingPathComponent("run.tritonevidence", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func writePlan(_ yaml: String) throws -> URL {
        let url = root.appendingPathComponent("plan.tritontest.yaml")
        try yaml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private final class FakeTestRunExecutor: TKTestRunPrimitiveExecutor {
    private let failingText: String?
    private(set) var operations: [String] = []

    init(failingText: String? = nil) {
        self.failingText = failingText
    }

    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        operations.append(step.type)
        switch step.type {
        case "launch":
            return .passed(command: ["triton", "list", "--bundle-id", plan.app.bundleId, "--json"])
        case "takeScreenshot":
            let path = "screenshots/step-\(Self.indexString(step.index)).png"
            let axPath = "debug/step-\(Self.indexString(step.index))-after-ax.json"
            let hierarchyPath = "debug/step-\(Self.indexString(step.index))-after-hierarchy.json"
            let file = context.evidenceDirectory.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: context.evidenceDirectory.appendingPathComponent("debug", isDirectory: true),
                withIntermediateDirectories: true
            )
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: file)
            try Data("[{\"label\":\"Fixture Login\"}]".utf8).write(
                to: context.evidenceDirectory.appendingPathComponent(axPath)
            )
            try Data("{\"root\":\"login\"}".utf8).write(
                to: context.evidenceDirectory.appendingPathComponent(hierarchyPath)
            )
            return .passed(
                command: ["triton", "screenshot", "--target", context.target, "--output", path],
                artifacts: [
                    TKEvidenceArtifact(kind: "screenshot", path: path, contentType: "image/png", bytes: 4),
                    TKEvidenceArtifact(kind: "accessibility", path: axPath, contentType: "application/json", bytes: 27),
                    TKEvidenceArtifact(kind: "hierarchy", path: hierarchyPath, contentType: "application/json", bytes: 16),
                ],
                observations: [
                    TKTestRunObservationOutcome(
                        phase: "after",
                        artifacts: TKTestRunObservationArtifacts(
                            screenshot: "../\(path)",
                            ax: "../\(axPath)",
                            hierarchy: "../\(hierarchyPath)"
                        ),
                        screenCandidate: TKTestRunScreenCandidate(
                            screenshotSha256: "screenshot-login",
                            axTextHash: "ax-login",
                            hierarchySha256: "hierarchy-login",
                            visibleTexts: ["Fixture Login", "Go Home"]
                        )
                    )
                ]
            )
        case "tap":
            return .passed(
                command: ["triton", "tap", "--target", context.target, "--json"],
                observations: [
                    Self.observation(step: step, phase: "before", text: "Fixture Login"),
                    Self.observation(step: step, phase: "after", text: "Fixture Home", changed: true),
                ]
            )
        case "assertVisible":
            let selector = TKTestRunSelector(
                text: TKTestRunTextSelector(
                    value: step.selector?.text ?? "",
                    match: step.selector?.match ?? "exact",
                    source: step.selector?.source ?? "ax"
                )
            )
            if step.selector?.text == failingText {
                let debugPath = "debug/step-\(Self.indexString(step.index))-ax.json"
                let file = context.evidenceDirectory.appendingPathComponent(debugPath)
                try FileManager.default.createDirectory(
                    at: file.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try Data("[]".utf8).write(to: file)
                return .failed(
                    command: ["triton", "assert", "text-exists", step.selector?.text ?? "", "--json"],
                    failure: TKTestRunFailure(
                        type: "assert_visible_failed",
                        message: "AX exact text not visible: \(step.selector?.text ?? "")",
                        selector: selector,
                        artifactRefs: ["../\(debugPath)"]
                    ),
                    assertion: TKTestRunAssertionOutcome(status: .failed, selector: selector),
                    artifacts: [
                        TKEvidenceArtifact(kind: "accessibility", path: debugPath, contentType: "application/json", bytes: 2)
                    ],
                    observations: [
                        Self.observation(step: step, phase: "after", text: "Fixture Home")
                    ]
                )
            }
            return .passed(
                command: ["triton", "assert", "text-exists", step.selector?.text ?? "", "--json"],
                assertion: TKTestRunAssertionOutcome(status: .passed, selector: selector)
            )
        default:
            throw TKTestRunPrimitiveError(type: "unsupported_step", message: "Unexpected executor step: \(step.type)")
        }
    }

    private static func indexString(_ index: Int) -> String {
        String(format: "%03d", index)
    }

    private static func observation(
        step: TKTestPlanStep,
        phase: String,
        text: String,
        changed: Bool? = nil
    ) -> TKTestRunObservationOutcome {
        let index = indexString(step.index)
        return TKTestRunObservationOutcome(
            phase: phase,
            artifacts: TKTestRunObservationArtifacts(
                screenshot: "../debug/step-\(index)-\(phase).png",
                ax: "../debug/step-\(index)-\(phase)-ax.json",
                hierarchy: "../debug/step-\(index)-\(phase)-hierarchy.json"
            ),
            screenCandidate: TKTestRunScreenCandidate(
                screenshotSha256: "screenshot-\(phase)-\(text)",
                axTextHash: "ax-\(phase)-\(text)",
                hierarchySha256: "hierarchy-\(phase)-\(text)",
                visibleTexts: [text]
            ),
            changed: changed
        )
    }
}
