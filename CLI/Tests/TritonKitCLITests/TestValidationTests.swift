import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite
struct TestValidationTests {
    @Test("valid tritontest YAML normalizes into a stable offline plan")
    func validYAMLNormalizesIntoStableOfflinePlan() throws {
        let plan = try validateTritonTestContract(
            yaml: validContractYAML(),
            inputPath: "/tmp/login-flow.tritontest.yaml"
        )

        #expect(plan.schemaVersion == 1)
        #expect(plan.kind == "triton.test.normalized-plan")
        #expect(plan.name == "login-flow")
        #expect(plan.app.bundleId == "com.example.LoginFixture")
        #expect(plan.device.platform == "ios")
        #expect(plan.settings.strict == true)
        #expect(plan.settings.timeoutMs == 5_000)
        #expect(plan.settings.retry.count == 0)
        #expect(plan.settings.retry.intervalMs == 250)
        #expect(plan.steps.map(\.id) == ["step-000", "step-001", "step-002", "step-003"])
        #expect(plan.steps.map(\.kind) == ["action", "observation", "action", "assertion"])
        #expect(plan.steps.map(\.type) == ["launch", "takeScreenshot", "tap", "assertVisible"])
        #expect(plan.steps[2].point?.coordinateSpace == "runtime-point")
        #expect(plan.steps[2].point?.x == 191.5)
        #expect(plan.steps[2].point?.y == 329.25)
        #expect(plan.steps[3].selector?.text == "Home")
        #expect(plan.steps[3].selector?.match == "exact")
        #expect(plan.steps[3].selector?.source == "ax")
    }

    @Test("valid tritontest YAML command emits ok response with normalized plan")
    func validYAMLCommandEmitsOKResponseWithNormalizedPlan() throws {
        let url = try writeTemporaryContract(name: "valid", contents: validContractYAML())
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let result = try runTriton(["test", "validate", url.path, "--json"])
        let response = try JSONDecoder().decode(TKTestValidationResponse.self, from: Data(result.stdout.utf8))

        #expect(result.exitCode == 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(response.ok == true)
        #expect(response.normalizedPlan.name == "login-flow")
        #expect(response.normalizedPlan.steps.count == 4)
    }

    @Test("unsupported tritontest step emits machine readable validation error")
    func unsupportedStepEmitsMachineReadableValidationError() throws {
        let url = try writeTemporaryContract(name: "drag", contents: invalidDragYAML())
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let result = try runTriton(["test", "validate", url.path, "--json"])
        let nonEmptyStreams = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let output = try #require(nonEmptyStreams.first)
        let response = try JSONDecoder().decode(TKTestValidationFailureResponse.self, from: Data(output.utf8))

        #expect(result.exitCode != 0)
        #expect(nonEmptyStreams.count == 1)
        #expect(response.ok == false)
        #expect(response.error.type == "validation_error")
        #expect(response.error.code == "unsupported_step")
        #expect(response.error.path == "$.steps[0].drag")
        #expect(response.error.allowed == tritonTestSupportedSteps)
    }

