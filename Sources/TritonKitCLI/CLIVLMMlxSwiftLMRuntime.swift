import Foundation
import TritonKitShared

struct TKMLXSwiftLMProvider: TKVLMProvider {
    let name = "mlx-swift-lm"
    let model: String?
    let modelPath: String?
    let maxTokens: Int
    let temperature: Double
    let seed: Int
    let promptTemplate: String
    let allowModelDownload: Bool
    let helperPath: String?

    func ground(image: TKVLMGroundImage, target: String) throws -> TKVLMProviderResponseArtifact {
        if (modelPath == nil || modelPath?.isEmpty == true) &&
            (model == nil || model?.isEmpty == true) {
            throw TKVLMGroundingFailure(
                code: "mlx_model_load_failed",
                message: "mlx-swift-lm grounding requires --model or --model-path",
                hint: "Pass --model-path for local fake/real model configuration or --model with --allow-model-download when downloads are intended"
            )
        }
        let helperMode: String
        let rawOutput: String
        if let helperOutput = try runMLXSwiftLMHelperIfConfigured(image: image, target: target) {
            helperMode = "external-helper"
            rawOutput = helperOutput
        } else {
            helperMode = "fake-helper"
            rawOutput = try fakeMLXSwiftLMRawOutput(target: target)
        }
        let parsed = try parseMLXSwiftLMGroundingOutput(rawOutput)
        return TKVLMProviderResponseArtifact(
            provider: name,
            model: model ?? modelPath,
            coordinateSpace: "normalized_0_1000",
            point: parsed,
            confidence: 1,
            rationale: helperMode == "external-helper" ? "external mlx-swift-lm helper output parsed by TritonKit" : "deterministic P17 fake mlx-swift-lm helper; no real model loaded",
            rawText: rawOutput,
            mode: helperMode
        )
    }

    private func runMLXSwiftLMHelperIfConfigured(image: TKVLMGroundImage, target: String) throws -> String? {
        let resolvedHelper = helperPath ?? ProcessInfo.processInfo.environment["TRITON_MLX_HELPER"] ?? ProcessInfo.processInfo.environment["TRITON_MLX_SWIFT_LM_HELPER"]
        guard let resolvedHelper, !resolvedHelper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard FileManager.default.isExecutableFile(atPath: resolvedHelper) else {
            throw TKVLMGroundingFailure(
                code: "mlx_model_load_failed",
                message: "mlx-swift-lm helper is not executable at \(resolvedHelper)",
                hint: "Set TRITON_MLX_HELPER to an executable helper or omit it to use the deterministic fake helper"
            )
        }

        let request = TKMLXSwiftLMHelperRequest(
            provider: name,
            model: model,
            modelPath: modelPath,
            image: image,
            target: target,
            maxTokens: maxTokens,
            temperature: temperature,
            seed: seed,
            promptTemplate: promptTemplate,
            allowModelDownload: allowModelDownload
        )
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-mlx-helper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let requestURL = tempDirectory.appendingPathComponent("request.json")
        try writeVLMJSON(request, to: requestURL)
        return try runMLXSwiftLMHelper(path: resolvedHelper, requestURL: requestURL)
    }
}

struct TKMLXSwiftLMHelperRequest: Codable, Equatable {
    let schemaVersion: Int
    let provider: String
    let model: String?
    let modelPath: String?
    let image: TKVLMGroundImage
    let target: String
    let maxTokens: Int
    let temperature: Double
    let seed: Int
    let promptTemplate: String
    let allowModelDownload: Bool

    init(
        schemaVersion: Int = 1,
        provider: String,
        model: String?,
        modelPath: String?,
        image: TKVLMGroundImage,
        target: String,
        maxTokens: Int,
        temperature: Double,
        seed: Int,
        promptTemplate: String,
        allowModelDownload: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.provider = provider
        self.model = model
        self.modelPath = modelPath
        self.image = image
        self.target = target
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.seed = seed
        self.promptTemplate = promptTemplate
        self.allowModelDownload = allowModelDownload
    }
}

func runMLXSwiftLMHelper(path: String, requestURL: URL, timeoutSeconds: TimeInterval = 120) throws -> String {
    try runMLXHelperCommand(
        path: path, operation: "ground", requestURL: requestURL, timeoutSeconds: timeoutSeconds,
        launchFailureCode: "mlx_model_load_failed", failureCode: "mlx_generation_failed"
    )
}

