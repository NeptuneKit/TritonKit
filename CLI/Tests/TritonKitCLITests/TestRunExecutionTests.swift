import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("P0D test runner execution")
struct TestRunExecutionTests {
    @Test("test-run screenshot metadata describes only the published normalized PNG")
    func publishedScreenshotMetadataDescribesNormalizedPNGOnly() throws {
        let runtimeScreenshot = TKScreenshotResponse(
            format: "jpeg",
            width: 40,
            height: 20,
            scale: 2,
            dataBase64: Data("legacy-jpeg-bytes".utf8).base64EncodedString(),
            dataRef: "legacy-runtime-jpeg"
        )
        let artifactData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])

        let metadata = testRunPublishedScreenshotMetadata(
            runtimeScreenshot: runtimeScreenshot,
            artifactData: artifactData,
            imagePath: "debug/step-001-after.png"
        )
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(metadata)) as? [String: Any])
        let encodedFormat = object["format"] as? String
        let encodedDataRef = object["dataRef"]
        let encodedDataBase64 = object["dataBase64"]
        let encodedImagePath = object["imagePath"] as? String

        #expect(metadata.format == "png")
        #expect(metadata.sourceFormat == "jpeg")
        #expect(metadata.dataRef == nil)
        #expect(metadata.imagePath == "debug/step-001-after.png")
        #expect(metadata.bytes == artifactData.count)
        #expect(encodedFormat == "png")
        #expect(encodedDataRef == nil)
        #expect(encodedDataBase64 == nil)
        #expect(encodedImagePath == "debug/step-001-after.png")
    }

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

        let report = try buildTritonTestReport(input: temp.evidence.path)
        #expect(report.ok)
        #expect(report.kind == "triton.test.report")
        #expect(report.summary.status == .passed)
        #expect(report.summary.stepCount == 4)
        #expect(report.summary.observationCount == 3)
        #expect(report.summary.screenshotCount == 3)
        #expect(report.failure == nil)
        #expect(report.steps.first { $0.stepIndex == 2 }?.observations.count == 2)
        #expect(report.steps.first { $0.stepIndex == 3 }?.assertion?.status == .passed)
        #expect(report.suggestedCommands.contains { $0.contains("evidence summary") })
    }

    @Test("runner executes tap text as deterministic action")
    func tapTextRunsAsDeterministicAction() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: Fixture tap text
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - tap:
                  text: Go Home
                  source: ax
                  match: exact
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
        #expect(executor.operations == ["launch", "tap", "assertVisible"])
        let events = try TKTestRunEventLogParser().parse(
            Data(contentsOf: temp.evidence.appendingPathComponent("run/events.jsonl"))
        )
        #expect(events.events.contains { $0.type == .commandExecuted && $0.stepIndex == 1 && $0.command?.contains("Go Home") == true })
        #expect(events.events.contains { $0.type == .observationCaptured && $0.stepIndex == 1 && $0.phase == "before" })
        #expect(events.events.contains { $0.type == .observationCaptured && $0.stepIndex == 1 && $0.phase == "after" })
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

        let report = try buildTritonTestReport(input: temp.evidence.path)
        #expect(report.ok)
        #expect(report.summary.status == .failed)
        #expect(report.summary.failureCount == 1)
        #expect(report.failure?.type == "assert_visible_failed")
        #expect(report.steps.first { $0.stepIndex == 1 }?.failure?.type == "assert_visible_failed")
        #expect(report.steps.first { $0.stepIndex == 1 }?.observations.count == 1)
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
              - drag:
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

    @Test("runner routes P6 deterministic primitives through the executor")
    func deterministicPrimitivesExecuteThroughRunner() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: P6 deterministic primitives
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - input:
                  text: hello
              - press:
                  button: home
              - swipe:
                  from:
                    x: 40
                    y: 500
                    coordinateSpace: runtime-point
                  to:
                    x: 40
                    y: 150
                    coordinateSpace: runtime-point
              - assertNotVisible:
                  text: Spinner
              - scrollUntilVisible:
                  text: Checkout
                  direction: down
                  maxScrolls: 2
              - stop: {}
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
        #expect(executor.operations == [
            "launch",
            "input",
            "press",
            "swipe",
            "assertNotVisible",
            "scrollUntilVisible",
            "stop",
        ])

        let events = try TKTestRunEventLogParser().parse(
            Data(contentsOf: temp.evidence.appendingPathComponent("run/events.jsonl"))
        )
        #expect(events.summary.status == .passed)
        #expect(events.events.contains { $0.type == .assertionResult && $0.stepIndex == 4 && $0.status == .passed })
        #expect(events.events.contains { $0.type == .assertionResult && $0.stepIndex == 5 && $0.status == .passed })
        #expect(events.summary.observationCount >= 7)
    }

    @Test("VLM-assisted tap writes grounding event when explicitly allowed")
    func vlmAssistedTapWritesGroundingEvent() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: VLM tap
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - tap:
                  target: Go Home button
                  grounding: vlm
                  provider: mock
              - assertVisible:
                  text: Fixture Home
            """
        )
        let executor = FakeTestRunExecutor()

        let response = try await runTritonTest(
            input: plan.path,
            evidenceDirectory: temp.evidence.path,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 19421,
            executor: executor,
            allowVLM: true
        )

        #expect(response.ok)
        let events = try TKTestRunEventLogParser().parse(
            Data(contentsOf: temp.evidence.appendingPathComponent("run/events.jsonl"))
        )
        #expect(events.events.contains { $0.type == .vlmGrounding && $0.stepIndex == 1 })
        let grounding = try #require(events.events.first { $0.type == .vlmGrounding }?.vlmGrounding)
        #expect(grounding.provider == "mock")
        #expect(grounding.target == "Go Home button")
        #expect(events.events.contains { $0.type == .artifactCreated && $0.artifactKind == "vlm.overlay" })
    }

    @Test("P14 mock AI assertions write reportable evidence without blocking by default")
    func mockAIAssertionsWriteReportableEvidence() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: P14 mock AI
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - assertWithAI:
                  prompt: Login screen has a primary action
                  provider: mock
              - extractTextWithAI: {}
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
        #expect(executor.operations == ["launch", "assertWithAI", "extractTextWithAI"])
        let report = try buildTritonTestReport(input: temp.evidence.path)
        #expect(report.summary.status == .passed)
        #expect(report.artifacts.contains { $0.kind == "ai.assertion" })
        #expect(report.artifacts.contains { $0.kind == "ai.extraction" })
        #expect(report.steps.first { $0.stepIndex == 1 }?.assertion?.status == .passed)
        #expect(report.steps.first { $0.stepIndex == 2 }?.observations.count == 1)
    }

    @Test("optional AI assertion failure records failure event and continues")
    func optionalAIAssertionFailureContinues() async throws {
        let temp = try TestRunTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: Optional AI fail
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - assertWithAI:
                  prompt: force fail
                  provider: mock
              - assertVisible:
                  text: Fixture Home
                  source: ax
                  match: exact
            """
        )
        let executor = FakeTestRunExecutor(failingAI: true)

        let response = try await runTritonTest(
            input: plan.path,
            evidenceDirectory: temp.evidence.path,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 19421,
            executor: executor
        )

        #expect(response.ok)
        let events = try TKTestRunEventLogParser().parse(Data(contentsOf: temp.evidence.appendingPathComponent("run/events.jsonl")))
        #expect(events.summary.status == .passed)
        #expect(events.summary.failureCount == 1)
        let report = try buildTritonTestReport(input: temp.evidence.path)
        #expect(report.summary.failureCount == 1)
        #expect(report.steps.first { $0.stepIndex == 1 }?.failure?.type == "ai_assertion_failed")
        #expect(report.steps.first { $0.stepIndex == 2 }?.status == .passed)
    }

    @Test("live executor rejects VLM tap before runtime work when allow flag is missing")
    func liveExecutorRejectsVLMTapWithoutAllowFlag() async throws {
        let step = TKTestPlanStep(
            index: 0,
            id: "step-000",
            kind: "action",
            type: "tap",
            optional: false,
            timeoutMs: nil,
            point: nil,
            selector: nil,
            target: "Go Home button",
            grounding: "vlm",
            provider: "mock"
        )
        let plan = TKTestNormalizedPlan(
            name: "vlm-disabled",
            app: TKTestPlanApp(bundleId: "com.neptunekit.tritonkit.testfixture"),
            device: TKTestPlanDevice(platform: "ios-simulator"),
            settings: TKTestPlanSettings(strict: true, timeoutMs: 5_000, retry: TKTestPlanRetry(count: 0, intervalMs: 250)),
            steps: [step]
        )
        let context = TKTestRunExecutionContext(
            evidenceDirectory: FileManager.default.temporaryDirectory,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 1,
            runID: "run-test"
        )

        let outcome = try await TKLiveTestRunPrimitiveExecutor().execute(step: step, plan: plan, context: context)

        #expect(outcome.status == .failed)
        #expect(outcome.failure?.type == "vlm_step_not_allowed")
        #expect(outcome.observations.isEmpty)
        #expect(outcome.vlmGroundings.isEmpty)
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
    private let failingAI: Bool
    private(set) var operations: [String] = []

    init(failingText: String? = nil, failingAI: Bool = false) {
        self.failingText = failingText
        self.failingAI = failingAI
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
        case "stop":
            return .passed(command: ["triton", "app", "terminate", "--bundle-id", plan.app.bundleId, "--json"])
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
            if let target = step.target {
                return .passed(
                    command: ["triton", "test", "run", "tap", "--target", target, "--grounding", "vlm", "--json"],
                    artifacts: [
                        TKEvidenceArtifact(kind: "vlm.overlay", path: "debug/\(step.id)-vlm/vlm-overlay.png", contentType: "image/png", bytes: 4),
                        TKEvidenceArtifact(kind: "vlm.request", path: "debug/\(step.id)-vlm/vlm-request.redacted.json", contentType: "application/json", bytes: 2),
                        TKEvidenceArtifact(kind: "vlm.response", path: "debug/\(step.id)-vlm/vlm-response.json", contentType: "application/json", bytes: 2),
                    ],
                    observations: [
                        Self.observation(step: step, phase: "before", text: "Fixture Login"),
                        Self.observation(step: step, phase: "after", text: "Fixture Home", changed: true),
                    ],
                    vlmGroundings: [TKTestRunVLMGroundingOutcome(response: Self.vlmGrounding(target: target))]
                )
            }
            if let selector = step.selector {
                return .passed(
                    command: ["triton", "tap", selector.text, "--target", context.target, "--json"],
                    observations: [
                        Self.observation(step: step, phase: "before", text: "Fixture Login"),
                        Self.observation(step: step, phase: "after", text: "Fixture Home", changed: true),
                    ]
                )
            }
            return .passed(
                command: ["triton", "tap", "--target", context.target, "--json"],
                observations: [
                    Self.observation(step: step, phase: "before", text: "Fixture Login"),
                    Self.observation(step: step, phase: "after", text: "Fixture Home", changed: true),
                ]
            )
        case "input":
            return .passed(
                command: ["triton", "type", step.text ?? "", "--json"],
                observations: [
                    Self.observation(step: step, phase: "before", text: "Fixture Login"),
                    Self.observation(step: step, phase: "after", text: step.text ?? "Fixture Login", changed: true),
                ]
            )
        case "press":
            return .passed(
                command: ["triton", "press", step.button ?? "", "--json"],
                observations: [
                    Self.observation(step: step, phase: "before", text: "Fixture Login"),
                    Self.observation(step: step, phase: "after", text: "Fixture Login", changed: false),
                ]
            )
        case "swipe":
            return .passed(
                command: ["triton", "swipe", "--json"],
                observations: [
                    Self.observation(step: step, phase: "before", text: "Fixture Login"),
                    Self.observation(step: step, phase: "after", text: "Fixture Login", changed: false),
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
        case "assertNotVisible":
            let selector = TKTestRunSelector(
                text: TKTestRunTextSelector(
                    value: step.selector?.text ?? "",
                    match: step.selector?.match ?? "exact",
                    source: step.selector?.source ?? "ax"
                )
            )
            return .passed(
                command: ["triton", "assert", "text-not-exists", step.selector?.text ?? "", "--json"],
                assertion: TKTestRunAssertionOutcome(status: .passed, selector: selector)
            )
        case "scrollUntilVisible":
            let selector = TKTestRunSelector(
                text: TKTestRunTextSelector(
                    value: step.selector?.text ?? "",
                    match: step.selector?.match ?? "exact",
                    source: step.selector?.source ?? "ax"
                )
            )
            return .passed(
                command: ["triton", "wait", step.selector?.text ?? "", "--json"],
                observations: [
                    Self.observation(step: step, phase: "before", text: "Fixture Login"),
                    Self.observation(step: step, phase: "after", text: step.selector?.text ?? "Checkout", changed: true),
                ],
                assertion: TKTestRunAssertionOutcome(status: .passed, selector: selector)
            )
        case "assertWithAI", "assertNoDefectsWithAI":
            let artifact = try Self.aiArtifact(step: step, context: context, kind: "ai.assertion")
            let selector = TKTestRunSelector(text: TKTestRunTextSelector(value: step.prompt ?? step.type, match: "exact", source: "ai"))
            if failingAI {
                return .failed(
                    command: ["triton", "test", "run", step.type, "--provider", step.provider ?? "mock", "--json"],
                    failure: TKTestRunFailure(type: "ai_assertion_failed", message: "mock AI assertion failed", selector: selector),
                    assertion: TKTestRunAssertionOutcome(status: .failed, selector: selector),
                    artifacts: [artifact],
                    observations: [Self.observation(step: step, phase: "after", text: "Fixture Login")]
                )
            }
            return .passed(
                command: ["triton", "test", "run", step.type, "--provider", step.provider ?? "mock", "--json"],
                artifacts: [artifact],
                observations: [Self.observation(step: step, phase: "after", text: "Fixture Login")],
                assertion: TKTestRunAssertionOutcome(status: .passed, selector: selector)
            )
        case "extractTextWithAI":
            let artifact = try Self.aiArtifact(step: step, context: context, kind: "ai.extraction")
            return .passed(
                command: ["triton", "test", "run", step.type, "--provider", step.provider ?? "mock", "--json"],
                artifacts: [artifact],
                observations: [Self.observation(step: step, phase: "after", text: "Fixture Login")]
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

    private static func vlmGrounding(target: String) -> TKVLMGroundResponse {
        TKVLMGroundResponse(
            provider: "mock",
            target: target,
            image: TKVLMGroundImage(path: "debug/step-001-before.png", width: 402, height: 874, sha256: "image-sha"),
            coordinateContract: TKVLMGroundCoordinateContractRef(path: "coordinate-contract.json", canonicalTapSpace: "runtime-point"),
            point: TKVLMGroundPoint(
                normalized: TKVLMNormalizedPoint(x: 500, y: 331.2356979405034),
                runtimePoint: TKVLMRuntimePoint(x: 201, y: 289.5),
                coordinateSpace: "runtime-point"
            ),
            transform: TKVLMCoordinateTransform(
                inputSpace: "normalized_0_1000",
                imageSpace: "image-pixel",
                outputSpace: "runtime-point",
                imageWidth: 402,
                imageHeight: 874,
                runtimeWidth: 402,
                runtimeHeight: 874,
                scale: 3,
                orientation: "portrait",
                source: "coordinate-contract.json"
            ),
            artifacts: TKVLMGroundArtifacts(
                overlay: "debug/step-001-vlm/vlm-overlay.png",
                request: "debug/step-001-vlm/vlm-request.redacted.json",
                response: "debug/step-001-vlm/vlm-response.json"
            )
        )
    }

    private static func aiArtifact(
        step: TKTestPlanStep,
        context: TKTestRunExecutionContext,
        kind: String
    ) throws -> TKEvidenceArtifact {
        let path = "debug/\(step.id)-ai-result.json"
        let file = context.evidenceDirectory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"kind\":\"triton.test.ai-result\"}".utf8).write(to: file)
        return TKEvidenceArtifact(kind: kind, path: path, contentType: "application/json", bytes: 33)
    }
}
