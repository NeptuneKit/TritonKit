import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct EvidenceScreenshotMetadata: Codable {
    let format: String
    let width: Double
    let height: Double
    let scale: Double
    let dataRef: String?
    let imagePath: String
    let bytes: Int
}

struct EvidenceArtifactPayload {
    let data: Data
    let contentType: String
    let sourceCommand: String?

    init(data: Data, contentType: String = "application/json", sourceCommand: String? = nil) {
        self.data = data
        self.contentType = contentType
        self.sourceCommand = sourceCommand
    }
}

struct EvidenceHostXcodeArtifactProviders {
    var loadDefaults: () throws -> TKHostWorkspaceDefaults?
    var simulatorList: () throws -> EvidenceArtifactPayload
    var xcodeStatus: () throws -> EvidenceArtifactPayload
    var xcodeDiscovery: () throws -> EvidenceArtifactPayload

    static let live = EvidenceHostXcodeArtifactProviders(
        loadDefaults: {
            try loadHostWorkspaceDefaults()
        },
        simulatorList: {
            let command = TKSimctlCommand.listAvailableDevices()
            let result = try runHostCommand(command)
            return EvidenceArtifactPayload(
                data: try prettyJSONData(result.stdoutData),
                sourceCommand: result.sourceCommand
            )
        },
        xcodeStatus: {
            let status = try currentXcodeProcessStatus()
            return EvidenceArtifactPayload(
                data: try prettyEncodedData(status),
                sourceCommand: status.sourceCommand
            )
        },
        xcodeDiscovery: {
            let discovery = try TKXcodeProjectDiscovery.discover(path: ".", maxDepth: 2)
            return EvidenceArtifactPayload(
                data: try prettyEncodedData(discovery),
                sourceCommand: "triton xcode discover --path . --json"
            )
        }
    )
}

func parseEvidenceIncludes(_ raw: String) throws -> [String] {
    let aliases = [
        "targets": "list",
        "accessibility": "ax",
        "export": "archive",
    ]
    let allowed: Set<String> = [
        "screenshot",
        "ax",
        "hierarchy",
        "status",
        "list",
        "version",
        "geometry",
        "archive",
        "logs",
        "host",
        "xcode",
    ]
    var result: [String] = []
    var seen = Set<String>()
    for part in raw.split(separator: ",") {
        let normalized = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { continue }
        let kind = aliases[normalized] ?? normalized
        guard allowed.contains(kind) else {
            throw RuntimeError("Unsupported evidence include: \(normalized)")
        }
        if seen.insert(kind).inserted {
            result.append(kind)
        }
    }
    return result.isEmpty ? ["status", "list", "version", "hierarchy", "ax", "screenshot"] : result
}

func failEvidenceValidation(_ message: String, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Run `triton schema --command evidence --json` to inspect required fields"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}

func readEvidenceManifest(from path: String) throws -> TKEvidenceManifest {
    let inputURL = URL(fileURLWithPath: path)
    let manifestURL: URL
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
        manifestURL = inputURL.appendingPathComponent("manifest.json")
    } else {
        manifestURL = inputURL.lastPathComponent == "manifest.json"
            ? inputURL
            : inputURL.appendingPathComponent("manifest.json")
    }
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(TKEvidenceManifest.self, from: data)
}

func evidenceBundleRoot(from path: String) -> URL {
    let inputURL = URL(fileURLWithPath: path)
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
        return inputURL
    }
    if inputURL.lastPathComponent == "manifest.json" {
        return inputURL.deletingLastPathComponent()
    }
    return inputURL.deletingLastPathComponent()
}

func summarizeEvidenceBundle(input: String, profile: String = "ios-private") throws -> TKEvidenceSummaryResponse {
    let manifest = try readEvidenceManifest(from: input)
    let artifacts = manifest.artifacts.map(evidenceArtifactSummary)
    let sensitiveArtifactCount = manifest.artifacts.filter(evidenceArtifactIsSensitive).count
    let summary = TKEvidenceSummaryResponse(
        action: "evidence.summary",
        input: input,
        profile: profile,
        createdAt: manifest.createdAt,
        name: manifest.name,
        note: manifest.note,
        output: manifest.output,
        artifactCount: manifest.artifacts.count,
        sensitiveArtifactCount: sensitiveArtifactCount,
        skippedCount: manifest.skipped.count,
        target: manifest.target,
        cli: manifest.cli,
        artifacts: artifacts,
        primaryArtifacts: manifest.primaryArtifacts,
        skipped: manifest.skipped,
        suggestedCommands: [
            "triton evidence redact \(shellQuotedEvidencePath(input)) --profile \(profile) --output \(shellQuotedEvidencePath(evidenceBundleRoot(from: input).appendingPathComponent("redacted").path)) --json",
        ]
    )
    return summary
}

