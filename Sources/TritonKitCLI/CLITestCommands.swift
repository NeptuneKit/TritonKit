import ArgumentParser
import Foundation
import TritonKitShared

struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Validate, normalize, and run minimal .tritontest.yaml contracts",
        subcommands: [
            TestValidate.self,
            TestNormalize.self,
            TestRun.self,
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
        abstract: "Run a minimal .tritontest.yaml plan and write .tritonevidence"
    )

    @Argument(help: ".tritontest.yaml path") var input: String
    @Option(name: .customLong("evidence-dir"), help: "Output .tritonevidence directory") var evidenceDir: String
    @Option(help: "Runtime target id. Defaults to local target resolution.") var target: String = TKLocalTargetID
    @Option(help: "Triton HTTP host") var host: String = "127.0.0.1"
    @Option(help: "Triton HTTP port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runTestRunCommand(
            input: input,
            evidenceDir: evidenceDir,
            target: target,
            host: host,
            port: port,
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
    format: ClientOutputFormat
) async throws {
    do {
        let response = try await runTritonTest(
            input: input,
            evidenceDirectory: evidenceDir,
            target: target,
            host: host,
            port: port,
            executor: TKLiveTestRunPrimitiveExecutor()
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