/// Reuse the host executor's concurrent capped pipe drains, TERM/KILL cleanup,
/// and bounded post-exit EOF wait. The execution timeout is followed by the host
/// executor's cleanup budget; arbitrary descendant process trees are not killed.
func runMLXHelperCommand(
    path: String,
    operation: String,
    requestURL: URL,
    timeoutSeconds: TimeInterval,
    launchFailureCode: String,
    failureCode: String
) throws -> String {
    guard timeoutSeconds.isFinite, timeoutSeconds > 0 else {
        throw TKVLMGroundingFailure(code: failureCode, message: "Invalid helper timeout", hint: "Use a positive finite timeout")
    }
    let command = TKHostCommand(
        executable: URL(fileURLWithPath: path).path,
        arguments: [operation, "--request", requestURL.path],
        defaultTimeoutSeconds: timeoutSeconds
    )
    do {
        let result = try runHostCommand(command, maximumOutputBytes: 1_048_576)
        guard !result.stdoutTruncated else {
            throw TKVLMGroundingFailure(
                code: failureCode, message: "mlx-swift-lm helper stdout exceeded the 1048576-byte limit",
                hint: "Write compact machine output to stdout and progress logs to stderr"
            )
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch let failure as TKVLMGroundingFailure {
        throw failure
    } catch HostCommandRunError.launchFailed(let message) {
        throw TKVLMGroundingFailure(
            code: launchFailureCode, message: "Failed to launch mlx-swift-lm helper at \(path): \(message)",
            hint: "Check --helper or TRITON_MLX_HELPER and executable permissions"
        )
    } catch HostCommandRunError.nonZeroExit(_, let result) {
        throw TKVLMGroundingFailure(
            code: failureCode,
            message: "mlx-swift-lm helper exited with status \(result.exitCode): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))",
            hint: "Inspect helper stderr and model availability"
        )
    } catch {
        throw TKVLMGroundingFailure(
            code: failureCode, message: "mlx-swift-lm helper \(operation) failed: \(error)",
            hint: "Inspect helper logs, timeout, and output completeness"
        )
    }
}

func fakeMLXSwiftLMRawOutput(target: String) throws -> String {
    let lowercased = target.lowercased()
    if lowercased.contains("not visible") || lowercased.contains("missing") {
        return #"{"error":"target_not_visible"}"#
    }
    if lowercased.contains("action-list") {
        return #"click(512, 734) + type("hello")"#
    }
    if lowercased.contains("out-of-bounds") || lowercased.contains("outside") {
        return #"{"x":1200,"y":734,"scale":1000}"#
    }
    if lowercased.contains("home") {
        return #"{"x":500,"y":331,"scale":1000}"#
    }
    return #"{"x":500,"y":500,"scale":1000}"#
}

func parseMLXSwiftLMGroundingOutput(_ rawOutput: String) throws -> TKVLMNormalizedPoint {
    let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw TKVLMGroundingFailure(
            code: "mlx_response_empty",
            message: "mlx-swift-lm provider returned an empty response",
            hint: "Expected compact JSON point or (x,y)"
        )
    }
    let lowercased = trimmed.lowercased()
    if lowercased.contains("click(") ||
        lowercased.contains("type(") ||
        lowercased.contains("action") ||
        lowercased.contains("chain-of-thought") {
        throw TKVLMGroundingFailure(
            code: "mlx_parse_failed",
            message: "mlx-swift-lm response contains actions or explanatory text",
            hint: #"Provider must return only {"x":...,"y":...,"scale":1000}"#
        )
    }
    if let data = trimmed.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data) {
        return try parseMLXSwiftLMJSONPointObject(object)
    }
    return try parseMLXSwiftLMTuplePoint(trimmed)
}

private func parseMLXSwiftLMJSONPointObject(_ object: Any) throws -> TKVLMNormalizedPoint {
    guard let dictionary = object as? [String: Any] else {
        throw mlxParseFailure("mlx-swift-lm JSON response must be an object")
    }
    if let error = dictionary["error"] as? String {
        if error == "target_not_visible" {
            throw TKVLMGroundingFailure(
                code: "vlm_target_not_visible",
                message: "mlx-swift-lm reported target_not_visible",
                hint: "Capture a fresh screenshot or use deterministic AX assertion before grounding"
            )
        }
        throw mlxParseFailure("mlx-swift-lm returned unsupported error (error)")
    }
    if let nested = dictionary["point"] {
        return try parseMLXSwiftLMJSONPointObject(nested)
    }
    guard let x = numericValue(dictionary["x"]),
          let y = numericValue(dictionary["y"]) else {
        throw mlxParseFailure("mlx-swift-lm response missing x/y")
    }
    let scale = numericValue(dictionary["scale"]) ?? 1000
    guard scale == 1000 else {
        throw mlxParseFailure("mlx-swift-lm response scale must be 1000")
    }
    let point = TKVLMNormalizedPoint(x: x, y: y, scale: scale)
    try validateMLXNormalizedPoint(point)
    return point
}

private func parseMLXSwiftLMTuplePoint(_ text: String) throws -> TKVLMNormalizedPoint {
    let pattern = #"^\(?\s*([0-9]+(?:\.[0-9]+)?)\s*,\s*([0-9]+(?:\.[0-9]+)?)\s*\)?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
          match.numberOfRanges == 3,
          let xRange = Range(match.range(at: 1), in: text),
          let yRange = Range(match.range(at: 2), in: text),
          let x = Double(text[xRange]),
          let y = Double(text[yRange]) else {
        throw mlxParseFailure("mlx-swift-lm response is not strict JSON point or tuple")
    }
    let point = TKVLMNormalizedPoint(x: x, y: y, scale: 1000)
    try validateMLXNormalizedPoint(point)
    return point
}