func redactEvidenceBundle(input: String, output: String, profile: String) throws -> TKEvidenceRedactionResponse {
    let manifest = try readEvidenceManifest(from: input)
    let inputRoot = evidenceBundleRoot(from: input)
    let outputURL = URL(fileURLWithPath: output)
    try prepareEvidenceOutputDirectory(outputURL)

    var redactedArtifacts: [TKEvidenceArtifact] = []
    var keptArtifacts: [TKEvidenceArtifact] = []
    var redactedSummaries: [TKEvidenceArtifactSummary] = []
    var keptSummaries: [TKEvidenceArtifactSummary] = []
    var outputArtifacts: [TKEvidenceArtifact] = []
    var outputSummaries: [TKEvidenceArtifactSummary] = []

    for artifact in manifest.artifacts {
        if evidenceArtifactIsSensitive(artifact) {
            let placeholderPath = "redacted/\(sanitizedEvidencePathComponent(artifact.kind)).json"
            let placeholderURL = outputURL.appendingPathComponent(placeholderPath)
            try FileManager.default.createDirectory(at: placeholderURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let placeholderData = try prettyEncodedData(TKEvidenceArtifactSummary(
                kind: artifact.kind,
                path: artifact.path,
                contentType: artifact.contentType,
                bytes: artifact.bytes,
                platform: artifact.platform,
                riskLevel: artifact.riskLevel,
                policy: profile,
                redactionStatus: "redacted",
                target: artifact.target
            ))
            try placeholderData.write(to: placeholderURL, options: .atomic)
            let summary = TKEvidenceArtifactSummary(
                kind: artifact.kind,
                path: placeholderPath,
                contentType: "application/json",
                bytes: placeholderData.count,
                platform: artifact.platform,
                riskLevel: artifact.riskLevel,
                policy: profile,
                redactionStatus: "redacted",
                target: artifact.target
            )
            redactedSummaries.append(summary)
            let redactedArtifact = TKEvidenceArtifact(
                kind: artifact.kind,
                path: placeholderPath,
                contentType: "application/json",
                bytes: placeholderData.count,
                freshness: artifact.freshness,
                platform: artifact.platform,
                riskLevel: artifact.riskLevel,
                policy: profile,
                redactionStatus: "redacted",
                sourceCommand: nil,
                target: artifact.target
            )
            redactedArtifacts.append(redactedArtifact)
            outputArtifacts.append(redactedArtifact)
            outputSummaries.append(summary)
        } else {
            let sourceURL = inputRoot.appendingPathComponent(artifact.path)
            let destinationURL = outputURL.appendingPathComponent(artifact.path)
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } else {
                let placeholderData = Data()
                try placeholderData.write(to: destinationURL, options: .atomic)
            }
            let summary = TKEvidenceArtifactSummary(
                kind: artifact.kind,
                path: artifact.path,
                contentType: artifact.contentType,
                bytes: artifact.bytes,
                platform: artifact.platform,
                riskLevel: artifact.riskLevel,
                policy: artifact.policy,
                redactionStatus: "included",
                target: artifact.target
            )
            keptSummaries.append(summary)
            let keptArtifact = TKEvidenceArtifact(
                kind: artifact.kind,
                path: artifact.path,
                contentType: artifact.contentType,
                bytes: artifact.bytes,
                freshness: artifact.freshness,
                platform: artifact.platform,
                riskLevel: artifact.riskLevel,
                policy: artifact.policy,
                redactionStatus: "included",
                sourceCommand: artifact.sourceCommand,
                target: artifact.target
            )
            keptArtifacts.append(keptArtifact)
            outputArtifacts.append(keptArtifact)
            outputSummaries.append(summary)
        }
    }

    let redactedManifest = TKEvidenceManifest(
        ok: manifest.ok,
        formatVersion: manifest.formatVersion,
        name: manifest.name,
        note: manifest.note.map { "\($0) [redacted profile: \(profile)]" } ?? "[redacted profile: \(profile)]",
        createdAt: manifest.createdAt,
        output: outputURL.path,
        artifacts: outputArtifacts,
        skipped: manifest.skipped,
        target: manifest.target,
        cli: manifest.cli,
        run: manifest.run
    )
    let summaryPath = outputURL.appendingPathComponent("summary.json").path
    let summary = TKEvidenceSummaryResponse(
        action: "evidence.summary",
        input: input,
        profile: profile,
        createdAt: manifest.createdAt,
        name: manifest.name,
        note: manifest.note,
        output: manifest.output,
        artifactCount: manifest.artifacts.count,
        sensitiveArtifactCount: redactedSummaries.count,
        skippedCount: manifest.skipped.count,
        target: manifest.target,
        cli: manifest.cli,
        artifacts: outputSummaries,
        primaryArtifacts: redactedManifest.primaryArtifacts,
        skipped: manifest.skipped,
        suggestedCommands: [
            "triton evidence summary \(shellQuotedEvidencePath(outputURL.path)) --profile \(profile) --json",
        ]
    )
    try prettyEncodedData(redactedManifest).write(to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
    try prettyEncodedData(summary).write(to: URL(fileURLWithPath: summaryPath), options: .atomic)
    return TKEvidenceRedactionResponse(
        action: "evidence.redact",
        input: input,
        output: outputURL.path,
        profile: profile,
        createdAt: manifest.createdAt,
        artifactCount: manifest.artifacts.count,
        redactedArtifactCount: redactedSummaries.count,
        keptArtifactCount: keptSummaries.count,
        manifest: redactedManifest,
        redactedArtifacts: redactedSummaries,
        keptArtifacts: keptSummaries,
        primaryArtifacts: redactedManifest.primaryArtifacts,
        summaryPath: summaryPath,
        suggestedCommands: [
            "triton evidence summary \(shellQuotedEvidencePath(outputURL.path)) --profile \(profile) --json",
            "triton evidence inspect \(shellQuotedEvidencePath(outputURL.path)) --json",
        ]
    )
}

func readReplayPlan(from path: String) throws -> TKReplayPlan {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let plan = try JSONDecoder().decode(TKReplayPlan.self, from: data)
    guard plan.schemaVersion == 1 else {
        throw RuntimeError("Unsupported replay plan schemaVersion: \(plan.schemaVersion)")
    }
    guard !plan.steps.isEmpty else {
        throw RuntimeError("Replay plan must contain at least one step")
    }
    return plan
}

func parseAssertBounds(_ raw: String) throws -> TKRect {
    try parseBounds(raw)
}

func parseBounds(_ raw: String) throws -> TKRect {
    let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard parts.count == 4,
          let x = Double(parts[0]),
          let y = Double(parts[1]),
          let width = Double(parts[2]),
          let height = Double(parts[3]),
          width >= 0,
          height >= 0 else {
        throw RuntimeError("--within must use x,y,width,height with non-negative width and height")
    }
    return TKRect(x: x, y: y, width: width, height: height)
}

func parsePoint(_ raw: String) throws -> (x: Double, y: Double) {
    let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard parts.count == 2,
          let x = Double(parts[0]),
          let y = Double(parts[1]) else {
        throw RuntimeError("--at must use x,y")
    }
    return (x, y)
}

func requiredPoint(
    at: String?,
    x: Double?,
    y: Double?,
    outputFormat: ClientOutputFormat
) throws -> (x: Double, y: Double) {
    if at != nil && (x != nil || y != nil) {
        if outputFormat == .json {
            try printValidationError("--at cannot be combined with --x/--y")
            throw ExitCode.failure
        }
        throw RuntimeError("--at cannot be combined with --x/--y")
    }
    if let at {
        return try parsePoint(at)
    }
    guard let x, let y else {
        if outputFormat == .json {
            try printValidationError("Provide coordinates as --at x,y or --x/--y")
            throw ExitCode.failure
        }
        throw RuntimeError("Provide coordinates as --at x,y or --x/--y")
    }
    return (x, y)
}

func inputFocusPoint(
    at: String?,
    x: Double?,
    y: Double?,
    outputFormat: ClientOutputFormat
) throws -> (x: Double, y: Double)? {
    if at != nil && (x != nil || y != nil) {
        if outputFormat == .json {
            try printValidationError("--at cannot be combined with --x/--y")
            throw ExitCode.failure
        }
        throw RuntimeError("--at cannot be combined with --x/--y")
    }
    if (x == nil) != (y == nil) {
        if outputFormat == .json {
            try printValidationError("--x and --y must be provided together")
            throw ExitCode.failure
        }
        throw RuntimeError("--x and --y must be provided together")
    }
    if let at {
        return try parsePoint(at)
    }
    return nil
}

func printAssertResult(_ result: TKUIAssertResult, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("condition: \(result.condition)")
        print("query: \(result.query)")
        if let role = result.role { print("role: \(role)") }
        print("count: \(result.count)")
        if let expectedCount = result.expectedCount { print("expectedCount: \(expectedCount)") }
        if let minCount = result.minCount { print("minCount: \(minCount)") }
        if let maxCount = result.maxCount { print("maxCount: \(maxCount)") }
        if let within = result.within { print("within: \(formatRect(within))") }
        if let targetConnectionState = result.targetConnectionState { print("targetConnectionState: \(targetConnectionState)") }
        if let hierarchyCacheState = result.hierarchyCacheState { print("hierarchyCacheState: \(hierarchyCacheState)") }
        if let message = result.message { print("message: \(message)") }
        if let nearestText = result.nearestText, !nearestText.isEmpty { print("nearestText: \(nearestText.joined(separator: ", "))") }
        if let suggestedCommands = result.suggestedCommands, !suggestedCommands.isEmpty {
            print("suggestedCommands: \(suggestedCommands.joined(separator: " | "))")
        }
    }
}

