import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

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
        "real-device.diagnostics",
        "host.app-action",
        "runtime.snapshot",
        "host.layout",
        "build.summary",
        "network.proxy-session",
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
