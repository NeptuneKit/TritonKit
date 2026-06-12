import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct Export: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export a reusable hierarchy snapshot or archive")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output file path") var output: String
    @Option(help: "Export format: auto, json, or archive") var format: ExportOutputFormat = .auto
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before exporting")
    var refresh = true

    func run() async throws {
        let resolvedFormat = try resolveExportFormat(effectiveFormat(format, json: json), output: output)
        let (targetSummary, client) = try await resolveRuntimeClient(
            target: target,
            host: host,
            port: port,
            jsonError: json || resolvedFormat == .json
        )
        if refresh {
            _ = try await client.request(type: "hierarchy")
        }
        let hierarchyData = try await waitForHierarchy(client: client)
        let data: Data
        switch resolvedFormat {
        case .json, .auto:
            data = hierarchyData
        case .archive:
            let archive = try await buildExportArchive(
                target: targetSummary,
                hierarchyData: hierarchyData,
                client: client
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            data = try encoder.encode(archive)
        }
        try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        print(output)
    }
}

struct Evidence: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture, inspect, summarize, or redact an agent-friendly regression evidence bundle"
    )

    @Argument(help: "Optional action. Use `inspect`, `summary`, or `redact` for existing bundles.") var action: String?
    @Argument(help: "Evidence bundle path for `inspect`, `summary`, or `redact`.") var input: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Evidence bundle directory path") var output: String?
    @Option(help: "Comma-separated artifacts: screenshot,ax,hierarchy,status,list,version,geometry,archive,logs,host,xcode,network.proxy-session")
    var include: String = "status,list,version,hierarchy,ax,screenshot"
    @Option(help: "Scenario name stored in manifest") var name: String?
    @Option(help: "Human note stored in manifest") var note: String?
    @Option(name: .customLong("xcode-summary"), help: "Explicit TKXcodeActionSummary JSON file to import when --include contains xcode")
    var xcodeSummary: String?
    @Option(name: .customLong("proxy-session"), help: "Explicit device proxy session directory to import when --include contains network.proxy-session")
    var proxySession: String?
    @Option(help: "Redaction profile for existing evidence bundles") var profile: String = "ios-private"
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before capturing hierarchy/archive")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if let action {
            switch action {
            case "inspect":
                guard let input else {
                    try failEvidenceValidation("`triton evidence inspect` requires a bundle path", outputFormat: outputFormat)
                }
                let manifest = try readEvidenceManifest(from: input)
                try printEvidenceManifest(manifest, format: outputFormat)
                return
            case "summary":
                guard let input else {
                    try failEvidenceValidation("`triton evidence summary` requires a bundle path", outputFormat: outputFormat)
                }
                let summary = try summarizeEvidenceBundle(input: input, profile: profile)
                try printEvidenceSummary(summary, format: outputFormat)
                return
            case "redact":
                guard let input else {
                    try failEvidenceValidation("`triton evidence redact` requires a bundle path", outputFormat: outputFormat)
                }
                guard let output else {
                    try failEvidenceValidation("`triton evidence redact` requires --output <path>", outputFormat: outputFormat)
                }
                let redacted = try redactEvidenceBundle(input: input, output: output, profile: profile)
                try printEvidenceRedaction(redacted, format: outputFormat)
                return
            default:
                try failEvidenceValidation("Unsupported evidence action: \(action)", outputFormat: outputFormat)
            }
        }

        guard input == nil else {
            try failEvidenceValidation("Unexpected evidence argument: \(input ?? "")", outputFormat: outputFormat)
        }
        guard let output else {
            try failEvidenceValidation("`triton evidence` requires --output <path>", outputFormat: outputFormat)
        }

        let includes: [String]
        do {
            includes = try parseEvidenceIncludes(include)
        } catch {
            try failEvidenceValidation("\(error)", outputFormat: outputFormat)
        }
        do {
            let manifest = try await captureEvidenceBundle(
                output: output,
                includes: includes,
                name: name,
                note: note,
                target: target,
                host: host,
                port: port,
                refresh: refresh,
                xcodeSummaryPath: xcodeSummary,
                proxySessionPath: proxySession
            )
            try printEvidenceManifest(manifest, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/evidence", host: host, port: port)
        }
    }
}

