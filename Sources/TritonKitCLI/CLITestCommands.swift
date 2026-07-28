import ArgumentParser
import Foundation
import TritonKitShared

struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Import, validate, preflight, normalize, run, report, and evaluate deterministic .tritontest.yaml contracts",
        subcommands: [
            TestValidate.self,
            TestNormalize.self,
            TestRun.self,
            TestReport.self,
            TestReliability.self,
            TestReliabilityPreflight.self,
            TestReliabilityReserve.self,
            TestReliabilitySample.self,
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

    @Option(name: .customLong("samples"), help: "Private legacy reliability sample manifest JSON") var samples: String?
    @Option(name: .customLong("collection-receipt"), help: "Private receipt created by reliability-reserve") var collectionReceipt: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestReliabilityCommand(
            samples: samples,
            collectionReceipt: collectionReceipt,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestReliabilityReserve: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reliability-reserve",
        abstract: "Freeze a private reliability collection into one exclusive receipt without using runtime"
    )

    @Option(name: .customLong("collection"), help: "Private reliability collection JSON") var collection: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestReliabilityReserveCommand(
            collection: collection,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestReliabilitySample: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reliability-sample",
        abstract: "Execute exactly one receipt-frozen reliability sample after explicit confirmation"
    )

    @Option(name: .customLong("collection-receipt"), help: "Private receipt created by reliability-reserve") var collectionReceipt: String?
    @Option(help: "Receipt flow alias such as flow_001") var flow: String?
    @Option(help: "Receipt slot number") var slot: String?
    @Option(name: .customLong("reset-receipt"), help: "Operator-created private reset receipt for this exact slot") var resetReceipt: String?
    @Option(help: "Exact canonical iOS Simulator runtime target from the receipt") var target: String?
    @Option(help: "Triton HTTP host; reliability samples require 127.0.0.1") var host: String = "127.0.0.1"
    @Option(help: "Triton HTTP port; reliability samples require 19421") var port: String = "19421"
    @Flag(help: "Permit this exact receipt-bound slot to invoke the runner") var confirm = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runTestReliabilitySampleCommand(
            collectionReceipt: collectionReceipt,
            flow: flow,
            slot: slot,
            resetReceipt: resetReceipt,
            target: target,
            host: host,
            port: port,
            confirm: confirm,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestReliabilityPreflight: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reliability-preflight",
        abstract: "Validate an offline private reliability collection contract without starting runtime or writing evidence"
    )

    @Option(name: .customLong("collection"), help: "Private reliability collection JSON") var collection: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestReliabilityPreflightCommand(
            collection: collection,
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
    collectionReceipt: String?,
    format: ClientOutputFormat
) throws {
    do {
        let nonEmptySamples = samples?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyReceipt = collectionReceipt?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (nonEmptySamples?.isEmpty == false) != (nonEmptyReceipt?.isEmpty == false) else {
            throw TestReliabilityCommandFailure(detail: testReliabilityFailure(
                code: "missing_required_field",
                message: "Provide exactly one of --samples or --collection-receipt.",
                hint: "Use --samples for the legacy private sample set, or --collection-receipt for the receipt-backed harness."
            ))
        }
        let report: TKTestReliabilityReport
        if let nonEmptyReceipt, !nonEmptyReceipt.isEmpty {
            report = try buildTritonTestReliabilityReceiptReport(collectionReceiptPath: nonEmptyReceipt)
        } else if let nonEmptySamples, !nonEmptySamples.isEmpty {
            report = try buildTritonTestReliabilityReport(samplesPath: nonEmptySamples)
        } else {
            throw TestReliabilityCommandFailure(detail: testReliabilityFailure(
                code: "missing_required_field",
                message: "Provide exactly one of --samples or --collection-receipt.",
                hint: "Use a private reliability input."
            ))
        }
        switch format {
        case .json:
            print(try encodeJSON(report))
        case .text:
            print("ok: true")
            print("gateAuthority: \(report.gateAuthority.rawValue)")
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
    } catch let error as TKTestReliabilityHarnessError {
        try printTestReliabilityHarnessFailure(testReliabilityHarnessErrorDetail(error), format: format)
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

private func runTestReliabilityReserveCommand(
    collection: String?,
    format: ClientOutputFormat
) throws {
    do {
        guard let collection, !collection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TestReliabilityCommandFailure(detail: testReliabilityFailure(
                code: "missing_required_field",
                message: "--collection is required.",
                hint: "Provide a private collection declaration with --collection <private.json>."
            ))
        }
        let response = try reserveTritonTestReliabilityCollection(collectionPath: collection)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("receipt: \(response.receiptFile)")
            print("plannedSamples: \(response.plannedSampleCount)")
        }
    } catch let failure as TestReliabilityCommandFailure {
        try printTestReliabilityHarnessFailure(failure.detail, format: format)
    } catch let error as TKTestReliabilityHarnessError {
        try printTestReliabilityHarnessFailure(testReliabilityHarnessErrorDetail(error), format: format)
    } catch {
        if error is ExitCode { throw error }
        try printTestReliabilityHarnessFailure(
            testReliabilityFailure(
                code: "reliability_reservation_write_failed",
                message: "The private reliability reservation could not be completed.",
                hint: "Inspect the private collection and reserved root without overwriting it."
            ),
            format: format
        )
    }
}

func runTestReliabilitySampleCommand(
    collectionReceipt: String?,
    flow: String?,
    slot: String?,
    resetReceipt: String?,
    target: String?,
    host: String,
    port: String,
    confirm: Bool,
    format: ClientOutputFormat,
    executeSample: ((TKTestReliabilitySampleRequest) async throws -> TKTestReliabilitySampleResponse)? = nil,
    write: (String) -> Void = { print($0) }
) async throws {
    do {
        guard let collectionReceipt,
              !collectionReceipt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let flow,
              !flow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let slot,
              !slot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let resetReceipt,
              !resetReceipt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let target,
              !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TestReliabilityCommandFailure(detail: testReliabilityFailure(
                code: "missing_required_field",
                message: "reliability-sample requires receipt, flow, slot, reset receipt, and target.",
                hint: "Provide the exact private receipt-bound sample arguments."
            ))
        }
        guard let parsedSlot = Int(slot), parsedSlot > 0,
              let parsedPort = Int(port), parsedPort > 0 else {
            throw TestReliabilityCommandFailure(detail: testReliabilityFailure(
                code: "invalid_reliability_sample_request",
                message: "reliability-sample --slot and --port must be positive integers.",
                hint: "Use a declared positive receipt slot and port 19421."
            ))
        }
        let request = TKTestReliabilitySampleRequest(
            collectionReceipt: collectionReceipt,
            flow: flow,
            slot: parsedSlot,
            resetReceipt: resetReceipt,
            target: target,
            host: host,
            port: parsedPort,
            confirm: confirm
        )
        let response: TKTestReliabilitySampleResponse
        if let executeSample {
            response = try await executeSample(request)
        } else {
            let executor = TKLiveTestRunPrimitiveExecutor()
            response = try await runTritonTestReliabilitySample(
                request: request,
                executor: executor,
                targetResolver: TKLiveTestReliabilityRuntimeTargetResolver()
            )
        }
        try emitTestReliabilitySampleResult(response, format: format, write: write)
    } catch let failure as TestReliabilityCommandFailure {
        try printTestReliabilityHarnessFailure(failure.detail, format: format)
    } catch let error as TKTestReliabilityHarnessError {
        try printTestReliabilityHarnessFailure(testReliabilityHarnessErrorDetail(error), format: format)
    } catch {
        if error is ExitCode { throw error }
        try printTestReliabilityHarnessFailure(
            testReliabilityHarnessErrorDetail(.runnerFailed),
            format: format
        )
    }
}

func emitTestReliabilitySampleResult(
    _ response: TKTestReliabilitySampleResponse,
    format: ClientOutputFormat,
    write: (String) -> Void = { print($0) }
) throws {
    switch format {
    case .json:
        write(try encodeJSON(response))
    case .text:
        write("ok: \(response.ok)")
        write("flow: \(response.flowID)")
        write("slot: \(response.slot)")
        write("runStatus: \(response.runStatus.rawValue)")
    }
    if !response.ok {
        throw ExitCode.failure
    }
}

private func printTestReliabilityHarnessFailure(
    _ detail: TKCLIErrorDetail,
    format: ClientOutputFormat
) throws -> Never {
    switch format {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        fputs("\(detail.code): \(detail.message)\n", stderr)
    }
    throw ExitCode.failure
}

private func runTestReliabilityPreflightCommand(
    collection: String?,
    format: ClientOutputFormat
) throws {
    do {
        guard let collection, !collection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TestReliabilityCollectionPreflightCommandFailure(detail: testReliabilityFailure(
                code: "missing_required_field",
                message: "--collection is required.",
                hint: "Provide a private collection declaration with --collection <private.json>."
            ))
        }
        let response = try buildTritonTestReliabilityCollectionPreflight(collectionPath: collection)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("status: \(response.status.rawValue)")
            print("supportedFlows: \(response.supportedFlowCount)")
            print("runsPerSupportedFlow: \(response.runsPerSupportedFlow)")
            print("plannedSamples: \(response.plannedSampleCount)")
        }
    } catch let failure as TestReliabilityCollectionPreflightCommandFailure {
        try printTestReliabilityCollectionPreflightFailure(failure.detail, format: format)
    } catch let error as TKTestReliabilityCollectionError {
        try printTestReliabilityCollectionPreflightFailure(
            testReliabilityCollectionErrorDetail(error),
            format: format
        )
    } catch {
        if error is ExitCode { throw error }
        let detail = testReliabilityFailure(
            code: "test_reliability_collection_preflight_failed",
            message: "Reliability collection preflight could not be completed.",
            hint: "Verify the private collection declaration and imported plan contracts."
        )
        try printTestReliabilityCollectionPreflightFailure(detail, format: format)
    }
}

private func printTestReliabilityCollectionPreflightFailure(
    _ detail: TKCLIErrorDetail,
    format: ClientOutputFormat
) throws -> Never {
    switch format {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        fputs("\(detail.code): \(detail.message)\n", stderr)
    }
    throw ExitCode.failure
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

private struct TestReliabilityCollectionPreflightCommandFailure: Error {
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
