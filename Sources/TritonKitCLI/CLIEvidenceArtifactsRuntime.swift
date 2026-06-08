import Foundation
import TritonKitShared

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
    let sensitiveKinds: Set<String> = ["screenshot", "ax", "hierarchy", "geometry", "archive", "logs", "real-device.diagnostics", "runtime.snapshot", "build.summary"]
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
