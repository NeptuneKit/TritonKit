import Foundation
import Testing
@testable import TritonKitCLI

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
        let url = try writeTemporaryContract(name: "swipe", contents: invalidSwipeYAML())
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
        #expect(response.error.path == "$.steps[0].swipe")
        #expect(response.error.allowed == ["launch", "takeScreenshot", "tap", "assertVisible"])
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

    @Test("test command schema exposes P0D minimal run contract")
    func testCommandSchemaExposesP0DMinimalRunContract() throws {
        let schema = try #require(commandSchemas().first { $0.name == "test" })
        let validate = try #require(schema.subcommands.first { $0.name == "validate" })
        let run = try #require(schema.subcommands.first { $0.name == "run" })

        #expect(schema.requiresServer == false)
        #expect(schema.requiresTarget == false)
        #expect(schema.runtimeScope == "offline for validate/normalize; runtime target required for run")
        #expect(schema.providedCapabilities == ["test-validate", "test-normalized-plan", "test-run-minimal"])
        #expect(schema.failureCodes.contains("unsupported_step"))
        #expect(validate.requiredOptions == ["<path.tritontest.yaml>"])
        #expect(validate.outputSelectors == ["test.validation", "test.normalized-plan"])
        #expect(run.requiredOptions == ["<path.tritontest.yaml>", "--evidence-dir"])
        #expect(run.outputSelectors == ["test.run-result", "test.validation", "test.normalized-plan"])
        #expect(schema.outputContracts.contains { $0.selector == "test.run-result" })
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

    private func invalidSwipeYAML() -> String {
        """
        version: 1
        name: invalid-swipe
        app:
          bundleId: com.example.LoginFixture
        device:
          platform: ios
        steps:
          - swipe:
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