func parseReplayVariables(_ assignments: [String]) throws -> [String: String] {
    var result: [String: String] = [:]
    for assignment in assignments {
        guard let equals = assignment.firstIndex(of: "=") else {
            throw RuntimeError("Invalid --var assignment: \(assignment)")
        }
        let key = String(assignment[..<equals])
        let value = String(assignment[assignment.index(after: equals)...])
        guard !key.isEmpty else {
            throw RuntimeError("Invalid --var assignment with empty key")
        }
        if key.hasSuffix("-env") {
            let variableName = String(key.dropLast(4))
            guard !variableName.isEmpty else {
                throw RuntimeError("Invalid --var env assignment with empty key")
            }
            guard let envValue = ProcessInfo.processInfo.environment[value] else {
                throw RuntimeError("Environment variable is not set for replay variable \(variableName): \(value)")
            }
            result[variableName] = envValue
        } else {
            result[key] = value
        }
    }
    return result
}

func runReplayPlan(
    _ plan: TKReplayPlan,
    variables: [String: String],
    dryRun: Bool,
    target: String,
    host: String,
    port: Int
) async throws -> TKReplayResult {
    let start = Date()
    var steps: [TKReplayStepResult] = []
    var failedStepIndex: Int?
    let commands = try plan.steps.enumerated().map { offset, step in
        try replayCommand(for: step, plan: plan, index: offset + 1, variables: variables)
    }
    var client = TritonKitHTTPClient(host: host, port: port)

    if !dryRun {
        let resolved = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
        client = resolved.client
    }

    for (offset, step) in plan.steps.enumerated() {
        let index = offset + 1
        let command = commands[offset]
        if dryRun {
            steps.append(TKReplayStepResult(
                index: index,
                action: step.action.rawValue,
                name: step.name ?? step.id,
                ok: true,
                dryRun: true,
                elapsedMs: 0,
                command: command,
                message: "dry-run"
            ))
            continue
        }

        let stepStart = Date()
        do {
            let result = try await executeReplayStep(
                step,
                plan: plan,
                index: index,
                variables: variables,
                target: target,
                host: host,
                port: port,
                client: client,
                command: command,
                startedAt: stepStart
            )
            steps.append(result)
            if !result.ok {
                failedStepIndex = index
                break
            }
        } catch {
            failedStepIndex = index
            steps.append(replayFailureStepResult(
                step: step,
                index: index,
                command: command,
                error: error,
                startedAt: stepStart,
                host: host,
                port: port
            ))
            break
        }
    }

    return TKReplayResult(
        ok: failedStepIndex == nil,
        dryRun: dryRun,
        planName: plan.name,
        stepCount: plan.steps.count,
        executedCount: steps.count,
        failedStepIndex: failedStepIndex,
        failureCode: replayFailureCode(steps: steps, failedStepIndex: failedStepIndex),
        failureError: replayFailureError(steps: steps, failedStepIndex: failedStepIndex),
        failureWorkflowCategories: replayFailureWorkflowCategories(steps: steps, failedStepIndex: failedStepIndex),
        failureRecoveryCategories: replayFailureRecoveryCategories(steps: steps, failedStepIndex: failedStepIndex),
        failurePrimaryArtifacts: replayFailurePrimaryArtifacts(steps: steps, failedStepIndex: failedStepIndex),
        elapsedMs: elapsedMilliseconds(since: start),
        steps: steps,
        suggestedCommands: replaySuggestedCommands(
            steps: steps,
            failedStepIndex: failedStepIndex
        ),
        recoveryCommands: replayRecoveryCommands(
            steps: steps,
            failedStepIndex: failedStepIndex
        )
    )
}