private func validateMLXNormalizedPoint(_ point: TKVLMNormalizedPoint) throws {
    guard point.x >= 0, point.x <= 1000, point.y >= 0, point.y <= 1000 else {
        throw TKVLMGroundingFailure(
            code: "vlm_point_out_of_bounds",
            message: "mlx-swift-lm point ((point.x), (point.y)) is outside 0...1000",
            hint: "Provider must return normalized_0_1000 coordinates"
        )
    }
}

private func mlxParseFailure(_ message: String) -> TKVLMGroundingFailure {
    TKVLMGroundingFailure(
        code: "mlx_parse_failed",
        message: message,
        hint: #"Return only {"x":512,"y":734,"scale":1000}, {"point":{...}}, or (512,734)"#
    )
}

struct TKMLXSwiftLMArtifactPaths {
    let request: URL
    let response: URL
    let rawOutput: URL
    let parsedPoint: URL
    let transform: URL
    let overlay: URL
    let modelMetadata: URL
}

func mlxSwiftLMArtifactPaths(in outputURL: URL) -> TKMLXSwiftLMArtifactPaths {
    TKMLXSwiftLMArtifactPaths(
        request: outputURL.appendingPathComponent("mlx-grounding-request.redacted.json"),
        response: outputURL.appendingPathComponent("mlx-grounding-response.json"),
        rawOutput: outputURL.appendingPathComponent("mlx-grounding-raw-output.txt"),
        parsedPoint: outputURL.appendingPathComponent("mlx-grounding-parsed-point.json"),
        transform: outputURL.appendingPathComponent("mlx-grounding-transform.json"),
        overlay: outputURL.appendingPathComponent("mlx-grounding-overlay.png"),
        modelMetadata: outputURL.appendingPathComponent("mlx-model-metadata.json")
    )
}

func writeMLXSwiftLMArtifacts(
    paths: TKMLXSwiftLMArtifactPaths,
    request: TKVLMGroundingRequestArtifact,
    response: TKVLMProviderResponseArtifact,
    transform: TKVLMCoordinateTransform,
    modelPath: String?,
    allowModelDownload: Bool
) throws {
    try writeVLMJSON(request, to: paths.request)
    try writeVLMJSON(response, to: paths.response)
    try (response.rawText ?? "").data(using: .utf8)?.write(to: paths.rawOutput, options: .atomic)
    try writeVLMJSON(
        TKVLMMLXParsedPointArtifact(rawOutput: response.rawText ?? "", normalizedPoint: response.point),
        to: paths.parsedPoint
    )
    try writeVLMJSON(transform, to: paths.transform)
        try writeVLMJSON(
            TKVLMMLXModelMetadata(
                model: response.model,
                modelPath: modelPath,
                loadedAt: ISO8601DateFormatter().string(from: Date()),
                mlxSwiftLMVersion: response.mode == "external-helper" ? "external-helper" : "not-linked-p17-fake-helper",
                downloadAllowed: allowModelDownload,
                mode: response.mode ?? "fake-helper"
            ),
            to: paths.modelMetadata
        )
}

func vlmProviderListResponse() -> TKVLMProviderListResponse {
    TKVLMProviderListResponse(providers: [
        TKVLMProviderDescriptor(
            id: "mock",
            kind: "deterministic",
            status: "stable",
            requiresNetwork: false,
            requiresModel: false,
            defaultEnabledInCI: true,
            supports: ["point-grounding"],
            coordinateOutputs: ["normalized_0_1000", "runtime-point"],
            runnerIntegration: TKVLMProviderRunnerIntegration(supported: true, requiresAllowVLM: true, defaultEnabled: false)
        ),
        TKVLMProviderDescriptor(
            id: "openai-compatible",
            kind: "remote-or-local-http-vlm",
            status: "experimental",
            requiresNetwork: true,
            requiresModel: true,
            defaultEnabledInCI: false,
            supports: ["point-grounding"],
            coordinateOutputs: ["normalized_0_1000", "runtime-point"],
            runnerIntegration: TKVLMProviderRunnerIntegration(supported: true, requiresAllowVLM: true, defaultEnabled: false)
        ),
        TKVLMProviderDescriptor(
            id: "mlx-swift-lm",
            kind: "local-vlm",
            status: "experimental",
            requiresNetwork: false,
            requiresModel: true,
            defaultEnabledInCI: false,
            supports: ["point-grounding"],
            coordinateOutputs: ["normalized_0_1000", "runtime-point"],
            runnerIntegration: TKVLMProviderRunnerIntegration(supported: true, requiresAllowVLM: true, defaultEnabled: false)
        ),
    ])
}
