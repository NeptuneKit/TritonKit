import ArgumentParser
import Foundation
import TritonKitShared

struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Validate, normalize, and run deterministic .tritontest.yaml contracts",
        subcommands: [
            TestValidate.self,
            TestNormalize.self,
            TestRun.self,
            TestReport.self,
            TestCreate.self,
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
    @Option(name: .customLong("vlm-api-key-env"), help: "Environment variable containing VLM API key")
    var vlmAPIKeyEnv: String?
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
            vlmAPIKeyEnv: vlmAPIKeyEnv,
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
    vlmAPIKeyEnv: String? = nil,
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
            vlmAPIKeyEnv: vlmAPIKeyEnv
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