func replayFailureWorkflowCategories(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [String] {
    guard let failedStepIndex else { return [] }
    return steps.first { $0.index == failedStepIndex }?.workflowCategories ?? []
}

func replayFailureCode(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> String? {
    guard let failedStepIndex else { return nil }
    return steps.first { $0.index == failedStepIndex }?.failureCode
}

func replayFailureError(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> TKCLIErrorDetail? {
    guard let failedStepIndex else { return nil }
    return steps.first { $0.index == failedStepIndex }?.error
}

func replayFailureRecoveryCategories(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [String] {
    guard let failureCode = replayFailureCode(steps: steps, failedStepIndex: failedStepIndex) else { return [] }
    let familyCategories = TKCommandRecoveryCommand.recoveryCategories(forFailureCode: failureCode)
    let recoveryCategories = replayRecoveryCommands(steps: steps, failedStepIndex: failedStepIndex).map(\.category)
    let nextActionCategory = replayFailureError(steps: steps, failedStepIndex: failedStepIndex)?.nextAction?.category

    if nextActionCategory == nil {
        return familyCategories
    }

    var categories: [String] = []
    var seen = Set<String>()

    func append(_ category: String?) {
        guard let category, !seen.contains(category) else { return }
        seen.insert(category)
        categories.append(category)
    }

    append(nextActionCategory)
    for category in recoveryCategories {
        append(category)
    }
    for category in familyCategories {
        append(category)
    }
    return categories
}

func replayFailurePrimaryArtifacts(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [TKEvidenceArtifactSummary] {
    TKReplayResult(
        ok: failedStepIndex == nil,
        dryRun: false,
        planName: nil,
        stepCount: steps.count,
        executedCount: steps.count,
        failedStepIndex: failedStepIndex,
        elapsedMs: 0,
        steps: steps
    ).failurePrimaryArtifacts
}

func replaySuggestedCommands(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [String] {
    guard let failedStepIndex,
          let failedStep = steps.first(where: { $0.index == failedStepIndex }) else { return [] }

    var commands: [String] = []

    if let nextActionCommand = replayFailureNextActionCommandString(steps: steps, failedStepIndex: failedStepIndex) {
        commands.append(nextActionCommand)
    }

    if let query = failedStep.wait?.query, !query.isEmpty {
        commands.append("triton find \(shellQuotedEvidencePath(query)) --all --json")
    }
    if failedStep.wait != nil {
        commands.append("triton snapshot --json")
    }
    if failedStep.input != nil {
        commands.append("triton snapshot --json")
        commands.append("triton screenshot --json")
    }
    if let evidence = failedStep.evidence {
        commands.append("triton evidence summary \(shellQuotedEvidencePath(evidence.output)) --json")
        commands.append("triton evidence inspect \(shellQuotedEvidencePath(evidence.output)) --json")
        commands.append("triton evidence redact \(shellQuotedEvidencePath(evidence.output)) --output \(shellQuotedEvidencePath(evidence.output + "-redacted")) --json")
    }
    if failedStep.evidence == nil,
       let recentEvidence = steps.reversed().compactMap(\.evidence).first {
        commands.append("triton evidence summary \(shellQuotedEvidencePath(recentEvidence.output)) --json")
        commands.append("triton evidence inspect \(shellQuotedEvidencePath(recentEvidence.output)) --json")
    }

    var unique: [String] = []
    var seen = Set<String>()
    for command in commands where !seen.contains(command) {
        seen.insert(command)
        unique.append(command)
    }
    return Array(unique.prefix(5))
}

func replayRecoveryCommands(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [TKCommandRecoveryCommand] {
    replaySuggestedCommands(steps: steps, failedStepIndex: failedStepIndex)
        .compactMap(TKCommandRecoveryCommand.init(commandString:))
}

func replayFailureNextActionCommandString(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> String? {
    guard let nextAction = replayFailureError(steps: steps, failedStepIndex: failedStepIndex)?.nextAction else {
        return nil
    }
    return (["triton", nextAction.command] + nextAction.args).joined(separator: " ")
}

func replayFailureStepResult(
    step: TKReplayPlanStep,
    index: Int,
    command: [String],
    error: Error,
    startedAt: Date,
    host: String,
    port: Int
) -> TKReplayStepResult {
    let detail = replayFailureDetail(for: step, error: error, host: host, port: port)
    return TKReplayStepResult(
        index: index,
        action: step.action.rawValue,
        name: step.name ?? step.id,
        ok: false,
        dryRun: false,
        elapsedMs: elapsedMilliseconds(since: startedAt),
        command: command,
        failureCode: detail.code,
        error: detail,
        message: detail.message
    )
}

func replayFailureDetail(
    for step: TKReplayPlanStep,
    error: Error,
    host: String,
    port: Int
) -> TKCLIErrorDetail {
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return response.error
    }
    if let timeoutError = error as? RuntimeRequestTimeoutError {
        return TKCLIErrorDetail(
            code: "timeout",
            message: timeoutError.description,
            endpoint: endpointURL(replayEndpoint(for: step.action), host: host, port: port),
            hint: "Run `triton snapshot --json` or retry the replay step after the runtime responds again."
        )
    }
    if isReplayArtifactWriteFailure(step: step, error: error) {
        return TKCLIErrorDetail(
            code: "artifact_write_failed",
            message: "\(error)",
            hint: "Check the replay output path, parent directory existence, and write permissions."
        )
    }
    return cliErrorDetail(
        for: error,
        endpoint: replayEndpoint(for: step.action),
        host: host,
        port: port
    )
}

func replayEndpoint(for action: TKReplayAction) -> String {
    switch action {
    case .tap, .paste, .type, .clear:
        return "/runtime/input"
    case .wait:
        return "/runtime/wait"
    case .screenshot:
        return "/runtime/screenshot"
    case .evidence:
        return "/evidence/capture"
    }
}

func isReplayArtifactWriteFailure(step: TKReplayPlanStep, error: Error) -> Bool {
    guard step.action == .screenshot || step.action == .evidence else { return false }
    guard let cocoaError = error as? CocoaError else { return false }
    switch cocoaError.code {
    case .fileNoSuchFile, .fileWriteNoPermission, .fileWriteInvalidFileName, .fileWriteFileExists, .fileWriteOutOfSpace:
        return true
    default:
        return false
    }
}

func executeReplayStep(
    _ step: TKReplayPlanStep,
    plan: TKReplayPlan,
    index: Int,
    variables: [String: String],
    target: String,
    host: String,
    port: Int,
    client: TritonKitHTTPClient,
    command: [String],
    startedAt: Date
) async throws -> TKReplayStepResult {
    switch step.action {
    case .tap:
        let request = try await replayTapRequest(step, variables: variables, client: client)
        let input = try await executeInputRequest(request, client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: input.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, input: input, host: host, port: port),
            message: input.message,
            input: input
        )
    case .paste, .type, .clear:
        let (request, redactedValue) = try replayTextInputRequest(step, variables: variables)
        let input = try await executeInputRequest(request, client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: input.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, input: input, host: host, port: port),
            message: input.message,
            redactedValue: redactedValue,
            input: input
        )
    case .wait:
        let wait = try await performWait(replayWaitRequest(step, variables: variables), client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: wait.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, wait: wait, host: host, port: port),
            message: wait.ok ? "matched" : "timed out",
            wait: wait
        )
    case .screenshot:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).png",
            variables: variables
        )
        let data = try await client.request(type: "screenshot")
        let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: data)
        let imageData = try await screenshotImageData(screenshot, client: client)
        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try imageData.write(to: outputURL, options: .atomic)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: true,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            message: "screenshot captured",
            file: TKReplayFileArtifact(path: outputURL.path, bytes: imageData.count, contentType: "image/png")
        )
    case .evidence:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).tritonevidence",
            variables: variables
        )
        let includes = try parseEvidenceIncludes(step.include ?? "status,list,version,hierarchy,ax,screenshot")
        let manifest = try await captureEvidenceBundle(
            output: output,
            includes: includes,
            name: step.name ?? plan.name,
            note: step.note,
            target: target,
            host: host,
            port: port,
            refresh: step.refresh ?? true
        )
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: manifest.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, evidence: manifest, host: host, port: port),
            message: "evidence captured",
            evidence: manifest
        )
    }
}

