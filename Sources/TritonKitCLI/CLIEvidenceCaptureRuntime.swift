import Foundation
import TritonKit
import TritonKitShared

struct EvidenceScreenshotMetadata: Codable {
    let format: String
    let width: Double
    let height: Double
    let scale: Double?
    let dataRef: String?
    let imagePath: String
    let bytes: Int
    let scope: String
    let source: String
    let fidelity: String
    let visualAcceptance: Bool
    let fallbackCommand: String?
}

struct EvidenceSimulatorScreenshotPayload {
    let data: Data
    let sourceCommand: String
    let pixelWidth: Int?
    let pixelHeight: Int?
}

struct EvidenceSimulatorScreenshotProviders {
    var capture: (_ simulatorUDID: String, _ outputPath: String) throws -> EvidenceSimulatorScreenshotPayload

    static let live = EvidenceSimulatorScreenshotProviders(
        capture: { simulatorUDID, outputPath in
            try prepareHostArtifactOutputPath(outputPath)
            let result = try runHostCommand(TKSimctlCommand.screenshot(udid: simulatorUDID, output: outputPath))
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath), options: [.mappedIfSafe])
            _ = try validateRuntimeScreenshotArtifact(data, declaredFormat: "png", outputPath: outputPath)
            let dimensions = imagePixelSize(path: outputPath)
            return EvidenceSimulatorScreenshotPayload(
                data: data,
                sourceCommand: result.sourceCommand,
                pixelWidth: dimensions?.width,
                pixelHeight: dimensions?.height
            )
        }
    )
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
    proxySessionPath: String? = nil,
    hostXcodeProviders: EvidenceHostXcodeArtifactProviders = .live,
    simulatorScreenshotProviders: EvidenceSimulatorScreenshotProviders = .live,
    urlSession: URLSession = .shared
) async throws -> TKEvidenceManifest {
    let outputURL = URL(fileURLWithPath: output)
    try prepareEvidenceOutputDirectory(outputURL)

    var client = TritonKitHTTPClient(host: host, port: port, session: urlSession)
    let startedAt = ISO8601DateFormatter().string(from: Date())
    var artifacts: [TKEvidenceArtifact] = []
    var skipped: [TKEvidenceSkippedArtifact] = []
    var artifactErrors: [TKCLIErrorDetail] = []
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
                appendEvidenceArtifactFailure(kind: kind, error: error, endpoint: "/evidence/artifacts/version", host: host, port: port, skipped: &skipped, artifactErrors: &artifactErrors)
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
                appendEvidenceArtifactFailure(kind: kind, error: error, endpoint: "/status", host: host, port: port, skipped: &skipped, artifactErrors: &artifactErrors)
            }
        case "list":
            do {
                let data = try await client.getData("/targets")
                let targets = try JSONDecoder().decode(TKTargetsResponse.self, from: data)
                if targetSummary == nil {
                    targetSummary = try? TKResolveTargetSummary(target, in: targets.targets)
                    if let targetSummary {
                        client = TritonKitHTTPClient(host: host, port: port, target: targetSummary.id, session: urlSession)
                    }
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
                appendEvidenceArtifactFailure(kind: kind, error: error, endpoint: "/targets", host: host, port: port, skipped: &skipped, artifactErrors: &artifactErrors)
            }
        case "logs":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "unsupported in the current embedded runtime"))
        case "real-device.diagnostics":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "no real-device diagnostics source was provided to this generic evidence capture"))
        case "host.app-action":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "no host app action summary was provided to this generic evidence capture"))
        case "runtime.snapshot":
            do {
                if targetSummary == nil {
                    let resolved = try await resolveEvidenceRuntimeClient(target: target, host: host, port: port, session: urlSession)
                    targetSummary = resolved.summary
                    client = resolved.client
                }
                let payload = try JSONEncoder().encode(TKRuntimeSnapshotRequest(include: ["app", "scene", "route", "ax", "geometry"]))
                let data = try await client.request(type: "runtimeSnapshot", payload: payload)
                try appendEvidenceArtifact(
                    kind: "runtime.snapshot",
                    relativePath: "artifacts/runtime/snapshot.json",
                    data: try prettyJSONData(data),
                    contentType: "application/json",
                    directory: outputURL,
                    freshness: evidenceFreshness(source: "runtime", status: status),
                    artifacts: &artifacts
                )
            } catch {
                appendEvidenceArtifactFailure(kind: kind, error: error, endpoint: "/request", host: host, port: port, skipped: &skipped, artifactErrors: &artifactErrors)
            }
        case "host.layout":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "host layout capture requires a platform smoke/observe path such as Android uiautomator or Harmony uitest"))
        case "build.summary":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "no build summary was provided to this generic evidence capture"))
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
        case "network.proxy-session":
            appendNetworkProxySessionEvidenceArtifacts(
                sessionPath: proxySessionPath,
                directory: outputURL,
                artifacts: &artifacts,
                skipped: &skipped
            )
        case "hierarchy", "ax", "geometry", "screenshot", "archive":
            do {
                if targetSummary == nil {
                    let resolved = try await resolveEvidenceRuntimeClient(target: target, host: host, port: port, session: urlSession)
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
                    await captureEvidenceScreenshots(
                        client: client,
                        directory: outputURL,
                        status: status,
                        target: targetSummary,
                        providers: simulatorScreenshotProviders,
                        host: host,
                        port: port,
                        artifacts: &artifacts,
                        skipped: &skipped,
                        artifactErrors: &artifactErrors
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
                appendEvidenceArtifactFailure(kind: kind, error: error, endpoint: "/request", host: host, port: port, skipped: &skipped, artifactErrors: &artifactErrors)
            }
        default:
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "unsupported"))
        }
    }

    let captureError = evidencePartialCaptureError(
        artifactErrors: artifactErrors,
        skipped: skipped,
        artifacts: artifacts
    )
    let targetUnavailable = artifactErrors.contains { $0.code == "target_not_found" }
    let manifest = TKEvidenceManifest(
        ok: captureError == nil,
        partial: !skipped.isEmpty,
        error: captureError,
        name: name,
        note: note,
        createdAt: startedAt,
        output: outputURL.path,
        artifacts: artifacts,
        skipped: skipped,
        target: targetSummary.map { summary in
            TKEvidenceTarget(
                id: summary.id,
                connected: targetUnavailable ? false : summary.connected,
                appName: summary.appName,
                bundleIdentifier: summary.bundleIdentifier,
                deviceDescription: summary.deviceDescription,
                osDescription: summary.osDescription,
                identityState: summary.identityState ?? "unknown",
                targetConnectionState: targetUnavailable ? "disconnected" : (status?.targetConnectionState ?? (summary.connected ? "connected" : "disconnected")),
                hierarchyCacheState: summary.hierarchyCacheState ?? status?.hierarchyCacheState
            )
        },
        cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion)
    )
    try prettyEncodedData(manifest).write(to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
    return manifest
}

