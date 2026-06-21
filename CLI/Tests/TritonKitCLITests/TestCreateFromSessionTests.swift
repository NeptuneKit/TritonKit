import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("P16 session-to-test projection")
struct TestCreateFromSessionTests {
    @Test("create from session writes a valid editable tritontest yaml")
    func createFromSessionWritesValidEditableYAML() async throws {
        let temp = try SessionToTestTempFiles()
        let plan = try temp.writePlan(
            """
            version: 1
            name: fixture-session
            app:
              bundleId: com.neptunekit.tritonkit.testfixture
            device:
              platform: ios-simulator
            steps:
              - launch: {}
              - takeScreenshot: {}
              - assertVisible:
                  text: Fixture Login
                  source: ax
                  match: exact
              - tap:
                  point:
                    x: 201
                    y: 289.5
                    coordinateSpace: runtime-point
              - assertVisible:
                  text: Fixture Home
                  source: ax
                  match: exact
            """
        )

        _ = try await runTritonTest(
            input: plan.path,
            evidenceDirectory: temp.evidence.path,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 19421,
            executor: SessionToTestExecutor()
        )

        let output = temp.root.appendingPathComponent("generated-fixture-session.tritontest.yaml")
        let response = try createTritonTestFromSession(
            input: temp.evidence.path,
            output: output.path
        )

        #expect(response.ok)
        #expect(response.kind == "triton.test.create-result")
        #expect(response.source == "normalized-plan.json")
        #expect(response.stepCount == 5)
        #expect(response.validation.normalizedPlan.steps.map(\.type) == ["launch", "takeScreenshot", "assertVisible", "tap", "assertVisible"])
        #expect(FileManager.default.fileExists(atPath: output.path))

        let yaml = try String(contentsOf: output, encoding: .utf8)
        #expect(yaml.contains("name: \"fixture-session\""))
        #expect(yaml.contains("bundleId: \"com.neptunekit.tritonkit.testfixture\""))
        #expect(yaml.contains("takeScreenshot: {}"))
        #expect(yaml.contains("text: \"Fixture Login\""))
        #expect(yaml.contains("x: 201"))
        #expect(yaml.contains("y: 289.5"))
        #expect(yaml.contains("coordinateSpace: \"runtime-point\""))

        let validated = try validateTritonTestContract(yaml: yaml, inputPath: output.path)
        #expect(validated.name == "fixture-session")
        #expect(validated.steps.count == 5)
    }

    @Test("test command schema exposes create from session contract")
    func schemaExposesCreateFromSessionContract() throws {
        let schema = try #require(commandSchemas().first { $0.name == "test" })
        let create = try #require(schema.subcommands.first { $0.name == "create" })

        #expect(schema.runtimeScope == "offline for validate/normalize/report/create; runtime target required for run")
        #expect(schema.providedCapabilities.contains("test-create-from-session"))
        #expect(schema.outputContracts.contains { $0.selector == "test.create" })
        #expect(create.requiredOptions == ["--from-session", "--output"])
        #expect(create.outputSelectors == ["test.create", "test.validation"])
    }
}

private struct SessionToTestTempFiles {
    let root: URL
    let evidence: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tritonkit-session-to-test-\(UUID().uuidString)", isDirectory: true)
        evidence = root.appendingPathComponent("run.tritonevidence", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func writePlan(_ yaml: String) throws -> URL {
        let url = root.appendingPathComponent("plan.tritontest.yaml")
        try yaml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private final class SessionToTestExecutor: TKTestRunPrimitiveExecutor {
    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        switch step.type {
        case "launch":
            return .passed(command: ["triton", "list", "--bundle-id", plan.app.bundleId, "--json"])
        case "takeScreenshot":
            let path = "screenshots/step-\(Self.indexString(step.index)).png"
            let file = context.evidenceDirectory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: file)
            return .passed(
                command: ["triton", "screenshot", "--target", context.target, "--output", path],
                artifacts: [
                    TKEvidenceArtifact(kind: "screenshot", path: path, contentType: "image/png", bytes: 4),
                ],
                observations: [
                    Self.observation(step: step, phase: "after", text: "Fixture Login"),
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
            return .passed(
                command: ["triton", "assert", "text-exists", step.selector?.text ?? "", "--json"],
                assertion: TKTestRunAssertionOutcome(status: .passed, selector: selector)
            )
        default:
            return .passed(command: ["triton", step.type, "--json"])
        }
    }

    private static func observation(step: TKTestPlanStep, phase: String, text: String, changed: Bool? = nil) -> TKTestRunObservationOutcome {
        TKTestRunObservationOutcome(
            phase: phase,
            artifacts: TKTestRunObservationArtifacts(
                screenshot: "../debug/step-\(indexString(step.index))-\(phase).png",
                ax: "../debug/step-\(indexString(step.index))-\(phase)-ax.json",
                hierarchy: "../debug/step-\(indexString(step.index))-\(phase)-hierarchy.json"
            ),
            screenCandidate: TKTestRunScreenCandidate(
                screenshotSha256: "screenshot-\(text)",
                axTextHash: "ax-\(text)",
                hierarchySha256: "hierarchy-\(text)",
                visibleTexts: [text]
            ),
            changed: changed
        )
    }

    private static func indexString(_ index: Int) -> String {
        String(format: "%03d", index)
    }
}
