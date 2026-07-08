import CryptoKit
import Foundation
import TritonKitShared

typealias TKWorkspaceLiveObserveProvider = (TKWorkspaceLiveObserveRequest) async throws -> ObserveOutput

struct TKWorkspaceLiveObserveRequest: Equatable {
    let action: String
    let kind: String
    let platform: ObservationPlatform
    let target: String
    let hdc: String
    let host: String
    let port: Int
    let runtimeBaseURL: String?
    let maxNodes: Int?
    let output: String?
}

struct TKWorkspaceObservationSeed {
    let fixturePath: String?
    let fixtureRef: String?
    let rawObservationData: Data?
    let artifacts: TKTestRunObservationArtifacts
    let screenCandidate: TKTestRunScreenCandidate
    let sourceCommands: [String]
    let changed: Bool?
}

private struct TKWorkspaceObservationFixture: Codable {
    let schemaVersion: Int?
    let kind: String?
    let artifacts: TKTestRunObservationArtifacts
    let screenCandidate: TKTestRunScreenCandidate
    let sourceCommands: [String]?
    let changed: Bool?
}

private struct TKWorkspaceObserveOutputFixture: Codable {
    let action: String?
    let primarySource: TKWorkspaceObserveSourceFixture?
    let sources: [TKWorkspaceObserveSourceFixture]?
    let nodes: [ObserveNodeOutput]
    let artifacts: [String]?
    let sourceCommands: [String]?
}

private struct TKWorkspaceObserveSourceFixture: Codable {
    let name: String
    let available: Bool
    let reason: String?
    let artifact: String?
    let sourceCommands: [String]
}

func workspaceObservationSeed(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceObservationSeed {
    if request.observeLive {
        throw RuntimeError("Live workspace observation requires the async workspace runtime.")
    }
    return try workspaceObservationSeed(fixturePath: request.observationFixture)
}

func workspaceObservationSeed(
    for request: TKWorkspaceRunRequest,
    observeProvider: TKWorkspaceLiveObserveProvider
) async throws -> TKWorkspaceObservationSeed {
    try await workspaceInitialObservationSeed(for: request, observeProvider: observeProvider)
}

func workspaceInitialObservationSeed(
    for request: TKWorkspaceRunRequest,
    observeProvider: TKWorkspaceLiveObserveProvider
) async throws -> TKWorkspaceObservationSeed {
    if workspaceHasObservationFixture(request.observationFixture) {
        return try workspaceObservationSeed(fixturePath: request.observationFixture)
    }
    if request.observeLive {
        return try await workspaceLiveObservationSeed(for: request, observeProvider: observeProvider)
    }
    return try workspaceObservationSeed(fixturePath: request.observationFixture)
}

func workspacePostActionObservationSeed(
    for request: TKWorkspaceRunRequest,
    observeProvider: TKWorkspaceLiveObserveProvider
) async throws -> TKWorkspaceObservationSeed? {
    guard request.observeLive else { return nil }
    return try await workspaceLiveObservationSeed(for: request, observeProvider: observeProvider)
}

func workspaceDefaultLiveObserveProvider(_ request: TKWorkspaceLiveObserveRequest) async throws -> ObserveOutput {
    let resolved = try resolveObservationTarget(
        device: request.target == "current" ? nil : request.target,
        platform: request.platform,
        target: TKLocalTargetID,
        hdc: request.hdc,
        runtimeBaseURL: request.runtimeBaseURL
    )
    switch resolved.platform {
    case .harmony:
        return try await observeHarmony(
            action: request.action,
            target: resolved.target,
            hdc: request.hdc,
            runtimeBaseURL: request.runtimeBaseURL,
            maxNodes: request.maxNodes,
            output: request.output
        )
    case .android:
        guard let hostTarget = resolved.hostTarget else {
            throw RuntimeError("Android live observation requires a resolved host target.")
        }
        return try observeAndroid(
            action: request.action,
            selected: hostTarget,
            adb: "adb",
            output: request.output
        )
    case .ios:
        return try await observeIOS(
            action: request.action,
            target: resolved.target,
            host: request.host,
            port: request.port,
            runtimeBaseURL: request.runtimeBaseURL,
            maxNodes: request.maxNodes,
            iosHostAX: usesIOSHostSimulatorAX(resolved.hostTarget)
        )
    }
}

func writeWorkspaceObservationEvidence(
    _ observation: TKWorkspaceObservationSeed,
    runDir: URL,
    index: Int
) throws {
    let observationURL = runDir.appendingPathComponent(workspaceObservationEvidenceRef(index: index))
    if let rawObservationData = observation.rawObservationData {
        try rawObservationData.write(to: observationURL, options: .atomic)
    } else if let fixturePath = observation.fixturePath {
        if FileManager.default.fileExists(atPath: observationURL.path) {
            try FileManager.default.removeItem(at: observationURL)
        }
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: fixturePath),
            to: observationURL
        )
    }
}