struct Capture: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture an agent-friendly regression evidence bundle"
    )

    @Option(name: .customLong("case"), help: "Regression case name stored in manifest") var caseName: String?
    @Option(help: "Evidence bundle directory path") var output: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Comma-separated artifacts: screenshot,ax,hierarchy,status,list,version,geometry,archive,logs,host,xcode,network.proxy-session")
    var include: String = "status,list,version,hierarchy,ax,screenshot,geometry,archive"
    @Option(help: "Human note stored in manifest") var note: String?
    @Option(name: .customLong("xcode-summary"), help: "Explicit TKXcodeActionSummary JSON file to import when --include contains xcode")
    var xcodeSummary: String?
    @Option(name: .customLong("proxy-session"), help: "Explicit device proxy session directory to import when --include contains network.proxy-session")
    var proxySession: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before capturing hierarchy/archive")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let includes: [String]
        do {
            includes = try parseEvidenceIncludes(include)
        } catch {
            try failRegressionValidation("\(error)", command: "capture", outputFormat: outputFormat)
        }
        do {
            let manifest = try await captureEvidenceBundle(
                output: output,
                includes: includes,
                name: caseName,
                note: note,
                target: target,
                host: host,
                port: port,
                refresh: refresh,
                xcodeSummaryPath: xcodeSummary,
                proxySessionPath: proxySession
            )
            try printEvidenceManifest(manifest, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/capture", host: host, port: port)
        }
    }
}

struct UIAssert: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "assert",
        abstract: "Assert visible UI text state for agent-driven regression"
    )

    @Argument(help: "Assertion condition: text-exists or text-not-exists") var condition: String
    @Argument(help: "Visible text, AX label, identifier, title, or value to assert") var query: String
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Optional AX role filter") var role: String?
    @Option(help: "Require exact match count") var count: Int?
    @Option(name: .customLong("min-count"), help: "Require at least this many matches") var minCount: Int?
    @Option(name: .customLong("max-count"), help: "Require at most this many matches") var maxCount: Int?
    @Option(help: "Restrict assertion to bounds: x,y,width,height") var within: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard let assertionCondition = TKUIAssertCondition(rawValue: condition) else {
                try failRegressionValidation("Unsupported assert condition: \(condition)", command: "assert", outputFormat: outputFormat)
            }
            let exactCountProvided = count != nil
            if exactCountProvided && (minCount != nil || maxCount != nil) {
                try failRegressionValidation("--count cannot be combined with --min-count or --max-count", command: "assert", outputFormat: outputFormat)
            }
            if let count, count < 0 {
                try failRegressionValidation("--count must be non-negative", command: "assert", outputFormat: outputFormat)
            }
            if let minCount, minCount < 0 {
                try failRegressionValidation("--min-count must be non-negative", command: "assert", outputFormat: outputFormat)
            }
            if let maxCount, maxCount < 0 {
                try failRegressionValidation("--max-count must be non-negative", command: "assert", outputFormat: outputFormat)
            }
            if let minCount, let maxCount, minCount > maxCount {
                try failRegressionValidation("--min-count cannot be greater than --max-count", command: "assert", outputFormat: outputFormat)
            }
            let bounds: TKRect?
            do {
                bounds = try within.map(parseAssertBounds)
            } catch {
                try failRegressionValidation("\(error)", command: "assert", outputFormat: outputFormat)
            }
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let status: TKStatusResponse = try await client.getJSON("/status")
            let accessibilityData = try await client.request(type: "accessibility")
            let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
            let request = TKUIAssertRequest(
                condition: assertionCondition,
                query: query,
                role: role,
                count: count,
                minCount: minCount,
                maxCount: maxCount,
                within: bounds
            )
            let result = TKUIAssertEvaluate(
                request,
                nodes: nodes,
                targetConnectionState: status.targetConnectionState,
                hierarchyCacheState: status.hierarchyCacheState
            )
            try printAssertResult(result, format: outputFormat)
            if !result.ok {
                throw ExitCode.failure
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/assert", host: host, port: port)
        }
    }
}

