import Foundation
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
        case "real-device.diagnostics":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "no real-device diagnostics source was provided to this generic evidence capture"))
        case "host.app-action":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "no host app action summary was provided to this generic evidence capture"))
        case "runtime.snapshot":
            do {
                if targetSummary == nil {
                    let resolved = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
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
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
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