func workspaceObservationEvidenceRef(index: Int) -> String {
    "evidence/observations/\(String(format: "%04d", index)).json"
}

private func workspaceLiveObservationSeed(
    for request: TKWorkspaceRunRequest,
    observeProvider: TKWorkspaceLiveObserveProvider
) async throws -> TKWorkspaceObservationSeed {
    let observeRequest = try workspaceLiveObserveRequest(for: request)
    let output = try await observeProvider(observeRequest)
    let rawData = try workspaceObserveOutputData(output)
    return workspaceObservationSeed(
        from: output,
        rawData: rawData,
        sourceCommands: [workspaceLiveObservationCommand(observeRequest)] + output.sourceCommands
    )
}

private func workspaceLiveObserveRequest(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceLiveObserveRequest {
    guard let platform = workspaceLiveObservationPlatform(from: request.platform) else {
        throw RuntimeError("Live workspace observation requires --platform ios, android, or harmony.")
    }
    let kind = try workspaceLiveObservationKind(request.observeKind)
    return TKWorkspaceLiveObserveRequest(
        action: "observe.\(kind)",
        kind: kind,
        platform: platform,
        target: workspaceLiveObservationTarget(workspaceRuntimeTarget(for: request)),
        hdc: request.hdc,
        host: request.observeHost,
        port: request.observePort,
        runtimeBaseURL: workspaceNilIfEmpty(request.observeRuntimeBaseURL),
        maxNodes: request.observeMaxNodes,
        output: workspaceNilIfEmpty(request.observeOutput)
    )
}

private func workspaceObservationSeed(fixturePath: String?) throws -> TKWorkspaceObservationSeed {
    guard let rawPath = workspaceNilIfEmpty(fixturePath) else {
        return workspacePlaceholderObservationSeed()
    }

    let data = try Data(contentsOf: URL(fileURLWithPath: rawPath))
    if let fixture = try? JSONDecoder().decode(TKWorkspaceObservationFixture.self, from: data) {
        return TKWorkspaceObservationSeed(
            fixturePath: rawPath,
            fixtureRef: "evidence/observations/0000.json",
            rawObservationData: nil,
            artifacts: fixture.artifacts,
            screenCandidate: fixture.screenCandidate,
            sourceCommands: fixture.sourceCommands ?? [],
            changed: fixture.changed
        )
    }

    let observeOutput = try JSONDecoder().decode(TKWorkspaceObserveOutputFixture.self, from: data)
    return workspaceObservationSeed(from: observeOutput, fixturePath: rawPath, rawData: data)
}

private func workspacePlaceholderObservationSeed() -> TKWorkspaceObservationSeed {
    TKWorkspaceObservationSeed(
        fixturePath: nil,
        fixtureRef: nil,
        rawObservationData: nil,
        artifacts: TKTestRunObservationArtifacts(
            screenshot: "evidence/screenshots/0000.txt",
            ax: "evidence/hierarchy/0000-ax.json",
            hierarchy: "evidence/hierarchy/0000.json"
        ),
        screenCandidate: TKTestRunScreenCandidate(
            screenshotSha256: "placeholder-screenshot",
            axTextHash: "placeholder-ax",
            hierarchySha256: "placeholder-hierarchy",
            visibleTexts: []
        ),
        sourceCommands: [],
        changed: false
    )
}

private func workspaceObservationSeed(
    from output: TKWorkspaceObserveOutputFixture,
    fixturePath: String,
    rawData: Data
) -> TKWorkspaceObservationSeed {
    let visibleTexts = workspaceVisibleTexts(from: output.nodes)
    return TKWorkspaceObservationSeed(
        fixturePath: fixturePath,
        fixtureRef: "evidence/observations/0000.json",
        rawObservationData: nil,
        artifacts: workspaceObserveArtifacts(
            screenshot: workspaceObserveScreenshotRef(output.artifacts),
            ax: workspaceObserveAXRef(output.artifacts),
            hierarchy: workspaceObserveHierarchyRef(
                primaryArtifact: output.primarySource?.artifact,
                sourceArtifacts: output.sources?.map { ($0.available, $0.artifact) },
                artifacts: output.artifacts
            )
        ),
        screenCandidate: TKTestRunScreenCandidate(
            screenshotSha256: workspaceSHA256(rawData),
            axTextHash: workspaceSHA256(Data(visibleTexts.joined(separator: "\n").utf8)),
            hierarchySha256: workspaceSHA256(Data(workspaceHierarchyFingerprint(from: output.nodes).utf8)),
            visibleTexts: visibleTexts
        ),
        sourceCommands: output.sourceCommands ?? output.primarySource?.sourceCommands ?? [],
        changed: nil
    )
}

private func workspaceObservationSeed(
    from output: ObserveOutput,
    rawData: Data,
    sourceCommands: [String]
) -> TKWorkspaceObservationSeed {
    let visibleTexts = workspaceVisibleTexts(from: output.nodes)
    return TKWorkspaceObservationSeed(
        fixturePath: nil,
        fixtureRef: "evidence/observations/0000.json",
        rawObservationData: rawData,
        artifacts: workspaceObserveArtifacts(
            screenshot: workspaceObserveScreenshotRef(output.artifacts),
            ax: workspaceObserveAXRef(output.artifacts),
            hierarchy: workspaceObserveHierarchyRef(
                primaryArtifact: output.primarySource?.artifact,
                sourceArtifacts: output.sources.map { ($0.available, $0.artifact) },
                artifacts: output.artifacts
            )
        ),
        screenCandidate: TKTestRunScreenCandidate(
            screenshotSha256: workspaceSHA256(rawData),
            axTextHash: workspaceSHA256(Data(visibleTexts.joined(separator: "\n").utf8)),
            hierarchySha256: workspaceSHA256(Data(workspaceHierarchyFingerprint(from: output.nodes).utf8)),
            visibleTexts: visibleTexts
        ),
        sourceCommands: sourceCommands,
        changed: nil
    )
}

private func workspaceLiveObservationPlatform(from rawPlatform: String?) -> ObservationPlatform? {
    guard let value = workspaceNilIfEmpty(rawPlatform)?.lowercased() else { return nil }
    return ObservationPlatform(rawValue: value)
}

private func workspaceLiveObservationKind(_ rawKind: String) throws -> String {
    let kind = rawKind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch kind {
    case "", "tree":
        return "tree"
    case "current":
        return "current"
    default:
        throw RuntimeError("Unsupported live observation kind \(rawKind); expected current or tree.")
    }
}

private func workspaceLiveObservationTarget(_ rawTarget: String) -> String {
    let value = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "current" : value
}

private func workspaceLiveObservationCommand(_ request: TKWorkspaceLiveObserveRequest) -> String {
    var parts = ["triton", "observe", request.kind, "--platform", request.platform.rawValue]
    if request.target != "current" {
        parts += ["--device", request.target]
    }
    if let maxNodes = request.maxNodes {
        parts += ["--max-nodes", "\(maxNodes)"]
    }
    if let output = request.output {
        parts += ["--output", output]
    }
    if let runtimeBaseURL = request.runtimeBaseURL {
        parts += ["--runtime-base-url", runtimeBaseURL]
    }
    parts.append("--json")
    return parts.joined(separator: " ")
}

private func workspaceHasObservationFixture(_ path: String?) -> Bool {
    workspaceNilIfEmpty(path) != nil
}

private func workspaceNilIfEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty
    else {
        return nil
    }
    return trimmed
}