func replayStepError(
    for step: TKReplayPlanStep,
    input: TKInputResult? = nil,
    wait: TKWaitResult? = nil,
    evidence: TKEvidenceManifest? = nil,
    host: String,
    port: Int
) -> TKCLIErrorDetail? {
    if let input, !input.ok {
        return TKCLIErrorDetail(
            code: "action_failed",
            message: input.message ?? "Replay input step failed",
            endpoint: endpointURL(replayEndpoint(for: step.action), host: host, port: port),
            hint: "Run `triton input --json --summary --strict` or inspect the current UI with `triton snapshot --json`."
        )
    }
    if let wait, !wait.ok {
        let message: String
        if wait.timedOut {
            if let query = wait.query, !query.isEmpty {
                message = "Timed out waiting for \(wait.condition) '\(query)'"
            } else {
                message = "Timed out waiting for \(wait.condition)"
            }
        } else {
            message = "Replay wait step failed"
        }
        return TKCLIErrorDetail(
            code: wait.timedOut ? "timeout" : "request_failed",
            message: message,
            endpoint: endpointURL(replayEndpoint(for: step.action), host: host, port: port),
            hint: "Run `triton wait --format json` with a narrower condition or inspect the current UI with `triton snapshot --json`."
        )
    }
    if let evidence, !evidence.ok {
        return TKCLIErrorDetail(
            code: "request_failed",
            message: "Replay evidence step reported ok=false for \(evidence.output)",
            hint: "Inspect the evidence output path and rerun `triton evidence summary \(shellQuotedEvidencePath(evidence.output)) --json` if artifacts were partially written."
        )
    }
    return nil
}

func replayTapRequest(
    _ step: TKReplayPlanStep,
    variables: [String: String],
    client: TritonKitHTTPClient
) async throws -> TKInputRequest {
    let selectorCount = [
        step.text != nil,
        step.oid != nil,
        step.x != nil || step.y != nil,
        step.axOID != nil,
        step.axLabel != nil,
    ].filter { $0 }.count
    guard selectorCount == 1 else {
        throw RuntimeError("Replay tap step requires exactly one selector: text, oid, x/y, axOID, or axLabel")
    }
    if (step.x == nil) != (step.y == nil) {
        throw RuntimeError("Replay tap step requires x and y together")
    }
    if let text = step.text {
        let query = try TKReplaySubstituteVariables(text, variables: variables)
        return try await resolveTapTarget(
            query,
            client: client,
            width: step.width,
            height: step.height,
            duration: step.duration
        ).request
    }
    if step.axOID != nil || step.axLabel != nil {
        let data = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
        let label = try step.axLabel.map { try TKReplaySubstituteVariables($0, variables: variables) }
        guard let node = selectAXNode(nodes, oid: step.axOID, label: label) else {
            throw RuntimeError("AX node not found for replay tap step")
        }
        return tapRequest(for: node, width: step.width, height: step.height, duration: step.duration)
    }
    return TKInputRequest.tap(
        x: step.x,
        y: step.y,
        targetOID: step.oid,
        width: step.width,
        height: step.height,
        duration: step.duration
    )
}

func replayTextInputRequest(
    _ step: TKReplayPlanStep,
    variables: [String: String]
) throws -> (request: TKInputRequest, redactedValue: String?) {
    try validateReplayXYPair(step)
    switch step.action {
    case .paste:
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay paste step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        return (
            TKInputRequest.paste(value, targetOID: step.oid, x: step.x, y: step.y, secure: step.secure ?? false),
            step.redactedValue(substitutedValue: value)
        )
    case .type:
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay type step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        return (
            TKInputRequest(type: .typeText, targetOID: step.oid, text: value, secure: step.secure),
            step.redactedValue(substitutedValue: value)
        )
    case .clear:
        return (TKInputRequest.clear(targetOID: step.oid, x: step.x, y: step.y), nil)
    default:
        throw RuntimeError("Replay text input builder received unsupported action: \(step.action.rawValue)")
    }
}

