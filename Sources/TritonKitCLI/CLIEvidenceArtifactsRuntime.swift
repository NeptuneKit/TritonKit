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
        scope: artifact.scope,
        source: artifact.source,
        fidelity: artifact.fidelity,
        platform: artifact.platform,
        riskLevel: artifact.riskLevel,
        policy: artifact.policy,
        redactionStatus: artifact.redactionStatus,
        target: artifact.target
    )
}

func evidenceArtifactIsSensitive(_ artifact: TKEvidenceArtifact) -> Bool {
    let sensitiveKinds: Set<String> = [
        "screenshot",
        "ax",
        "hierarchy",
        "geometry",
        "archive",
        "logs",
        "real-device.diagnostics",
        "runtime.snapshot",
        "build.summary",
        "network.proxy-session",
        "network-capture",
        "proxy-restore",
    ]
    return sensitiveKinds.contains(artifact.kind)
        || artifact.kind.hasPrefix("screenshot")
        || artifact.kind.hasPrefix("host.")
        || artifact.kind.hasPrefix("xcode.")
        || artifact.path.hasSuffix(".log")
        || artifact.path.hasSuffix(".xcresult")
        || artifact.path.hasSuffix(".trace")
}

func sanitizedEvidencePathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
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
    scope: String? = nil,
    source: String? = nil,
    fidelity: String? = nil,
    platform: String? = nil,
    riskLevel: String? = nil,
    policy: String? = nil,
    redactionStatus: String? = nil,
    sourceCommand: String? = nil,
    metadata: [String: TKJSONValue]? = nil,
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
        scope: scope,
        source: source,
        fidelity: fidelity,
        freshness: freshness,
        platform: platform,
        riskLevel: riskLevel,
        policy: policy,
        redactionStatus: redactionStatus,
        sourceCommand: sourceCommand,
        metadata: metadata,
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

func appendNetworkProxySessionEvidenceArtifacts(
    sessionPath: String?,
    directory: URL,
    artifacts: inout [TKEvidenceArtifact],
    skipped: inout [TKEvidenceSkippedArtifact]
) {
    guard let sessionPath, !sessionPath.isEmpty else {
        skipped.append(TKEvidenceSkippedArtifact(kind: "network.proxy-session", reason: "no proxy session directory was provided"))
        return
    }

    do {
        let sessionURL = URL(fileURLWithPath: sessionPath, isDirectory: true)
        let state = try loadNetworkProxySessionState(directory: sessionPath)
        try appendEvidenceArtifact(
            kind: "network.proxy-session",
            relativePath: "artifacts/network/session-state.json",
            data: try prettyEncodedData(state),
            contentType: "application/json",
            directory: directory,
            freshness: evidenceFreshness(source: "host-proxy", status: nil),
            artifacts: &artifacts,
            platform: state.platform,
            riskLevel: "readonly",
            policy: "explicit-proxy-session",
            redactionStatus: "sensitive",
            sourceCommand: "read --proxy-session",
            target: state.target.isEmpty ? nil : state.target
        )

        if let capture = state.artifacts.first(where: { $0.kind == "network-capture" }) {
            let captureURL = networkProxyArtifactURL(path: capture.path, sessionURL: sessionURL)
            do {
                let captureData = try Data(contentsOf: captureURL)
                try appendEvidenceArtifact(
                    kind: "network-capture",
                    relativePath: "artifacts/network/requests.ndjson",
                    data: captureData,
                    contentType: "application/x-ndjson",
                    directory: directory,
                    freshness: evidenceFreshness(source: "host-proxy", status: nil),
                    artifacts: &artifacts,
                    platform: state.platform,
                    riskLevel: "readonly",
                    policy: "host-proxy-metadata-capture",
                    redactionStatus: "sensitive",
                    sourceCommand: "read --proxy-session",
                    target: state.target.isEmpty ? nil : state.target
                )
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: "network-capture", reason: evidenceSkipReason(error)))
            }
        } else {
            skipped.append(TKEvidenceSkippedArtifact(kind: "network-capture", reason: "proxy session did not declare a network-capture artifact"))
        }

        appendNetworkProxyRestoreFailureEvidenceArtifact(
            state: state,
            sessionURL: sessionURL,
            directory: directory,
            artifacts: &artifacts,
            skipped: &skipped
        )
    } catch {
        skipped.append(TKEvidenceSkippedArtifact(kind: "network.proxy-session", reason: evidenceSkipReason(error)))
    }
}

private func appendNetworkProxyRestoreFailureEvidenceArtifact(
    state: NetworkProxySessionStatePayload,
    sessionURL: URL,
    directory: URL,
    artifacts: inout [TKEvidenceArtifact],
    skipped: inout [TKEvidenceSkippedArtifact]
) {
    guard let restoreURL = networkProxyRestoreFailureArtifactURL(state: state, sessionURL: sessionURL) else {
        return
    }
    do {
        let data = try Data(contentsOf: restoreURL)
        let payload = try? JSONDecoder().decode(NetworkProxyRestoreFailurePayload.self, from: data)
        let platform = payload?.platform ?? state.platform
        let target = payload?.target ?? state.target
        try appendEvidenceArtifact(
            kind: "proxy-restore",
            relativePath: "artifacts/network/restore-failure.json",
            data: data,
            contentType: "application/json",
            directory: directory,
            freshness: evidenceFreshness(source: "host-proxy", status: nil),
            artifacts: &artifacts,
            platform: platform.isEmpty ? nil : platform,
            riskLevel: "readonly",
            policy: "proxy-restore-failure-recovery",
            redactionStatus: "sensitive",
            sourceCommand: "read --proxy-session",
            target: target.isEmpty ? nil : target
        )
    } catch {
        skipped.append(TKEvidenceSkippedArtifact(kind: "proxy-restore", reason: evidenceSkipReason(error)))
    }
}

private func networkProxyRestoreFailureArtifactURL(
    state: NetworkProxySessionStatePayload,
    sessionURL: URL
) -> URL? {
    var candidates: [URL] = []
    for artifact in state.artifacts where artifact.kind == "proxy-restore" {
        candidates.append(networkProxyArtifactURL(path: artifact.path, sessionURL: sessionURL))
    }
    if let restoreSnapshotPath = state.restoreSnapshotPath, !restoreSnapshotPath.isEmpty {
        candidates.append(URL(fileURLWithPath: restoreSnapshotPath).deletingLastPathComponent().appendingPathComponent("restore-failure.json"))
    }
    candidates.append(sessionURL.appendingPathComponent("restore-failure.json"))

    var seen = Set<String>()
    for candidate in candidates where seen.insert(candidate.path).inserted {
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
    }
    return nil
}

private func networkProxyArtifactURL(path: String, sessionURL: URL) -> URL {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path)
    }
    return sessionURL.appendingPathComponent(path)
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