private func workspaceObserveOutputData(_ output: ObserveOutput) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(output)
}

private func workspaceVisibleTexts(from nodes: [ObserveNodeOutput]) -> [String] {
    var seen = Set<String>()
    var texts: [String] = []
    for node in nodes {
        guard let text = node.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              seen.insert(text).inserted
        else {
            continue
        }
        texts.append(text)
    }
    return texts
}

private func workspaceObserveScreenshotRef(_ artifacts: [String]?) -> String? {
    artifacts?.first { path in
        let lower = path.lowercased()
        return lower.contains("screenshot") || lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
    }
}

private func workspaceObserveArtifacts(
    screenshot: String?,
    ax: String?,
    hierarchy: String?
) -> TKTestRunObservationArtifacts {
    let hierarchyRef = hierarchy ?? "evidence/observations/0000.json"
    return TKTestRunObservationArtifacts(
        screenshot: screenshot ?? "evidence/screenshots/0000.txt",
        ax: ax ?? hierarchyRef,
        hierarchy: hierarchyRef
    )
}

private func workspaceObserveHierarchyRef(
    primaryArtifact: String?,
    sourceArtifacts: [(available: Bool, artifact: String?)]?,
    artifacts: [String]?
) -> String? {
    primaryArtifact
        ?? sourceArtifacts?.first(where: { $0.available && $0.artifact != nil })?.artifact
        ?? artifacts?.first
}

private func workspaceObserveAXRef(_ artifacts: [String]?) -> String? {
    artifacts?.first { path in
        let lower = path.lowercased()
        return lower.contains("ax") || lower.contains("accessibility")
    }
}

private func workspaceHierarchyFingerprint(from nodes: [ObserveNodeOutput]) -> String {
    nodes.map { node in
        [
            node.nodeID,
            node.source,
            node.role ?? "",
            node.text ?? "",
            node.identifier ?? "",
        ].joined(separator: "|")
    }.joined(separator: "\n")
}

private func workspaceSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
