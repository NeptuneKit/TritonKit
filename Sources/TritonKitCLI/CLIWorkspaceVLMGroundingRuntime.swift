import Foundation
import TritonKitShared

typealias TKWorkspaceVLMGroundingProvider = (TKWorkspaceVLMGroundingRequest) async throws -> TKVLMGroundResponse

struct TKWorkspaceVLMGroundingRequest: Equatable {
    let provider: String
    let image: String
    let target: String
    let coordinateContract: String
    let outputDirectory: String
    let baseURL: String?
    let model: String?
    let apiKeyEnv: String?
    let allowRemoteVLM: Bool
}

func workspaceDefaultVLMGroundingProvider(
    _ request: TKWorkspaceVLMGroundingRequest
) async throws -> TKVLMGroundResponse {
    try groundVLMTarget(
        provider: request.provider,
        image: request.image,
        target: request.target,
        coordinateContract: request.coordinateContract,
        outputDirectory: request.outputDirectory,
        baseURL: request.baseURL,
        model: request.model,
        apiKeyEnv: request.apiKeyEnv,
        allowRemoteVLM: request.allowRemoteVLM
    )
}

func workspaceVLMGroundingForAction(
    request: TKWorkspaceRunRequest,
    observation: TKWorkspaceObservationSeed,
    actionCandidate: TKWorkspaceActionCandidate,
    runDir: URL,
    providerPreflight: TKWorkspaceProviderPreflight,
    vlmGroundingProvider: TKWorkspaceVLMGroundingProvider
) async throws -> TKVLMGroundResponse? {
    guard actionCandidate.action == "tap",
          providerPreflight.vlmProviderStatus == "ready",
          let provider = providerPreflight.vlmProvider,
          let image = workspaceObservationScreenshotPath(observation, runDir: runDir)
    else {
        return nil
    }

    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let coordinateContractURL = runDir.appendingPathComponent("coordinate-contract.json")
    try writeWorkspaceVLMCoordinateContract(imagePath: image, to: coordinateContractURL)

    let outputURL = runDir.appendingPathComponent("evidence/actions/vlm-000", isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let grounding = try await vlmGroundingProvider(TKWorkspaceVLMGroundingRequest(
        provider: provider,
        image: image,
        target: actionCandidate.query,
        coordinateContract: coordinateContractURL.path,
        outputDirectory: outputURL.path,
        baseURL: request.vlmBaseURL,
        model: request.vlmModel,
        apiKeyEnv: request.vlmAPIKeyEnv,
        allowRemoteVLM: request.allowRemoteVLM
    ))
    try writeVLMJSON(
        grounding,
        to: outputURL.appendingPathComponent("vlm-grounding.json")
    )
    return grounding
}

private func workspaceObservationScreenshotPath(
    _ observation: TKWorkspaceObservationSeed,
    runDir: URL
) -> String? {
    let raw = (observation.artifacts.screenshot ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }

    let directURL = URL(fileURLWithPath: raw)
    if directURL.isFileURL, directURL.path == raw, FileManager.default.fileExists(atPath: directURL.path) {
        return directURL.path
    }

    var candidates: [URL] = []
    if let fixturePath = observation.fixturePath {
        candidates.append(
            URL(fileURLWithPath: fixturePath)
                .deletingLastPathComponent()
                .appendingPathComponent(raw)
        )
    }
    candidates.append(runDir.appendingPathComponent(raw))
    candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(raw))

    for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
        return candidate.path
    }
    return nil
}

private func writeWorkspaceVLMCoordinateContract(imagePath: String, to url: URL) throws {
    let image = try loadVLMImage(path: imagePath)
    let contract = TKVLMCoordinateContract(
        schemaVersion: 1,
        canonicalTapSpace: "runtime-point",
        runtimeScreenshotSpace: TKVLMRuntimeScreenshotSpace(
            kind: "runtime-point-sized-image",
            width: image.width,
            height: image.height,
            scale: 1
        ),
        runtimeGeometry: TKVLMRuntimeGeometry(
            width: image.width,
            height: image.height,
            scale: 1,
            orientation: "unknown"
        ),
        vlmImageSpace: "workspace-observation-screenshot",
        hostFramebufferSpace: nil
    )
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try writeVLMJSON(contract, to: url)
}
