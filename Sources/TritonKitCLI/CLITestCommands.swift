import ArgumentParser
import Foundation
import TritonKitShared

struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Import, validate, normalize, and run deterministic .tritontest.yaml contracts",
        subcommands: [
            TestValidate.self,
            TestNormalize.self,
            TestRun.self,
            TestReport.self,
            TestReliability.self,
            TestCreate.self,
            TestImport.self,
        ]
    )
}

struct TestValidate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a .tritontest.yaml file and emit a normalized offline plan"
    )

    @Argument(help: ".tritontest.yaml path") var input: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(name: .customLong("emit-normalized-plan"), help: "Emit only the normalized plan JSON when validation succeeds")
    var emitNormalizedPlan = false

    func run() throws {
        try runTestValidationCommand(
            input: input,
            format: effectiveFormat(format, json: json),
            emitNormalizedPlan: emitNormalizedPlan
        )
    }
}

struct TestNormalize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "normalize",
        abstract: "Validate a .tritontest.yaml file and emit only the normalized plan"
    )

    @Argument(help: ".tritontest.yaml path") var input: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestValidationCommand(
            input: input,
            format: effectiveFormat(format, json: json),
            emitNormalizedPlan: true
        )
    }
}

struct TestRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a deterministic .tritontest.yaml plan and write .tritonevidence"
    )

    @Argument(help: ".tritontest.yaml path") var input: String
    @Option(name: .customLong("evidence-dir"), help: "Output .tritonevidence directory") var evidenceDir: String
    @Option(help: "Runtime target id. Defaults to local target resolution.") var target: String = TKLocalTargetID
    @Option(help: "Triton HTTP host") var host: String = "127.0.0.1"
    @Option(help: "Triton HTTP port") var port: Int = 19421
    @Flag(name: .customLong("allow-vlm"), help: "Allow experimental VLM-assisted test steps")
    var allowVLM = false
    @Flag(name: .customLong("allow-remote-vlm"), help: "Allow remote VLM provider calls that may send screenshots off-host")
    var allowRemoteVLM = false
    @Option(name: .customLong("vlm-base-url"), help: "OpenAI-compatible VLM base URL for VLM-assisted steps")
    var vlmBaseURL: String?
    @Option(name: .customLong("vlm-model"), help: "OpenAI-compatible VLM model for VLM-assisted steps")
    var vlmModel: String?
    @Option(name: .customLong("vlm-model-path"), help: "Local MLX VLM model path for VLM-assisted steps")
    var vlmModelPath: String?
    @Option(name: .customLong("vlm-api-key-env"), help: "Environment variable containing VLM API key")
    var vlmAPIKeyEnv: String?
    @Flag(name: .customLong("vlm-allow-model-download"), help: "Allow local VLM provider model download when explicitly requested")
    var vlmAllowModelDownload = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runTestRunCommand(
            input: input,
            evidenceDir: evidenceDir,
            target: target,
            host: host,
            port: port,
            allowVLM: allowVLM,
            allowRemoteVLM: allowRemoteVLM,
            vlmBaseURL: vlmBaseURL,
            vlmModel: vlmModel,
            vlmModelPath: vlmModelPath,
            vlmAPIKeyEnv: vlmAPIKeyEnv,
            vlmAllowModelDownload: vlmAllowModelDownload,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestReport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Build a JSON report from an existing .tritonevidence test run"
    )

    @Argument(help: ".tritonevidence directory or manifest.json path") var input: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestReportCommand(
            input: input,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestReliability: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reliability",
        abstract: "Evaluate private iOS Simulator test evidence against the canonical reliability gate"
    )

    @Option(name: .customLong("samples"), help: "Private reliability sample manifest JSON") var samples: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestReliabilityCommand(
            samples: samples,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestCreate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create an editable .tritontest.yaml draft from existing evidence"
    )

    @Option(name: .customLong("from-session"), help: ".tritonevidence directory or manifest.json path") var fromSession: String
    @Option(help: "Output .tritontest.yaml path") var output: String
    @Option(help: "Override generated test name") var name: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestCreateCommand(
            fromSession: fromSession,
            output: output,
            name: name,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestImport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import an existing compiled .tritontestcase contract into a validated .tritontest.yaml plan"
    )

    @Argument(help: "Compiled .tritontestcase directory") var input: String?
    @Option(help: "Output .tritontest.yaml path") var output: String?
    @Option(name: .customLong("bundle-id"), help: "Required app bundle identifier; testrec v1 does not store it") var bundleID: String?
    @Option(name: .customLong("device-platform"), help: "Required execution platform for the imported plan; P0 supports ios-simulator") var devicePlatform: String?
    @Option(name: .customLong("expect-compiled-digest"), help: "Optional expected fnv1a64 digest for compiled-contract.json") var expectedCompiledDigest: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestImportCommand(
            input: input,
            output: output,
            bundleID: bundleID,
            devicePlatform: devicePlatform,
            expectedCompiledDigest: expectedCompiledDigest,
            format: effectiveFormat(format, json: json)
        )
    }
}