func replayWaitRequest(_ step: TKReplayPlanStep, variables: [String: String]) throws -> WaitRequest {
    let conditionCount = [
        step.text != nil,
        step.gone != nil,
        step.exists != nil,
        step.idle == true,
        step.hierarchyChange == true,
        step.predicate != nil,
    ].filter { $0 }.count
    guard conditionCount == 1 else {
        throw RuntimeError("Replay wait step requires exactly one condition: text, gone, exists, idle, hierarchyChange, or predicate")
    }
    guard let condition = step.waitCondition else {
        throw RuntimeError("Replay wait step requires one condition: text, gone, exists, idle, hierarchyChange, or predicate")
    }
    switch condition {
    case .text:
        return WaitRequest(
            condition: .text,
            query: try step.text.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .gone:
        return WaitRequest(
            condition: .gone,
            query: try step.gone.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .exists:
        return WaitRequest(
            condition: .exists,
            query: try step.exists.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .idle:
        return WaitRequest(condition: .idle, query: nil, predicate: nil, role: nil, timeout: step.timeout ?? 10, interval: step.interval ?? 0.5)
    case .hierarchyChange:
        return WaitRequest(condition: .hierarchyChange, query: nil, predicate: nil, role: nil, timeout: step.timeout ?? 10, interval: step.interval ?? 0.5)
    case .predicate:
        return WaitRequest(
            condition: .predicate,
            query: nil,
            predicate: try step.predicate.map { try TKReplaySubstituteVariables($0, variables: variables) },
            role: nil,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    }
}

func replayCommand(
    for step: TKReplayPlanStep,
    plan: TKReplayPlan,
    index: Int,
    variables: [String: String]
) throws -> [String] {
    try TKReplayStepExecution.argv(for: step, planName: plan.name, index: index, variables: variables)
}

func validateReplayXYPair(_ step: TKReplayPlanStep) throws {
    if (step.x == nil) != (step.y == nil) {
        throw RuntimeError("Replay \(step.action.rawValue) step requires x and y together")
    }
}

func replayOutputPath(_ raw: String?, fallback: String, variables: [String: String]) throws -> String {
    try TKReplaySubstituteVariables(raw ?? fallback, variables: variables)
}

func replayArtifactName(plan: TKReplayPlan, step: TKReplayPlanStep, index: Int) -> String {
    TKReplayStepExecution.artifactName(planName: plan.name, step: step, index: index)
}

func sanitizedPathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    let scalars = value.unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
    return collapsed.isEmpty ? "triton-replay" : collapsed
}

func failReplayValidation(_ message: String, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Run `triton schema --command replay --json` to inspect required fields"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}

func failRegressionValidation(_ message: String, command: String, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Run `triton schema --command \(command) --json` to inspect required fields"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}

func printEvidenceManifest(_ manifest: TKEvidenceManifest, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(manifest))
    case .text:
        print("ok: \(manifest.ok)")
        print("output: \(manifest.output)")
        if let name = manifest.name { print("name: \(name)") }
        print("artifacts: \(manifest.artifacts.count)")
        if !manifest.skipped.isEmpty {
            print("skipped: \(manifest.skipped.count)")
            for item in manifest.skipped {
                print("- \(item.kind): \(item.reason)")
            }
        }
    }
}

func printEvidenceSummary(_ summary: TKEvidenceSummaryResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(summary))
    case .text:
        print("ok: \(summary.ok)")
        print("input: \(summary.input)")
        print("profile: \(summary.profile)")
        print("artifacts: \(summary.artifactCount)")
        print("sensitiveArtifacts: \(summary.sensitiveArtifactCount)")
        print("skipped: \(summary.skippedCount)")
    }
}

func printEvidenceRedaction(_ redaction: TKEvidenceRedactionResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(redaction))
    case .text:
        print("ok: \(redaction.ok)")
        print("output: \(redaction.output)")
        print("profile: \(redaction.profile)")
        print("redactedArtifacts: \(redaction.redactedArtifactCount)")
        print("keptArtifacts: \(redaction.keptArtifactCount)")
    }
}

func evidenceArtifactSummary(_ artifact: TKEvidenceArtifact) -> TKEvidenceArtifactSummary {
    TKEvidenceArtifactSummary(
        kind: artifact.kind,
        path: artifact.path,
        contentType: artifact.contentType,
        bytes: artifact.bytes,
        platform: artifact.platform,
        riskLevel: artifact.riskLevel,
        policy: artifact.policy,
        redactionStatus: artifact.redactionStatus,
        target: artifact.target
    )
}

func evidenceArtifactIsSensitive(_ artifact: TKEvidenceArtifact) -> Bool {
    let sensitiveKinds: Set<String> = ["screenshot", "ax", "hierarchy", "geometry", "archive", "logs"]
    return sensitiveKinds.contains(artifact.kind)
        || artifact.kind.hasPrefix("host.")
        || artifact.kind.hasPrefix("xcode.")
        || artifact.path.hasSuffix(".log")
        || artifact.path.hasSuffix(".xcresult")
        || artifact.path.hasSuffix(".trace")
}

func sanitizedEvidencePathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    let scalars = value.unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
    return collapsed.isEmpty ? "evidence" : collapsed
}

func shellQuotedEvidencePath(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func captureEvidenceBundle(
    output: String,
    includes: [String],
    name: String?,
    note: String?,
    target: String,
    host: String,
    port: Int,
    refresh: Bool,
    xcodeSummaryPath: String? = nil,
    hostXcodeProviders: EvidenceHostXcodeArtifactProviders = .live
) async throws -> TKEvidenceManifest {
    let outputURL = URL(fileURLWithPath: output)
    try prepareEvidenceOutputDirectory(outputURL)

    var client = TritonKitHTTPClient(host: host, port: port)
    let startedAt = ISO8601DateFormatter().string(from: Date())
    var artifacts: [TKEvidenceArtifact] = []
    var skipped: [TKEvidenceSkippedArtifact] = []
    var status: TKStatusResponse?
    var targetSummary: TKTargetSummary?

    for kind in includes {
        switch kind {
        case "version":
            do {
                let version = TKCLIVersionResponse(version: TritonKitBuildInfo.cliVersion, language: "en")
                let data = try prettyEncodedData(version)
                try appendEvidenceArtifact(
                    kind: "version",
                    relativePath: "version.json",
                    data: data,
                    contentType: "application/json",
                    directory: outputURL,
                    freshness: evidenceFreshness(source: "cli", status: status),
                    artifacts: &artifacts
                )
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        case "status":
            do {
                let data = try await client.getData("/status")
                status = try JSONDecoder().decode(TKStatusResponse.self, from: data)
                try appendEvidenceArtifact(
                    kind: "status",
                    relativePath: "status.json",
                    data: try prettyJSONData(data),
                    contentType: "application/json",
                    directory: outputURL,
                    freshness: evidenceFreshness(source: "server", status: status),
                    artifacts: &artifacts
                )
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        case "list":
            do {
                let data = try await client.getData("/targets")
                let targets = try JSONDecoder().decode(TKTargetsResponse.self, from: data)
                if targetSummary == nil {
                    targetSummary = try? TKResolveTargetSummary(target, in: targets.targets)
                }
                try appendEvidenceArtifact(
                    kind: "list",
                    relativePath: "targets.json",
                    data: try prettyJSONData(data),
                    contentType: "application/json",
                    directory: outputURL,
                    freshness: evidenceFreshness(source: "server", status: status),
                    artifacts: &artifacts
                )
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        case "logs":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "unsupported in the current embedded runtime"))
        case "host":
            appendHostEvidenceArtifacts(
                directory: outputURL,
                providers: hostXcodeProviders,
                artifacts: &artifacts,
                skipped: &skipped
            )
        case "xcode":
            appendXcodeEvidenceArtifacts(
                directory: outputURL,
                providers: hostXcodeProviders,
                xcodeSummaryPath: xcodeSummaryPath,
                artifacts: &artifacts,
                skipped: &skipped
            )
        case "hierarchy", "ax", "geometry", "screenshot", "archive":
            do {
                if targetSummary == nil {
                    let resolved = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
                    targetSummary = resolved.summary
                    client = resolved.client
                }
                switch kind {
                case "hierarchy":
                    let data = try await evidenceHierarchyData(client: client, refresh: refresh)
                    try appendEvidenceArtifact(
                        kind: "hierarchy",
                        relativePath: "hierarchy.json",
                        data: try prettyJSONData(data),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: refresh ? "runtime" : "server-cache", status: status),
                        artifacts: &artifacts
                    )
                case "ax":
                    let data = try await client.request(type: "accessibility")
                    try appendEvidenceArtifact(
                        kind: "ax",
                        relativePath: "ax.json",
                        data: try prettyJSONData(data),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: "runtime", status: status),
                        artifacts: &artifacts
                    )
                case "geometry":
                    let data = try await client.request(type: "geometry")
                    try appendEvidenceArtifact(
                        kind: "geometry",
                        relativePath: "geometry.json",
                        data: try prettyJSONData(data),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: "runtime", status: status),
                        artifacts: &artifacts
                    )
                case "screenshot":
                    try await captureEvidenceScreenshot(
                        client: client,
                        directory: outputURL,
                        status: status,
                        artifacts: &artifacts
                    )
                case "archive":
                    let hierarchyData = try await evidenceHierarchyData(client: client, refresh: refresh)
                    let archive = try await buildExportArchive(
                        target: targetSummary ?? TKTargetSummary(connected: true, latestHierarchyAvailable: true),
                        hierarchyData: hierarchyData,
                        client: client
                    )
                    try appendEvidenceArtifact(
                        kind: "archive",
                        relativePath: "archive.json",
                        data: try prettyEncodedData(archive),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: "runtime", status: status),
                        artifacts: &artifacts
                    )
                default:
                    break
                }
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        default:
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "unsupported"))
        }
    }

    let manifest = TKEvidenceManifest(
        ok: true,
        name: name,
        note: note,
        createdAt: startedAt,
        output: outputURL.path,
        artifacts: artifacts,
        skipped: skipped,
        target: targetSummary.map { summary in
            TKEvidenceTarget(
                id: summary.id,
                connected: summary.connected,
                appName: summary.appName,
                bundleIdentifier: summary.bundleIdentifier,
                deviceDescription: summary.deviceDescription,
                osDescription: summary.osDescription,
                identityState: summary.identityState ?? "unknown",
                targetConnectionState: status?.targetConnectionState ?? (summary.connected ? "connected" : "disconnected"),
                hierarchyCacheState: summary.hierarchyCacheState ?? status?.hierarchyCacheState
            )
        },
        cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion)
    )
    try prettyEncodedData(manifest).write(to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
    return manifest
}