    @Test("P6 deterministic steps normalize into explicit primitive fields")
    func deterministicStepsNormalizeIntoPrimitiveFields() throws {
        let plan = try validateTritonTestContract(
            yaml: deterministicContractYAML(),
            inputPath: "/tmp/p6.tritontest.yaml"
        )

        #expect(plan.steps.map(\.type) == [
            "launch",
            "input",
            "press",
            "swipe",
            "assertNotVisible",
            "scrollUntilVisible",
            "stop",
        ])
        #expect(plan.steps[1].text == "hello")
        #expect(plan.steps[2].button == "home")
        #expect(plan.steps[3].point?.x == 20)
        #expect(plan.steps[3].endPoint?.y == 120)
        #expect(plan.steps[4].selector?.text == "Spinner")
        #expect(plan.steps[5].selector?.text == "Checkout")
        #expect(plan.steps[5].direction == "down")
        #expect(plan.steps[5].maxScrolls == 3)
    }

    @Test("VLM-assisted tap target normalizes only with explicit grounding metadata")
    func vlmAssistedTapTargetNormalizes() throws {
        let plan = try validateTritonTestContract(
            yaml: """
            version: 1
            name: vlm-tap
            app:
              bundleId: com.example.LoginFixture
            device:
              platform: ios
            steps:
              - tap:
                  target: Go Home button
                  grounding: vlm
                  provider: mock
            """,
            inputPath: "/tmp/vlm-tap.tritontest.yaml"
        )

        #expect(plan.steps[0].type == "tap")
        #expect(plan.steps[0].point == nil)
        #expect(plan.steps[0].target == "Go Home button")
        #expect(plan.steps[0].grounding == "vlm")
        #expect(plan.steps[0].provider == "mock")
    }

    @Test("MLX VLM tap target preserves local model fields")
    func mlxVLMTapTargetPreservesLocalModelFields() throws {
        let plan = try validateTritonTestContract(
            yaml: """
            version: 1
            name: mlx-tap
            app:
              bundleId: com.example.LoginFixture
            device:
              platform: ios
            steps:
              - tap:
                  target: Go Home button
                  grounding: vlm
                  provider: mlx-swift-lm
                  modelPath: ~/.cache/triton/mlx-models/gui-grounding-vlm
                  maxTokens: 32
                  temperature: 0
                  seed: 7
                  promptTemplate: gui-grounding-v1
                  allowModelDownload: false
            """,
            inputPath: "/tmp/mlx-tap.tritontest.yaml"
        )

        let step = try #require(plan.steps.first)
        #expect(step.provider == "mlx-swift-lm")
        #expect(step.modelPath == "~/.cache/triton/mlx-models/gui-grounding-vlm")
        #expect(step.maxTokens == 32)
        #expect(step.temperature == 0)
        #expect(step.seed == 7)
        #expect(step.promptTemplate == "gui-grounding-v1")
        #expect(step.allowModelDownload == false)
    }

    @Test("tap text normalizes as exact AX selector")
    func tapTextNormalizesAsExactAXSelector() throws {
        let plan = try validateTritonTestContract(
            yaml: """
            version: 1
            name: tap-text
            app:
              bundleId: com.example.LoginFixture
            device:
              platform: ios
            steps:
              - tap:
                  text: Go Home
                  source: ax
                  match: exact
            """,
            inputPath: "/tmp/tap-text.tritontest.yaml"
        )

        #expect(plan.steps[0].type == "tap")
        #expect(plan.steps[0].point == nil)
        #expect(plan.steps[0].target == nil)
        #expect(plan.steps[0].selector?.text == "Go Home")
        #expect(plan.steps[0].selector?.source == "ax")
        #expect(plan.steps[0].selector?.match == "exact")
    }

    @Test("P14 AI steps normalize as optional mock evidence steps")
    func aiStepsNormalizeAsOptionalMockEvidenceSteps() throws {
        let plan = try validateTritonTestContract(
            yaml: """
            version: 1
            name: ai-checks
            app:
              bundleId: com.example.LoginFixture
            device:
              platform: ios
            steps:
              - assertWithAI:
                  prompt: Login screen has a primary action
                  provider: mock
              - assertNoDefectsWithAI: {}
              - extractTextWithAI: {}
              - assertScreenshot:
                  baseline: /tmp/baseline.png
                  threshold: 0
                  cropOn: full
            """,
            inputPath: "/tmp/ai-checks.tritontest.yaml"
        )

        #expect(plan.steps.map(\.type) == ["assertWithAI", "assertNoDefectsWithAI", "extractTextWithAI", "assertScreenshot"])
        #expect(plan.steps[0].optional == true)
        #expect(plan.steps[0].provider == "mock")
        #expect(plan.steps[0].prompt == "Login screen has a primary action")
        #expect(plan.steps[1].optional == true)
        #expect(plan.steps[2].optional == true)
        #expect(plan.steps[3].optional == false)
        #expect(plan.steps[3].baseline == "/tmp/baseline.png")
        #expect(plan.steps[3].threshold == 0)
        #expect(plan.steps[3].cropOn == "full")
    }

    @Test("invalid tap point reports invalid_point with JSON path")
    func invalidTapPointReportsInvalidPointWithJSONPath() throws {
        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try validateTritonTestContract(
                yaml: """
                version: 1
                name: bad-point
                app:
                  bundleId: com.example.LoginFixture
                device:
                  platform: ios
                steps:
                  - tap:
                      point:
                        x: -1
                        y: 200
                        coordinateSpace: runtime-point
                """,
                inputPath: "/tmp/bad-point.tritontest.yaml"
            )
        }
        #expect(failure?.detail.code == "invalid_point")
        #expect(failure?.detail.path == "$.steps[0].tap.point.x")
    }

    @Test("duplicate explicit step id reports duplicate_step_id")
    func duplicateExplicitStepIDReportsDuplicateStepID() throws {
        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try validateTritonTestContract(
                yaml: """
                version: 1
                name: duplicate-id
                app:
                  bundleId: com.example.LoginFixture
                device:
                  platform: ios
                steps:
                  - id: login
                    launch: {}
                  - id: login
                    takeScreenshot: {}
                """,
                inputPath: "/tmp/duplicate-id.tritontest.yaml"
            )
        }
        #expect(failure?.detail.code == "duplicate_step_id")
        #expect(failure?.detail.path == "$.steps[1].id")
    }

    @Test("invalid app bundle id reports invalid_app_bundle_id")
    func invalidAppBundleIDReportsInvalidAppBundleID() throws {
        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try validateTritonTestContract(
                yaml: """
                version: 1
                name: invalid-bundle
                app:
                  bundleId: Invalid Bundle
                device:
                  platform: ios
                steps:
                  - launch: {}
                """,
                inputPath: "/tmp/invalid-bundle.tritontest.yaml"
            )
        }
        #expect(failure?.detail.code == "invalid_app_bundle_id")
        #expect(failure?.detail.path == "$.app.bundleId")
    }

    @Test("test command schema exposes deterministic run contract")
    func testCommandSchemaExposesDeterministicRunContract() throws {
        let schema = try #require(commandSchemas().first { $0.name == "test" })
        let validate = try #require(schema.subcommands.first { $0.name == "validate" })
        let run = try #require(schema.subcommands.first { $0.name == "run" })
        let reliability = try #require(schema.subcommands.first { $0.name == "reliability" })
        let reserve = try #require(schema.subcommands.first { $0.name == "reliability-reserve" })
        let sample = try #require(schema.subcommands.first { $0.name == "reliability-sample" })
        let failureShape = try #require(schema.failureShape)

        #expect(schema.requiresServer == false)
        #expect(schema.requiresTarget == false)
        #expect(schema.runtimeScope == "offline for import/validate/normalize/report/reliability/reliability-preflight/reliability-reserve/create; reliability-sample and run require an explicit runtime target; reliability-sample requires an already-running receipt-bound loopback server and never starts it")
        #expect(schema.providedCapabilities == ["test-import-compiled-contract", "test-validate", "test-normalized-plan", "test-run-minimal", "test-run-deterministic", "test-run-vlm-assisted", "test-run-ai-mock", "test-report", "test-reliability-gate", "test-reliability-collection-preflight", "test-reliability-reserve", "test-reliability-sample", "test-create-from-session"])
        #expect(schema.failureCodes.contains("unsupported_step"))
        #expect(failureShape.contains("run"))
        #expect(failureShape.contains("reliability-preflight"))
        #expect(failureShape.contains("reliability-reserve"))
        #expect(failureShape.contains("reliability-sample"))
        #expect(failureShape.contains("typed result then exits 1"))
        #expect(failureShape.contains("does not match its frozen expected outcome"))
        #expect(failureShape.contains("expected nonpassed negative-control result exits 0"))
        #expect(failureShape.contains("error:{ code, message"))
        #expect(validate.requiredOptions == ["<path.tritontest.yaml>"])
        #expect(validate.outputSelectors == ["test.validation", "test.normalized-plan"])
        #expect(run.requiredOptions == ["<path.tritontest.yaml>", "--evidence-dir"])
        #expect(run.outputSelectors == ["test.run-result", "test.validation", "test.normalized-plan"])
        #expect(run.requiresServer)
        #expect(run.requiresTarget)
        #expect(run.requiresConfirmation == false)
        #expect(run.sideEffect == "runtime-execution-evidence-write")
        #expect(reliability.requiredOptions == [])
        #expect(reliability.oneOfRequiredOptions == [["--samples"], ["--collection-receipt"]])
        #expect(reserve.requiredOptions == ["--collection"])
        #expect(reserve.outputSelectors == ["test.reliability-reserve"])
        #expect(reserve.requiresServer == false)
        #expect(reserve.requiresTarget == false)
        #expect(reserve.requiresConfirmation == false)
        #expect(reserve.sideEffect == "private-receipt-write")
        #expect(sample.requiredOptions == ["--collection-receipt", "--flow", "--slot", "--reset-receipt", "--target", "--confirm"])
        #expect(sample.outputSelectors == ["test.reliability-sample"])
        #expect(sample.requiresServer)
        #expect(sample.requiresTarget)
        #expect(sample.requiresConfirmation)
        #expect(sample.sideEffect == "runtime-execution-private-evidence-write")
        #expect(sample.optionOverrides.first { $0.name == "--target" }?.required == true)
        #expect(sample.optionOverrides.first { $0.name == "--target" }?.defaultValue == nil)
        #expect(sample.optionOverrides.first { $0.name == "--host" }?.defaultValue == "127.0.0.1")
        #expect(sample.optionOverrides.first { $0.name == "--port" }?.defaultValue == "19421")
        #expect(schema.outputContracts.contains { $0.selector == "test.run-result" })
        #expect(schema.outputContracts.contains { $0.selector == "test.report" })
        #expect(schema.outputContracts.contains { $0.selector == "test.reliability" })
        #expect(schema.outputContracts.contains { $0.selector == "test.reliability-collection-preflight" })
        #expect(schema.outputContracts.contains { $0.selector == "test.reliability-reserve" })
        #expect(schema.outputContracts.contains { $0.selector == "test.reliability-sample" })
        #expect(schema.outputContracts.contains { $0.selector == "test.create" })
    }

    @Test("test import reports omitted required fields as one JSON validation envelope")
    func testImportMissingFieldsUseJSONValidationEnvelope() throws {
        let result = try runTriton(["test", "import", "--json"])

        #expect(result.exitCode == 1)
        #expect(result.stderr.isEmpty)
        let response = try JSONDecoder().decode(
            TKTestValidationFailureResponse.self,
            from: Data(result.stdout.utf8)
        )
        #expect(!response.ok)
        #expect(response.error.type == "validation_error")
        #expect(response.error.code == "missing_required_field")
        #expect(response.error.path == "<case.tritontestcase>")
    }

    @Test("test reliability-preflight reports an omitted collection as one JSON envelope")
    func testReliabilityPreflightMissingCollectionUsesJSONEnvelope() throws {
        let result = try runTriton(["test", "reliability-preflight", "--json"])

        #expect(result.exitCode == 1)
        #expect(result.stderr.isEmpty)
        let response = try JSONDecoder().decode(
            TKCLIErrorResponse.self,
            from: Data(result.stdout.utf8)
        )
        #expect(!response.ok)
        #expect(response.error.code == "missing_required_field")
        #expect(response.error.message == "--collection is required.")
    }

    @Test("reliability-sample numeric validation stays in the JSON error envelope before receipt or runtime access")
    func testReliabilitySampleInvalidNumbersUseJSONEnvelope() throws {
        let result = try runTriton([
            "test", "reliability-sample",
            "--collection-receipt", "private-receipt.json",
            "--flow", "flow_001",
            "--slot", "not-a-slot",
            "--reset-receipt", "private-reset.json",
            "--target", "triton:ios-simulator:00000000-0000-0000-0000-000000000000/app:com.example.private",
            "--port", "not-a-port",
            "--confirm",
            "--json",
        ])

        #expect(result.exitCode == 1)
        #expect(result.stderr.isEmpty)
        let response = try JSONDecoder().decode(
            TKCLIErrorResponse.self,
            from: Data(result.stdout.utf8)
        )
        #expect(!response.ok)
        #expect(response.error.code == "invalid_reliability_sample_request")
    }

    @Test("reliability-sample missing configuration emits one JSON error envelope before runtime access")
    func testReliabilitySampleMissingTargetUsesJSONEnvelope() throws {
        let result = try runTriton([
            "test", "reliability-sample",
            "--collection-receipt", "private-receipt.json",
            "--flow", "flow_001",
            "--slot", "1",
            "--reset-receipt", "private-reset.json",
            "--confirm",
            "--json",
        ])

        #expect(result.exitCode == 1)
        #expect(result.stderr.isEmpty)
        let response = try JSONDecoder().decode(
            TKCLIErrorResponse.self,
            from: Data(result.stdout.utf8)
        )
        #expect(!response.ok)
        #expect(response.error.code == "missing_required_field")
    }

    private func validContractYAML() -> String {
        """
        version: 1
        name: login-flow
        app:
          bundleId: com.example.LoginFixture
        device:
          platform: ios
        settings:
          strict: true
          timeoutMs: 5000
          retry:
            count: 0
            intervalMs: 250
        steps:
          - launch: {}
          - takeScreenshot: {}
          - tap:
              point:
                x: 191.5
                y: 329.25
                coordinateSpace: runtime-point
          - assertVisible:
              text: Home
        """
    }

    private func deterministicContractYAML() -> String {
        """
        version: 1
        name: p6-deterministic
        app:
          bundleId: com.example.LoginFixture
        device:
          platform: ios
        steps:
          - launch: {}
          - input:
              text: hello
          - press:
              button: home
          - swipe:
              from:
                x: 20
                y: 200
                coordinateSpace: runtime-point
              to:
                x: 20
                y: 120
                coordinateSpace: runtime-point
          - assertNotVisible:
              text: Spinner
              source: ax
              match: exact
          - scrollUntilVisible:
              text: Checkout
              direction: down
              maxScrolls: 3
          - stop: {}
        """
    }

    private func invalidDragYAML() -> String {
        """
        version: 1
        name: invalid-drag
        app:
          bundleId: com.example.LoginFixture
        device:
          platform: ios
        steps:
          - drag:
              from:
                x: 10
                y: 20
              to:
                x: 10
                y: 200
        """
    }

    private func writeTemporaryContract(name: String, contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-test-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).tritontest.yaml")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func runTriton(_ arguments: [String]) throws -> CLIRunResult {
        let process = Process()
        process.executableURL = try tritonExecutableURL()
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return CLIRunResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func tritonExecutableURL() throws -> URL {
        let fileManager = FileManager.default
        for start in [
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent(),
            Bundle.main.bundleURL.deletingLastPathComponent(),
        ] {
            if let candidate = tritonExecutableAscending(from: start, fileManager: fileManager) {
                return candidate
            }
        }

        if let override = ProcessInfo.processInfo.environment["TRITON_CLI_PATH"],
           fileManager.isExecutableFile(atPath: override),
           tritonExecutableSupportsTestCommand(URL(fileURLWithPath: override)) {
            return URL(fileURLWithPath: override)
        }

        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildRoot = packageRoot.appendingPathComponent(".build", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: buildRoot,
            includingPropertiesForKeys: [.isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeError("Missing triton executable for CLI contract test")
        }
        for case let candidate as URL in enumerator where candidate.lastPathComponent == "triton" {
            if fileManager.isExecutableFile(atPath: candidate.path),
               tritonExecutableSupportsTestCommand(candidate) {
                return candidate
            }
        }
        if let candidate = tritonExecutableInTemporaryDirectory(fileManager: fileManager) {
            return candidate
        }
        throw RuntimeError("Missing triton executable for CLI contract test")
    }

    private func tritonExecutableAscending(from start: URL, fileManager: FileManager) -> URL? {
        var searchURL = start
        while searchURL.path != "/" {
            let candidate = searchURL.appendingPathComponent("triton")
            if fileManager.isExecutableFile(atPath: candidate.path),
               tritonExecutableSupportsTestCommand(candidate) {
                return candidate
            }
            searchURL.deleteLastPathComponent()
        }
        return nil
    }

    private func tritonExecutableInTemporaryDirectory(fileManager: FileManager) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: fileManager.temporaryDirectory,
            includingPropertiesForKeys: [.isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for case let candidate as URL in enumerator
        where candidate.lastPathComponent == "triton" && candidate.path.contains("triton-cli") {
            if fileManager.isExecutableFile(atPath: candidate.path),
               tritonExecutableSupportsTestCommand(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func tritonExecutableSupportsTestCommand(_ url: URL) -> Bool {
        let process = Process()
        process.executableURL = url
        process.arguments = ["test", "--help"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        guard process.terminationStatus == 0 else {
            return false
        }
        let text = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return text.contains(".tritontest.yaml")
    }
}

private struct CLIRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