private func resolveEvidenceRuntimeClient(
    target: String,
    host: String,
    port: Int,
    session: URLSession
) async throws -> (summary: TKTargetSummary, client: TritonKitHTTPClient) {
    let resolver = TritonKitHTTPClient(host: host, port: port, session: session)
    let targets: TKTargetsResponse = try await resolver.getJSON("/targets")
    let summary = try TKResolveTargetSummary(target, in: targets.targets)
    return (
        summary,
        TritonKitHTTPClient(host: host, port: port, target: summary.id, session: session)
    )
}

private func appendEvidenceArtifactFailure(
    kind: String,
    error: Error,
    endpoint: String,
    host: String,
    port: Int,
    skipped: inout [TKEvidenceSkippedArtifact],
    artifactErrors: inout [TKCLIErrorDetail]
) {
    let detail = cliErrorDetail(for: error, endpoint: endpoint, host: host, port: port)
    skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error), error: detail))
    artifactErrors.append(detail)
}

private func evidencePartialCaptureError(
    artifactErrors: [TKCLIErrorDetail],
    skipped: [TKEvidenceSkippedArtifact],
    artifacts: [TKEvidenceArtifact]
) -> TKCLIErrorDetail? {
    guard let first = artifactErrors.first else { return nil }
    let failedKinds = skipped.compactMap { $0.error == nil ? nil : $0.kind }
    return TKCLIErrorDetail(
        code: "evidence_capture_partial",
        message: "Evidence capture wrote \(artifacts.count) artifact(s) and failed to capture \(failedKinds.count): \(failedKinds.joined(separator: ", ")). First failure: \(first.code).",
        endpoint: first.endpoint,
        hint: first.hint ?? "Inspect skipped[].error and reconnect the target before retrying evidence capture.",
        nextAction: first.nextAction,
        suggestedCommands: first.suggestedCommands ?? [
            "triton list --json",
            "triton status --json",
        ]
    )
}