func prepareEvidenceOutputDirectory(_ url: URL) throws {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw RuntimeError("Evidence output exists and is not a directory: \(url.path)")
        }
    } else {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}

func appendEvidenceArtifact(
    kind: String,
    relativePath: String,
    data: Data,
    contentType: String,
    directory: URL,
    freshness: TKEvidenceFreshness,
    artifacts: inout [TKEvidenceArtifact],
    platform: String? = nil,
    riskLevel: String? = nil,
    policy: String? = nil,
    redactionStatus: String? = nil,
    sourceCommand: String? = nil,
    target: String? = nil
) throws {
    let fileURL = directory.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: fileURL, options: .atomic)
    artifacts.append(TKEvidenceArtifact(
        kind: kind,
        path: relativePath,
        contentType: contentType,
        bytes: data.count,
        freshness: freshness,
        platform: platform,
        riskLevel: riskLevel,
        policy: policy,
        redactionStatus: redactionStatus,
        sourceCommand: sourceCommand,
        target: target
    ))
}

func appendHostEvidenceArtifacts(
    directory: URL,
    providers: EvidenceHostXcodeArtifactProviders,
    artifacts: inout [TKEvidenceArtifact],
    skipped: inout [TKEvidenceSkippedArtifact]
) {
    do {
        if let defaults = try providers.loadDefaults() {
            try appendEvidenceArtifact(
                kind: "host.defaults",
                relativePath: "artifacts/host/defaults.json",
                data: try prettyEncodedData(defaults),
                contentType: "application/json",
                directory: directory,
                freshness: evidenceFreshness(source: "host", status: nil),
                artifacts: &artifacts,
                platform: "host",
                riskLevel: "readonly",
                policy: "read-only-small-artifact",
                redactionStatus: "sensitive",
                sourceCommand: "read .triton/host-defaults.json"
            )
        } else {
            skipped.append(TKEvidenceSkippedArtifact(kind: "host.defaults", reason: "host defaults are not configured"))
        }
    } catch {
        skipped.append(TKEvidenceSkippedArtifact(kind: "host.defaults", reason: evidenceSkipReason(error)))
    }

    do {
        let payload = try providers.simulatorList()
        try appendEvidenceArtifact(
            kind: "host.simulators",
            relativePath: "artifacts/host/simulators.json",
            data: payload.data,
            contentType: payload.contentType,
            directory: directory,
            freshness: evidenceFreshness(source: "host", status: nil),
            artifacts: &artifacts,
            platform: "host",
            riskLevel: "readonly",
            policy: "read-only-small-artifact",
            redactionStatus: "sensitive",
            sourceCommand: payload.sourceCommand
        )
    } catch {
        skipped.append(TKEvidenceSkippedArtifact(kind: "host.simulators", reason: evidenceSkipReason(error)))
    }
}