private func runTestValidationCommand(
    input: String,
    format: ClientOutputFormat,
    emitNormalizedPlan: Bool
) throws {
    do {
        let url = URL(fileURLWithPath: input)
        let yaml = try String(contentsOf: url, encoding: .utf8)
        let plan = try validateTritonTestContract(yaml: yaml, inputPath: input)
        switch format {
        case .json:
            if emitNormalizedPlan {
                print(try encodeJSON(plan))
            } else {
                print(try encodeJSON(TKTestValidationResponse(input: input, normalizedPlan: plan)))
            }
        case .text:
            print("ok: true")
            print("name: \(plan.name)")
            print("steps: \(plan.steps.count)")
        }
    } catch let failure as TKTestValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(testValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    } catch {
        let failure = testValidationFailure(
            code: "missing_required_field",
            message: "\(error)",
            path: "$"
        )
        switch format {
        case .json:
            print(try encodeJSON(testValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRunCommand(
    input: String,
    evidenceDir: String,
    target: String,
    host: String,
    port: Int,
    allowVLM: Bool = false,
    allowRemoteVLM: Bool = false,
    vlmBaseURL: String? = nil,
    vlmModel: String? = nil,
    vlmModelPath: String? = nil,
    vlmAPIKeyEnv: String? = nil,
    vlmAllowModelDownload: Bool = false,
    format: ClientOutputFormat
) async throws {
    do {
        let response = try await runTritonTest(
            input: input,
            evidenceDirectory: evidenceDir,
            target: target,
            host: host,
            port: port,
            executor: TKLiveTestRunPrimitiveExecutor(),
            allowVLM: allowVLM,
            allowRemoteVLM: allowRemoteVLM,
            vlmBaseURL: vlmBaseURL,
            vlmModel: vlmModel,
            vlmModelPath: vlmModelPath,
            vlmAPIKeyEnv: vlmAPIKeyEnv,
            vlmAllowModelDownload: vlmAllowModelDownload
        )
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: \(response.ok)")
            print("status: \(response.summary.status?.rawValue ?? "unknown")")
            print("evidenceDir: \(response.evidenceDir)")
            if let failure = response.failure {
                print("failure: \(failure.type ?? "failure"): \(failure.message)")
            }
        }
        if !response.ok {
            throw ExitCode.failure
        }
    } catch let failure as TKTestValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(testValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    } catch {
        if error is ExitCode { throw error }
        try failCommand(error, outputFormat: format, endpoint: "/test/run", host: host, port: port)
    }
}

private func runTestReportCommand(
    input: String,
    format: ClientOutputFormat
) throws {
    do {
        let response = try buildTritonTestReport(input: input)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("status: \(response.summary.status?.rawValue ?? "unknown")")
            print("steps: \(response.summary.stepCount)")
            print("observations: \(response.summary.observationCount)")
            print("screenshots: \(response.summary.screenshotCount)")
            if let failure = response.failure {
                print("failure: \(failure.type ?? "failure"): \(failure.message)")
            }
        }
    } catch {
        let detail = TKCLIErrorDetail(
            code: "test_report_failed",
            message: "\(error)",
            hint: "Verify the path points to a .tritonevidence bundle containing manifest.json and run/events.jsonl."
        )
        switch format {
        case .json:
            print(try encodeJSON(TKCLIErrorResponse(error: detail)))
        case .text:
            fputs("test_report_failed: \(detail.message)\n", stderr)
        }
        throw ExitCode.failure
    }
}

private func runTestReliabilityCommand(
    samples: String?,
    format: ClientOutputFormat
) throws {
    do {
        guard let samples, !samples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TestReliabilityCommandFailure(detail: testReliabilityFailure(
                code: "missing_required_field",
                message: "--samples is required.",
                hint: "Provide a private reliability sample manifest with --samples <file.json>."
            ))
        }
        let report = try buildTritonTestReliabilityReport(samplesPath: samples)
        switch format {
        case .json:
            print(try encodeJSON(report))
        case .text:
            print("ok: true")
            print("gate: \(report.gate.status.rawValue)")
            print("evidenceCompleteness: \(report.evidenceCompleteness.rate)")
            print("failureExplainability: \(report.failureExplainability.rate)")
            print("outcomeRepeatability: \(report.outcomeRepeatability.rate)")
        }
        if report.gate.status == .blocked {
            throw ExitCode.failure
        }
    } catch let failure as TestReliabilityCommandFailure {
        let detail = failure.detail
        switch format {
        case .json:
            print(try encodeJSON(TKCLIErrorResponse(error: detail)))
        case .text:
            fputs("\(detail.code): \(detail.message)\n", stderr)
        }
        throw ExitCode.failure
    } catch let error as TKTestReliabilityError {
        let detail = testReliabilityErrorDetail(error)
        switch format {
        case .json:
            print(try encodeJSON(TKCLIErrorResponse(error: detail)))
        case .text:
            fputs("\(detail.code): \(detail.message)\n", stderr)
        }
        throw ExitCode.failure
    } catch {
        if error is ExitCode { throw error }
        let detail = testReliabilityFailure(
            code: "test_reliability_failed",
            message: "Reliability report could not be generated from the private sample manifest.",
            hint: "Verify the manifest schema and evidence bundle completeness."
        )
        switch format {
        case .json:
            print(try encodeJSON(TKCLIErrorResponse(error: detail)))
        case .text:
            fputs("\(detail.code): \(detail.message)\n", stderr)
        }
        throw ExitCode.failure
    }
}

private func testReliabilityErrorDetail(_ error: TKTestReliabilityError) -> TKCLIErrorDetail {
    switch error {
    case .invalidSampleSet:
        return testReliabilityFailure(
            code: "invalid_reliability_sample_set",
            message: "Reliability samples must use the supported private manifest schema.",
            hint: "Use flow ids, explicit reset evidence ids, target tokens, and existing evidence bundle paths."
        )
    case .invalidThresholds:
        return testReliabilityFailure(
            code: "invalid_reliability_thresholds",
            message: "Reliability thresholds must be non-negative rates between zero and one.",
            hint: "Use the canonical reliability gate thresholds."
        )
    }
}

private func testReliabilityFailure(code: String, message: String, hint: String) -> TKCLIErrorDetail {
    TKCLIErrorDetail(code: code, message: message, hint: hint)
}

private struct TestReliabilityCommandFailure: Error {
    let detail: TKCLIErrorDetail
}

private func runTestCreateCommand(
    fromSession: String,
    output: String,
    name: String?,
    format: ClientOutputFormat
) throws {
    do {
        let response = try createTritonTestFromSession(input: fromSession, output: output, name: name)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("output: \(response.output)")
            print("steps: \(response.stepCount)")
        }
    } catch let failure as TKTestValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(testValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    } catch {
        let detail = TKCLIErrorDetail(
            code: "test_create_failed",
            message: "\(error)",
            hint: "Verify the path points to a .tritonevidence bundle containing manifest.json and normalized-plan.json."
        )
        switch format {
        case .json:
            print(try encodeJSON(TKCLIErrorResponse(error: detail)))
        case .text:
            fputs("test_create_failed: \(detail.message)\n", stderr)
        }
        throw ExitCode.failure
    }
}

private func runTestImportCommand(
    input: String?,
    output: String?,
    bundleID: String?,
    devicePlatform: String?,
    expectedCompiledDigest: String?,
    format: ClientOutputFormat
) throws {
    do {
        guard let input, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw testValidationFailure(
                code: "missing_required_field",
                message: "<case.tritontestcase> is required.",
                path: "<case.tritontestcase>"
            )
        }
        guard let output, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw testValidationFailure(
                code: "missing_required_field",
                message: "--output is required.",
                path: "--output"
            )
        }
        guard let bundleID, !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw testValidationFailure(
                code: "missing_required_field",
                message: "--bundle-id is required.",
                path: "--bundle-id"
            )
        }
        guard let devicePlatform, !devicePlatform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw testValidationFailure(
                code: "missing_required_field",
                message: "--device-platform is required.",
                path: "--device-platform"
            )
        }
        let response = try importTritonTestCase(
            input: input,
            output: output,
            bundleID: bundleID,
            devicePlatform: devicePlatform,
            expectedCompiledDigest: expectedCompiledDigest
        )
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("output: \(response.output)")
            print("steps: \(response.importedPlan.steps.count)")
            print("compiledDigest: \(response.provenance.contractRef.digest)")
        }
    } catch let failure as TKTestValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(testValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    } catch {
        let failure = testValidationFailure(
            code: "test_import_failed",
            message: "test import failed before a validated plan could be written.",
            path: "$"
        )
        switch format {
        case .json:
            print(try encodeJSON(testValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}