func captureEvidenceScreenshots(
    client: TritonKitHTTPClient,
    directory: URL,
    status: TKStatusResponse?,
    target: TKTargetSummary?,
    providers: EvidenceSimulatorScreenshotProviders,
    host: String,
    port: Int,
    artifacts: inout [TKEvidenceArtifact],
    skipped: inout [TKEvidenceSkippedArtifact],
    artifactErrors: inout [TKCLIErrorDetail]
) async {
    let simulatorUDID = target?.platform == "ios" ? target?.simulatorUDID : nil
    var hostScreenshotCaptured = false

    if let simulatorUDID, !simulatorUDID.isEmpty {
        let temporaryPath = directory
            .appendingPathComponent(".triton-host-screenshot-\(UUID().uuidString).png")
            .path
        defer { try? FileManager.default.removeItem(atPath: temporaryPath) }
        do {
            let payload = try providers.capture(simulatorUDID, temporaryPath)
            _ = try validateRuntimeScreenshotArtifact(payload.data, declaredFormat: "png", outputPath: "screenshot.png")
            let freshness = evidenceFreshness(source: "host-simulator", status: status)
            try appendEvidenceArtifact(
                kind: "screenshot",
                relativePath: "screenshot.png",
                data: payload.data,
                contentType: "image/png",
                directory: directory,
                freshness: freshness,
                artifacts: &artifacts,
                scope: "host-simulator",
                source: "simctl-framebuffer",
                fidelity: "full-screen",
                platform: "ios",
                riskLevel: "evidence",
                policy: "host-composited-visual-acceptance",
                redactionStatus: "sensitive",
                sourceCommand: payload.sourceCommand,
                metadata: [
                    "pixelWidth": payload.pixelWidth.map(TKJSONValue.int) ?? .null,
                    "pixelHeight": payload.pixelHeight.map(TKJSONValue.int) ?? .null,
                    "visualAcceptance": .bool(true),
                ],
                target: "sim:\(simulatorUDID)"
            )
            let metadata = EvidenceScreenshotMetadata(
                format: "png",
                width: Double(payload.pixelWidth ?? 0),
                height: Double(payload.pixelHeight ?? 0),
                scale: nil,
                dataRef: nil,
                imagePath: "screenshot.png",
                bytes: payload.data.count,
                scope: "host-simulator",
                source: "simctl-framebuffer",
                fidelity: "full-screen",
                visualAcceptance: true,
                fallbackCommand: nil
            )
            try appendEvidenceArtifact(
                kind: "screenshot-metadata",
                relativePath: "screenshot.json",
                data: try prettyEncodedData(metadata),
                contentType: "application/json",
                directory: directory,
                freshness: freshness,
                artifacts: &artifacts,
                scope: "host-simulator",
                source: "simctl-framebuffer",
                fidelity: "full-screen",
                platform: "ios",
                riskLevel: "summary",
                policy: "host-composited-visual-acceptance",
                redactionStatus: "included",
                sourceCommand: payload.sourceCommand,
                target: "sim:\(simulatorUDID)"
            )
            hostScreenshotCaptured = true
        } catch {
            let fallback = "triton sim screenshot --simulator \(simulatorUDID) --output <path.png> --json"
            let detail = TKCLIErrorDetail(
                code: "host_screenshot_unavailable",
                message: "Host-composited Simulator framebuffer screenshot could not be captured: \(error)",
                endpoint: "/evidence/capture",
                hint: "Retry the host screenshot through Triton; runtime screenshot is App-layer only and is not full visual acceptance evidence.",
                nextAction: TKCLINextAction(
                    command: "sim",
                    args: ["screenshot", "--simulator", simulatorUDID, "--output", "<path.png>", "--json"]
                ),
                suggestedCommands: [fallback]
            )
            skipped.append(TKEvidenceSkippedArtifact(
                kind: "screenshot.host",
                reason: "host-composited screenshot unavailable; runtime screenshot is retained as app-layer evidence",
                error: detail
            ))
            artifactErrors.append(detail)
        }
    }

    do {
        let screenshotData = try await client.request(type: "screenshot")
        let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
        let imageData = try await screenshotImageData(screenshot, client: client)
        let runtimeRelativePath = hostScreenshotCaptured ? "artifacts/runtime/screenshot.png" : "screenshot.png"
        let runtimeMetadataPath = hostScreenshotCaptured ? "artifacts/runtime/screenshot.json" : "screenshot.json"
        let runtimeKind = hostScreenshotCaptured ? "screenshot.runtime" : "screenshot"
        let runtimeMetadataKind = hostScreenshotCaptured ? "screenshot.runtime-metadata" : "screenshot-metadata"
        let artifactData = try normalizeRuntimeScreenshotToPNG(
            imageData,
            declaredFormat: screenshot.format,
            outputPath: runtimeRelativePath
        )
        let freshness = evidenceFreshness(source: "runtime", status: status)
        try appendEvidenceArtifact(
            kind: runtimeKind,
            relativePath: runtimeRelativePath,
            data: artifactData,
            contentType: "image/png",
            directory: directory,
            freshness: freshness,
            artifacts: &artifacts,
            scope: "runtime-app-layer",
            source: "embedded-runtime",
            fidelity: "app-layer",
            platform: target?.platform,
            riskLevel: "evidence",
            policy: "not-full-screen-visual-acceptance",
            redactionStatus: "sensitive",
            metadata: ["visualAcceptance": .bool(false)],
            target: target?.id
        )
        let fallbackCommand = hostScreenshotCaptured ? nil : simulatorUDID.map {
            "triton sim screenshot --simulator \($0) --output <path.png> --json"
        }
        let metadata = EvidenceScreenshotMetadata(
            format: "png",
            width: screenshot.width,
            height: screenshot.height,
            scale: screenshot.scale,
            // A legacy JPEG dataRef points at the pre-normalized source bytes, not this PNG artifact.
            dataRef: artifactData == imageData ? screenshot.dataRef : nil,
            imagePath: runtimeRelativePath,
            bytes: artifactData.count,
            scope: "runtime-app-layer",
            source: "embedded-runtime",
            fidelity: "app-layer",
            visualAcceptance: false,
            fallbackCommand: fallbackCommand
        )
        try appendEvidenceArtifact(
            kind: runtimeMetadataKind,
            relativePath: runtimeMetadataPath,
            data: try prettyEncodedData(metadata),
            contentType: "application/json",
            directory: directory,
            freshness: freshness,
            artifacts: &artifacts,
            scope: "runtime-app-layer",
            source: "embedded-runtime",
            fidelity: "app-layer",
            platform: target?.platform,
            riskLevel: "summary",
            policy: "not-full-screen-visual-acceptance",
            redactionStatus: "included",
            target: target?.id
        )
    } catch {
        appendEvidenceArtifactFailure(
            kind: hostScreenshotCaptured ? "screenshot.runtime" : "screenshot",
            error: error,
            endpoint: "/request",
            host: host,
            port: port,
            skipped: &skipped,
            artifactErrors: &artifactErrors
        )
    }
}

func evidenceHierarchyData(client: TritonKitHTTPClient, refresh: Bool) async throws -> Data {
    if refresh {
        return try await client.request(type: "hierarchy")
    }
    return try await client.latestHierarchyData()
}