func appendXcodeEvidenceArtifacts(
    directory: URL,
    providers: EvidenceHostXcodeArtifactProviders,
    xcodeSummaryPath: String?,
    artifacts: inout [TKEvidenceArtifact],
    skipped: inout [TKEvidenceSkippedArtifact]
) {
    do {
        if let xcode = try providers.loadDefaults()?.xcode {
            try appendEvidenceArtifact(
                kind: "xcode.defaults",
                relativePath: "artifacts/xcode/defaults.json",
                data: try prettyEncodedData(xcode),
                contentType: "application/json",
                directory: directory,
                freshness: evidenceFreshness(source: "host", status: nil),
                artifacts: &artifacts,
                platform: "xcode",
                riskLevel: "readonly",
                policy: "read-only-small-artifact",
                redactionStatus: "sensitive",
                sourceCommand: "read .triton/host-defaults.json"
            )
        } else {
            skipped.append(TKEvidenceSkippedArtifact(kind: "xcode.defaults", reason: "xcode defaults are not configured"))
        }
    } catch {
        skipped.append(TKEvidenceSkippedArtifact(kind: "xcode.defaults", reason: evidenceSkipReason(error)))
    }

    if let xcodeSummaryPath, !xcodeSummaryPath.isEmpty {
        appendXcodeActionSummaryArtifact(
            path: xcodeSummaryPath,
            directory: directory,
            artifacts: &artifacts,
            skipped: &skipped
        )
    }

    do {
        let payload = try providers.xcodeStatus()
        try appendEvidenceArtifact(
            kind: "xcode.status",
            relativePath: "artifacts/xcode/status.json",
            data: payload.data,
            contentType: payload.contentType,
            directory: directory,
            freshness: evidenceFreshness(source: "host", status: nil),
            artifacts: &artifacts,
            platform: "xcode",
            riskLevel: "readonly",
            policy: "read-only-small-artifact",
            redactionStatus: "sensitive",
            sourceCommand: payload.sourceCommand
        )
    } catch {
        skipped.append(TKEvidenceSkippedArtifact(kind: "xcode.status", reason: evidenceSkipReason(error)))
    }

    do {
        let payload = try providers.xcodeDiscovery()
        try appendEvidenceArtifact(
            kind: "xcode.discovery",
            relativePath: "artifacts/xcode/discovery.json",
            data: payload.data,
            contentType: payload.contentType,
            directory: directory,
            freshness: evidenceFreshness(source: "host", status: nil),
            artifacts: &artifacts,
            platform: "xcode",
            riskLevel: "readonly",
            policy: "read-only-small-artifact",
            redactionStatus: "sensitive",
            sourceCommand: payload.sourceCommand
        )
    } catch {
        skipped.append(TKEvidenceSkippedArtifact(kind: "xcode.discovery", reason: evidenceSkipReason(error)))
    }
}

func appendXcodeActionSummaryArtifact(
    path: String,
    directory: URL,
    artifacts: inout [TKEvidenceArtifact],
    skipped: inout [TKEvidenceSkippedArtifact]
) {
    do {
        let summaryURL = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: summaryURL)
        let summary = try JSONDecoder().decode(TKXcodeActionSummary.self, from: data)
        try appendEvidenceArtifact(
            kind: "xcode.action-summary",
            relativePath: "artifacts/xcode/action-summary.json",
            data: try prettyEncodedData(summary),
            contentType: "application/json",
            directory: directory,
            freshness: evidenceFreshness(source: "host", status: nil),
            artifacts: &artifacts,
            platform: "xcode",
            riskLevel: "readonly",
            policy: "explicit-xcode-summary",
            redactionStatus: "sensitive",
            sourceCommand: "read --xcode-summary"
        )
    } catch {
        let reason = TKXcresultRedaction.redact(evidenceSkipReason(error))
        skipped.append(TKEvidenceSkippedArtifact(kind: "xcode.action-summary", reason: reason))
    }
}

func captureEvidenceScreenshot(
    client: TritonKitHTTPClient,
    directory: URL,
    status: TKStatusResponse?,
    artifacts: inout [TKEvidenceArtifact]
) async throws {
    let screenshotData = try await client.request(type: "screenshot")
    let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
    let imageData = try await screenshotImageData(screenshot, client: client)
    let freshness = evidenceFreshness(source: "runtime", status: status)
    try appendEvidenceArtifact(
        kind: "screenshot",
        relativePath: "screenshot.png",
        data: imageData,
        contentType: "image/png",
        directory: directory,
        freshness: freshness,
        artifacts: &artifacts
    )
    let metadata = EvidenceScreenshotMetadata(
        format: screenshot.format,
        width: screenshot.width,
        height: screenshot.height,
        scale: screenshot.scale,
        dataRef: screenshot.dataRef,
        imagePath: "screenshot.png",
        bytes: imageData.count
    )
    try appendEvidenceArtifact(
        kind: "screenshot-metadata",
        relativePath: "screenshot.json",
        data: try prettyEncodedData(metadata),
        contentType: "application/json",
        directory: directory,
        freshness: freshness,
        artifacts: &artifacts
    )
}

func evidenceHierarchyData(client: TritonKitHTTPClient, refresh: Bool) async throws -> Data {
    if refresh {
        return try await client.request(type: "hierarchy")
    }
    return try await waitForHierarchy(client: client)
}

func evidenceFreshness(source: String, status: TKStatusResponse?) -> TKEvidenceFreshness {
    TKEvidenceFreshness(
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        source: source,
        hierarchyCacheState: status?.hierarchyCacheState,
        targetConnectionState: status?.targetConnectionState
    )
}

func evidenceSkipReason(_ error: Error) -> String {
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return "\(response.error.code): \(response.error.message)"
    }
    return "\(error)"
}

func prettyEncodedData<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
}

func prettyJSONData(_ data: Data) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: data)
    return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
}

func runInputRequest(
    _ request: TKInputRequest,
    host: String,
    port: Int,
    format: ClientOutputFormat
) async throws {
    try await runInputRequest(
        request,
        client: TritonKitHTTPClient(host: host, port: port),
        format: format
    )
}

func runInputRequest(
    _ request: TKInputRequest,
    client: TritonKitHTTPClient,
    format: ClientOutputFormat
) async throws {
    let result = try await executeInputRequest(request, client: client)
    try printInputResult(result, format: format)
    if !result.ok {
        throw RuntimeError(result.message ?? "Input request failed")
    }
}

func printInputResult(_ result: TKInputResult, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeCompactJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("action: \(result.action)")
        if let message = result.message {
            print("message: \(message)")
        }
        if let targetOID = result.targetOID {
            print("targetOID: \(targetOID)")
        }
        if let targetClassName = result.targetClassName {
            print("targetClassName: \(targetClassName)")
        }
        if let matchedOID = result.matchedOID {
            print("matchedOID: \(matchedOID)")
        }
        if let matchedClassName = result.matchedClassName {
            print("matchedClassName: \(matchedClassName)")
        }
        if let activationOID = result.activationOID {
            print("activationOID: \(activationOID)")
        }
        if let activationClassName = result.activationClassName {
            print("activationClassName: \(activationClassName)")
        }
        if let strategy = result.strategy {
            print("strategy: \(strategy)")
        }
        if let secure = result.secure {
            print("secure: \(secure)")
        }
        if let redacted = result.redacted {
            print("redacted: \(redacted)")
        }
        if let insertedLength = result.insertedLength {
            print("insertedLength: \(insertedLength)")
        }
    }
}
