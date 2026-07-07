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
    let modelPath: String?
    let mlxHelperPath: String?
    let allowModelDownload: Bool
    let apiKeyEnv: String?
    let allowRemoteVLM: Bool

    init(
        provider: String,
        image: String,
        target: String,
        coordinateContract: String,
        outputDirectory: String,
        baseURL: String?,
        model: String?,
        modelPath: String? = nil,
        mlxHelperPath: String? = nil,
        allowModelDownload: Bool = false,
        apiKeyEnv: String?,
        allowRemoteVLM: Bool
    ) {
        self.provider = provider
        self.image = image
        self.target = target
        self.coordinateContract = coordinateContract
        self.outputDirectory = outputDirectory
        self.baseURL = baseURL
        self.model = model
        self.modelPath = modelPath
        self.mlxHelperPath = mlxHelperPath
        self.allowModelDownload = allowModelDownload
        self.apiKeyEnv = apiKeyEnv
        self.allowRemoteVLM = allowRemoteVLM
    }
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
        modelPath: request.modelPath,
        apiKeyEnv: request.apiKeyEnv,
        allowRemoteVLM: request.allowRemoteVLM,
        allowModelDownload: request.allowModelDownload,
        mlxHelperPath: request.mlxHelperPath
    )
}

func workspaceVLMGroundingForAction(
    request: TKWorkspaceRunRequest,
    observation: TKWorkspaceObservationSeed,
    actionCandidate: TKWorkspaceActionCandidate,
    runDir: URL,
    providerPreflight: TKWorkspaceProviderPreflight,
    vlmGroundingProvider: TKWorkspaceVLMGroundingProvider,
    artifactIndex: Int = 0
) async throws -> TKVLMGroundResponse? {
    guard actionCandidate.action == "tap",
          providerPreflight.vlmProviderStatus == "ready",
          let provider = providerPreflight.vlmProvider,
          let image = workspaceObservationScreenshotPath(observation, runDir: runDir)
    else {
        return nil
    }

    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let suffix = workspaceArtifactSuffix(artifactIndex)
    let coordinateContractName = artifactIndex == 0 ? "coordinate-contract.json" : "coordinate-contract-\(suffix).json"
    let coordinateContractURL = runDir.appendingPathComponent(coordinateContractName)
    try writeWorkspaceVLMCoordinateContract(imagePath: image, to: coordinateContractURL)

    let outputURL = runDir.appendingPathComponent("evidence/actions/vlm-\(suffix)", isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let grounding = try await vlmGroundingProvider(TKWorkspaceVLMGroundingRequest(
        provider: provider,
        image: image,
        target: actionCandidate.query,
        coordinateContract: coordinateContractURL.path,
        outputDirectory: outputURL.path,
        baseURL: request.vlmBaseURL,
        model: request.vlmModel,
        modelPath: request.vlmModelPath,
        mlxHelperPath: request.vlmHelper,
        allowModelDownload: request.vlmAllowModelDownload,
        apiKeyEnv: request.vlmAPIKeyEnv,
        allowRemoteVLM: request.allowRemoteVLM
    ))
    try writeVLMJSON(
        grounding,
        to: outputURL.appendingPathComponent("vlm-grounding.json")
    )
    return grounding
}

func workspaceVLMGroundingFailureActionExecution(
    actionCandidate: TKWorkspaceActionCandidate,
    error: Error,
    runDir: URL,
    artifactIndex: Int = 0
) throws -> TKWorkspaceActionExecutionResult {
    let suffix = workspaceArtifactSuffix(artifactIndex)
    let outputURL = runDir.appendingPathComponent("evidence/actions/vlm-\(suffix)", isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let failureRef = "evidence/actions/vlm-\(suffix)/vlm-failure.json"
    let failure = workspaceVLMGroundingActionFailure(error, artifactRef: failureRef)
    try writeWorkspaceJSONArtifact(
        workspaceVLMGroundingFailureArtifact(failure, actionCandidate: actionCandidate),
        to: outputURL.appendingPathComponent("vlm-failure.json")
    )
    return TKWorkspaceActionExecutionResult(
        ok: false,
        action: actionCandidate.action,
        command: actionCandidate.command,
        proofSource: "vlm.grounding",
        sourceCommands: [
            actionCandidate.command.map(shellEscaped).joined(separator: " "),
            "vlm grounding \(failure.code)",
        ],
        message: failure.message,
        inputResult: nil,
        tapResolution: nil,
        vlmGrounding: nil,
        failure: failure
    )
}

private func workspaceVLMGroundingActionFailure(
    _ error: Error,
    artifactRef: String
) -> TKWorkspaceActionFailure {
    if let failure = error as? TKVLMGroundingFailure {
        return TKWorkspaceActionFailure(
            code: failure.code,
            kind: "vlm_grounding_failed",
            message: failure.message,
            hint: failure.hint,
            artifactRef: artifactRef
        )
    }
    return TKWorkspaceActionFailure(
        code: "vlm_grounding_failed",
        kind: "vlm_grounding_failed",
        message: String(describing: error),
        hint: "Inspect VLM grounding evidence, observe again, or choose a visible target before retrying.",
        artifactRef: artifactRef
    )
}

private func workspaceVLMGroundingFailureArtifact(
    _ failure: TKWorkspaceActionFailure,
    actionCandidate: TKWorkspaceActionCandidate
) -> [String: Any] {
    var artifact: [String: Any] = [
        "schemaVersion": 1,
        "kind": "triton.workspace.vlm-grounding-failure",
        "code": failure.code,
        "failureKind": failure.kind,
        "message": failure.message,
        "action": actionCandidate.action,
        "target": actionCandidate.query,
        "command": actionCandidate.command,
    ]
    if let hint = failure.hint {
        artifact["hint"] = hint
    }
    return artifact
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