struct Record: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create an editable replay plan template. This is not interactive recording yet."
    )

    @Option(help: "Output .tritonplan file path") var output: String
    @Option(help: "Plan name. Defaults to the output file basename.") var name: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        let outputFormat = effectiveFormat(format, json: json)
        let outputURL = URL(fileURLWithPath: output)
        let planName = name ?? outputURL.deletingPathExtension().lastPathComponent
        let plan = TKReplayPlan.template(name: planName.isEmpty ? "smoke-flow" : planName)
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try prettyEncodedData(plan).write(to: outputURL, options: .atomic)
            let response = TKRecordPlanResponse(
                ok: true,
                output: outputURL.path,
                templateOnly: true,
                message: "Created editable Triton replay plan template; interactive recording is not implemented yet",
                plan: plan
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print(outputURL.path)
                print("templateOnly: true")
            }
        } catch {
            if error is ExitCode { throw error }
            try failReplayValidation("\(error)", outputFormat: outputFormat)
        }
    }
}

struct Replay: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Replay a .tritonplan smoke-test flow")

    @Argument(help: "Replay plan path") var input: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Validate and print commands without connecting to runtime") var dryRun = false
    @Option(name: .customLong("var"), help: "Variable assignment: key=value or key-env=ENV_NAME")
    var variables: [String] = []

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let plan = try readReplayPlan(from: input)
            let resolvedVariables = try parseReplayVariables(variables)
            let result = try await runReplayPlan(
                plan,
                variables: resolvedVariables,
                dryRun: dryRun,
                target: plan.target?.id ?? target,
                host: host,
                port: port
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(result))
            case .text:
                print("ok: \(result.ok)")
                if let planName = result.planName { print("plan: \(planName)") }
                print("dryRun: \(result.dryRun)")
                print("executed: \(result.executedCount)/\(result.stepCount)")
                if let failedStepIndex = result.failedStepIndex {
                    print("failedStepIndex: \(failedStepIndex)")
                }
                if let failureCode = result.failureCode {
                    print("failureCode: \(failureCode)")
                }
                if let error = result.failureError {
                    print("failureError: \(error.code) \(error.message)")
                }
                if !result.failureWorkflowCategories.isEmpty {
                    print("failureWorkflowCategories: \(result.failureWorkflowCategories.joined(separator: ", "))")
                }
                if !result.failureRecoveryCategories.isEmpty {
                    print("failureRecoveryCategories: \(result.failureRecoveryCategories.joined(separator: ", "))")
                }
                if !result.failurePrimaryArtifacts.isEmpty {
                    print("failurePrimaryArtifacts: \(result.failurePrimaryArtifacts.map(\.kind).joined(separator: ", "))")
                }
                if !result.recoveryCommands.isEmpty {
                    let commands = result.recoveryCommands.map { "\($0.category): \($0.command)" }
                    print("recoveryCommands: \(commands.joined(separator: " | "))")
                }
                if !result.suggestedCommands.isEmpty {
                    print("suggestedCommands: \(result.suggestedCommands.joined(separator: " | "))")
                }
                for step in result.steps {
                    print("[\(step.index)] \(step.action) ok=\(step.ok) \(step.command.joined(separator: " "))")
                }
            }
            if !result.ok {
                throw ExitCode.failure
            }
        } catch {
            if error is ExitCode { throw error }
            try failReplayValidation("\(error)", outputFormat: outputFormat)
        }
    }
}
