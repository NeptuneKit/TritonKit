import AppKit
import CryptoKit
import Foundation
import ImageIO
import TritonKitShared

struct TKVLMGroundingFailure: Error, CustomStringConvertible {
    let code: String
    let message: String
    let hint: String?

    var description: String { message }
}

struct TKVLMCoordinateContract: Codable, Equatable {
    let schemaVersion: Int
    let canonicalTapSpace: String
    let runtimeScreenshotSpace: TKVLMRuntimeScreenshotSpace
    let runtimeGeometry: TKVLMRuntimeGeometry
    let vlmImageSpace: String?
    let hostFramebufferSpace: String?
}

struct TKVLMRuntimeScreenshotSpace: Codable, Equatable {
    let kind: String
    let width: Double
    let height: Double
    let scale: Double
}

struct TKVLMRuntimeGeometry: Codable, Equatable {
    let width: Double
    let height: Double
    let scale: Double
    let orientation: String
}

struct TKVLMGroundingRequestArtifact: Codable, Equatable {
    let schemaVersion: Int
    let provider: String
    let model: String?
    let baseURL: String?
    let target: String
    let image: TKVLMGroundImage
    let coordinateContract: TKVLMGroundCoordinateContractRef
    let redaction: String
    let network: String
}

struct TKVLMProviderResponseArtifact: Codable, Equatable {
    let schemaVersion: Int
    let provider: String
    let model: String?
    let coordinateSpace: String
    let point: TKVLMNormalizedPoint
    let confidence: Double
    let rationale: String
    let rawText: String?
    let mode: String?

    init(
        schemaVersion: Int = 1,
        provider: String,
        model: String? = nil,
        coordinateSpace: String,
        point: TKVLMNormalizedPoint,
        confidence: Double,
        rationale: String,
        rawText: String? = nil,
        mode: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.provider = provider
        self.model = model
        self.coordinateSpace = coordinateSpace
        self.point = point
        self.confidence = confidence
        self.rationale = rationale
        self.rawText = rawText
        self.mode = mode
    }
}

typealias TKVLMHTTPTransport = (_ url: URL, _ body: Data, _ headers: [String: String]) throws -> Data

protocol TKVLMProvider {
    var name: String { get }
    func ground(image: TKVLMGroundImage, target: String) throws -> TKVLMProviderResponseArtifact
}

struct TKMockVLMProvider: TKVLMProvider {
    let name = "mock"

    func ground(image: TKVLMGroundImage, target: String) throws -> TKVLMProviderResponseArtifact {
        let normalized: TKVLMNormalizedPoint
        let lowercasedTarget = target.lowercased()
        if lowercasedTarget.contains("out-of-bounds") || lowercasedTarget.contains("outside") {
            normalized = TKVLMNormalizedPoint(x: 1200, y: 1200)
        } else if lowercasedTarget.contains("go home") || lowercasedTarget.contains("home") {
            normalized = TKVLMNormalizedPoint(x: 500, y: 331.2356979405034)
        } else {
            normalized = TKVLMNormalizedPoint(x: 500, y: 500)
        }
        return TKVLMProviderResponseArtifact(
            schemaVersion: 1,
            provider: name,
            coordinateSpace: "normalized_0_1000",
            point: normalized,
            confidence: 1,
            rationale: "deterministic mock provider; no network or model call"
        )
    }
}

struct TKOpenAICompatibleVLMProvider: TKVLMProvider {
    let name = "openai-compatible"
    let baseURL: URL
    let model: String
    let apiKey: String?
    let transport: TKVLMHTTPTransport?

    func ground(image: TKVLMGroundImage, target: String) throws -> TKVLMProviderResponseArtifact {
        let requestURL = baseURL.appendingPathComponent("chat/completions")
        let imageData = try Data(contentsOf: URL(fileURLWithPath: image.path))
        let body = try makeOpenAICompatibleRequestBody(
            model: model,
            target: target,
            imageBase64: imageData.base64EncodedString()
        )
        var headers = [
            "Content-Type": "application/json",
        ]
        if let apiKey, !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        let responseData: Data
        do {
            if let transport {
                responseData = try transport(requestURL, body, headers)
            } else {
                responseData = try postVLMJSON(url: requestURL, body: body, headers: headers)
            }
        } catch let failure as TKVLMGroundingFailure {
            throw failure
        } catch {
            throw TKVLMGroundingFailure(
                code: "vlm_provider_request_failed",
                message: "OpenAI-compatible grounding request failed: \(error)",
                hint: "Check --base-url and provider availability"
            )
        }
        let rawText = try parseOpenAICompatibleText(responseData)
        let point = try parseVLMNormalizedPoint(rawText)
        return TKVLMProviderResponseArtifact(
            provider: name,
            model: model,
            coordinateSpace: "normalized_0_1000",
            point: point,
            confidence: 1,
            rationale: "openai-compatible point grounding response parsed from choices[0].message.content",
            rawText: rawText
        )
    }
}

func groundVLMTarget(
    provider providerName: String,
    image imagePath: String,
    target: String,
    coordinateContract coordinateContractPath: String,
    outputDirectory: String?,
    baseURL: String? = nil,
    model: String? = nil,
    modelPath: String? = nil,
    apiKeyEnv: String? = nil,
    allowRemoteVLM: Bool = false,
    maxTokens: Int = 64,
    temperature: Double = 0,
    seed: Int = 0,
    promptTemplate: String = "gui-grounding-v1",
    allowModelDownload: Bool = false,
    mlxHelperPath: String? = nil,
    httpTransport: TKVLMHTTPTransport? = nil
) throws -> TKVLMGroundResponse {
    let provider = try makeVLMProvider(
        providerName,
        baseURL: baseURL,
        model: model,
        modelPath: modelPath,
        apiKeyEnv: apiKeyEnv,
        allowRemoteVLM: allowRemoteVLM,
        maxTokens: maxTokens,
        temperature: temperature,
        seed: seed,
        promptTemplate: promptTemplate,
        allowModelDownload: allowModelDownload,
        mlxHelperPath: mlxHelperPath,
        httpTransport: httpTransport
    )
    let imageURL = URL(fileURLWithPath: imagePath)
    guard FileManager.default.fileExists(atPath: imageURL.path) else {
        throw TKVLMGroundingFailure(
            code: "vlm_image_not_found",
            message: "Image does not exist at \(imagePath)",
            hint: "Pass --image with an existing screenshot artifact"
        )
    }
    let coordinateURL = URL(fileURLWithPath: coordinateContractPath)
    guard FileManager.default.fileExists(atPath: coordinateURL.path) else {
        throw TKVLMGroundingFailure(
            code: "vlm_coordinate_contract_not_found",
            message: "Coordinate contract does not exist at \(coordinateContractPath)",
            hint: "Pass --coordinate-contract from a .tritonevidence run"
        )
    }

    let imageMetadata = try loadVLMImage(path: imageURL.path)
    let contract = try loadVLMCoordinateContract(path: coordinateURL.path)
    try validateVLMCoordinateContract(contract, path: coordinateURL.path)

    let providerResponse = try provider.ground(image: imageMetadata, target: target)
    guard providerResponse.coordinateSpace == "normalized_0_1000" else {
        throw TKVLMGroundingFailure(
            code: "vlm_coordinate_space_unsupported",
            message: "Provider returned unsupported coordinate space \(providerResponse.coordinateSpace)",
            hint: "P3 mock grounding accepts normalized_0_1000 provider points only"
        )
    }
    let runtimePoint = try normalizedPointToRuntimePoint(providerResponse.point, image: imageMetadata, contract: contract)
    try validateVLMRuntimePoint(runtimePoint, contract: contract)

    let outputURL = try resolveVLMOutputDirectory(outputDirectory, imageURL: imageURL)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let mlxArtifacts = provider.name == "mlx-swift-lm" ? mlxSwiftLMArtifactPaths(in: outputURL) : nil
    let requestURL = mlxArtifacts?.request ?? outputURL.appendingPathComponent("vlm-request.redacted.json")
    let responseURL = mlxArtifacts?.response ?? outputURL.appendingPathComponent("vlm-response.json")
    let overlayURL = mlxArtifacts?.overlay ?? outputURL.appendingPathComponent("vlm-overlay.png")

    let contractRef = TKVLMGroundCoordinateContractRef(
        path: coordinateURL.path,
        canonicalTapSpace: contract.canonicalTapSpace
    )
    let requestArtifact = TKVLMGroundingRequestArtifact(
        schemaVersion: 1,
        provider: provider.name,
        model: providerResponse.model,
        baseURL: redactedVLMBaseURL(baseURL),
        target: target,
        image: imageMetadata,
        coordinateContract: contractRef,
        redaction: "target-text-only",
        network: vlmRequestNetwork(for: provider.name)
    )
    try writeVLMJSON(requestArtifact, to: requestURL)
    try writeVLMJSON(providerResponse, to: responseURL)
    try writeVLMOverlay(
        imageURL: imageURL,
        outputURL: overlayURL,
        target: target,
        normalized: providerResponse.point,
        runtimePoint: runtimePoint,
        sha256: imageMetadata.sha256
    )

    let transform = TKVLMCoordinateTransform(
        inputSpace: "normalized_0_1000",
        imageSpace: "image-pixel",
        outputSpace: "runtime-point",
        imageWidth: imageMetadata.width,
        imageHeight: imageMetadata.height,
        runtimeWidth: contract.runtimeGeometry.width,
        runtimeHeight: contract.runtimeGeometry.height,
        scale: contract.runtimeGeometry.scale,
        orientation: contract.runtimeGeometry.orientation,
        source: coordinateURL.path
    )
    if let mlxArtifacts {
        try writeMLXSwiftLMArtifacts(
            paths: mlxArtifacts,
            request: requestArtifact,
            response: providerResponse,
            transform: transform,
            modelPath: modelPath,
            allowModelDownload: allowModelDownload
        )
    }
    return TKVLMGroundResponse(
        provider: provider.name,
        model: providerResponse.model,
        baseURL: redactedVLMBaseURL(baseURL),
        target: target,
        image: imageMetadata,
        coordinateContract: contractRef,
        point: TKVLMGroundPoint(
            normalized: providerResponse.point,
            runtimePoint: runtimePoint,
            coordinateSpace: "runtime-point"
        ),
        transform: transform,
        artifacts: TKVLMGroundArtifacts(
            overlay: overlayURL.path,
            request: requestURL.path,
            response: responseURL.path,
            rawOutput: mlxArtifacts?.rawOutput.path,
            parsedPoint: mlxArtifacts?.parsedPoint.path,
            transform: mlxArtifacts?.transform.path,
            modelMetadata: mlxArtifacts?.modelMetadata.path
        )
    )
}

func makeVLMProvider(
    _ providerName: String,
    baseURL: String? = nil,
    model: String? = nil,
    modelPath: String? = nil,
    apiKeyEnv: String? = nil,
    allowRemoteVLM: Bool = false,
    maxTokens: Int = 64,
    temperature: Double = 0,
    seed: Int = 0,
    promptTemplate: String = "gui-grounding-v1",
    allowModelDownload: Bool = false,
    mlxHelperPath: String? = nil,
    httpTransport: TKVLMHTTPTransport? = nil
) throws -> any TKVLMProvider {
    switch providerName.lowercased() {
    case "mock":
        return TKMockVLMProvider()
    case "mlx-swift-lm":
        return TKMLXSwiftLMProvider(
            model: model,
            modelPath: modelPath,
            maxTokens: maxTokens,
            temperature: temperature,
            seed: seed,
            promptTemplate: promptTemplate,
            allowModelDownload: allowModelDownload,
            helperPath: mlxHelperPath
        )
    case "openai-compatible":
        guard let baseURL, !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TKVLMGroundingFailure(
                code: "vlm_openai_base_url_required",
                message: "--base-url is required for --provider openai-compatible",
                hint: "Use a localhost OpenAI-compatible endpoint first, for example http://127.0.0.1:8000/v1"
            )
        }
        guard let url = URL(string: baseURL), let host = url.host else {
            throw TKVLMGroundingFailure(
                code: "vlm_openai_base_url_invalid",
                message: "Invalid OpenAI-compatible base URL \(baseURL)",
                hint: "Pass an absolute http(s) URL ending at the OpenAI-compatible /v1 base"
            )
        }
        if !isLocalVLMHost(host), !allowRemoteVLM {
            throw TKVLMGroundingFailure(
                code: "vlm_remote_provider_requires_approval",
                message: "Remote VLM provider \(host) requires explicit approval",
                hint: "Pass --allow-remote-vlm only when screenshot upload is intended"
            )
        }
        let resolvedAPIKey: String?
        if let apiKeyEnv, !apiKeyEnv.isEmpty {
            guard let value = ProcessInfo.processInfo.environment[apiKeyEnv], !value.isEmpty else {
                throw TKVLMGroundingFailure(
                    code: "vlm_api_key_missing",
                    message: "Environment variable \(apiKeyEnv) is not set",
                    hint: "Set \(apiKeyEnv) or omit --api-key-env for local unauthenticated providers"
                )
            }
            resolvedAPIKey = value
        } else {
            resolvedAPIKey = nil
        }
        return TKOpenAICompatibleVLMProvider(
            baseURL: url,
            model: model ?? "vlm-grounding",
            apiKey: resolvedAPIKey,
            transport: httpTransport
        )
    default:
        throw TKVLMGroundingFailure(
            code: "vlm_unsupported_provider",
            message: "Unsupported VLM provider \(providerName)",
            hint: "Supported providers: mock, openai-compatible"
        )
    }
}

func vlmRequestNetwork(for provider: String) -> String {
    switch provider {
    case "mock":
        return "not-used"
    case "mlx-swift-lm":
        return "local-helper"
    default:
        return "openai-compatible"
    }
}

func isLocalVLMHost(_ host: String) -> Bool {
    let normalized = host.lowercased()
    return normalized == "localhost" ||
        normalized == "127.0.0.1" ||
        normalized == "::1" ||
        normalized == "[::1]"
}

func redactedVLMBaseURL(_ baseURL: String?) -> String? {
    guard let baseURL, var components = URLComponents(string: baseURL) else {
        return baseURL
    }
    if components.password != nil {
        components.password = "<redacted>"
    }
    if components.user != nil {
        components.user = "<redacted>"
    }
    return components.string ?? baseURL
}

func makeOpenAICompatibleRequestBody(model: String, target: String, imageBase64: String) throws -> Data {
    let payload: [String: Any] = [
        "model": model,
        "temperature": 0,
        "messages": [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "Return only one point for the UI target in normalized_0_1000 coordinates as (x,y). Target: \(target)",
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/png;base64,\(imageBase64)",
                        ],
                    ],
                ],
            ],
        ],
    ]
    guard JSONSerialization.isValidJSONObject(payload) else {
        throw TKVLMGroundingFailure(
            code: "vlm_provider_request_invalid",
            message: "OpenAI-compatible request payload is not valid JSON",
            hint: nil
        )
    }
    return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
}

func postVLMJSON(url: URL, body: Data, headers: [String: String]) throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = 30
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<(Data, URLResponse), Error>?
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
            result = .failure(error)
        } else {
            result = .success((data ?? Data(), response ?? URLResponse()))
        }
        semaphore.signal()
    }.resume()
    semaphore.wait()

    let (data, response) = try result?.get() ?? (Data(), URLResponse())
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw TKVLMGroundingFailure(
            code: "vlm_provider_request_failed",
            message: "OpenAI-compatible provider returned HTTP \(http.statusCode): \(body)",
            hint: "Inspect provider logs and response body"
        )
    }
    return data
}

func parseOpenAICompatibleText(_ data: Data) throws -> String {
    let object: Any
    do {
        object = try JSONSerialization.jsonObject(with: data)
    } catch {
        throw TKVLMGroundingFailure(
            code: "vlm_provider_response_invalid",
            message: "OpenAI-compatible response is not valid JSON: \(error)",
            hint: "Expected choices[0].message.content"
        )
    }
    guard let dictionary = object as? [String: Any],
          let choices = dictionary["choices"] as? [[String: Any]],
          let firstChoice = choices.first,
          let message = firstChoice["message"] as? [String: Any],
          let content = message["content"] else {
        throw TKVLMGroundingFailure(
            code: "vlm_provider_response_invalid",
            message: "OpenAI-compatible response missing choices[0].message.content",
            hint: "Expected Chat Completions-compatible JSON"
        )
    }
    if let text = content as? String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let blocks = content as? [[String: Any]] {
        let text = blocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" || block["type"] == nil else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }
    }
    throw TKVLMGroundingFailure(
        code: "vlm_provider_response_invalid",
        message: "OpenAI-compatible message content is not text",
        hint: "Return a point as (x,y) or JSON"
    )
}

func parseVLMNormalizedPoint(_ rawText: String) throws -> TKVLMNormalizedPoint {
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    if let data = trimmed.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data),
       let point = parseVLMPointObject(object) {
        return point
    }

    let pattern = #"\(?\s*([0-9]+(?:\.[0-9]+)?)\s*,\s*([0-9]+(?:\.[0-9]+)?)\s*\)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)),
          match.numberOfRanges >= 3,
          let xRange = Range(match.range(at: 1), in: trimmed),
          let yRange = Range(match.range(at: 2), in: trimmed),
          let x = Double(trimmed[xRange]),
          let y = Double(trimmed[yRange]) else {
        throw TKVLMGroundingFailure(
            code: "vlm_provider_point_parse_failed",
            message: "Could not parse normalized point from provider text: \(rawText)",
            hint: "Return (x,y), {\"x\":500,\"y\":331}, or {\"point\":{\"x\":500,\"y\":331}}"
        )
    }
    return TKVLMNormalizedPoint(x: x, y: y)
}

func parseVLMPointObject(_ object: Any) -> TKVLMNormalizedPoint? {
    guard let dictionary = object as? [String: Any] else {
        return nil
    }
    if let x = numericValue(dictionary["x"]), let y = numericValue(dictionary["y"]) {
        let scale = numericValue(dictionary["scale"]) ?? 1000
        return TKVLMNormalizedPoint(x: x, y: y, scale: scale)
    }
    for key in ["point", "normalized", "normalizedPoint"] {
        if let nested = dictionary[key], let point = parseVLMPointObject(nested) {
            return point
        }
    }
    return nil
}

func numericValue(_ value: Any?) -> Double? {
    switch value {
    case let value as Double:
        return value
    case let value as Int:
        return Double(value)
    case let value as NSNumber:
        return value.doubleValue
    case let value as String:
        return Double(value)
    default:
        return nil
    }
}

func loadVLMImage(path: String) throws -> TKVLMGroundImage {
    guard let size = imagePixelSize(path: path) else {
        throw TKVLMGroundingFailure(
            code: "vlm_image_metadata_unavailable",
            message: "Could not read image dimensions from \(path)",
            hint: "Use a PNG or JPEG screenshot artifact"
        )
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    return TKVLMGroundImage(path: path, width: Double(size.width), height: Double(size.height), sha256: digest)
}

func loadVLMCoordinateContract(path: String) throws -> TKVLMCoordinateContract {
    do {
        return try JSONDecoder().decode(TKVLMCoordinateContract.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    } catch {
        throw TKVLMGroundingFailure(
            code: "vlm_coordinate_contract_invalid",
            message: "Could not decode coordinate contract at \(path): \(error)",
            hint: "Expected P0E coordinate-contract.json"
        )
    }
}

func validateVLMCoordinateContract(_ contract: TKVLMCoordinateContract, path: String) throws {
    guard contract.canonicalTapSpace == "runtime-point" else {
        throw TKVLMGroundingFailure(
            code: "vlm_coordinate_contract_invalid",
            message: "Unsupported canonicalTapSpace \(contract.canonicalTapSpace) in \(path)",
            hint: "P3 grounding requires canonicalTapSpace=runtime-point"
        )
    }
    guard contract.runtimeScreenshotSpace.kind == "runtime-point-sized-image" else {
        throw TKVLMGroundingFailure(
            code: "vlm_coordinate_contract_invalid",
            message: "Unsupported runtimeScreenshotSpace.kind \(contract.runtimeScreenshotSpace.kind) in \(path)",
            hint: "P3 grounding requires runtime-point-sized-image"
        )
    }
}

func normalizedPointToRuntimePoint(
    _ point: TKVLMNormalizedPoint,
    image: TKVLMGroundImage,
    contract: TKVLMCoordinateContract
) throws -> TKVLMRuntimePoint {
    guard point.scale > 0 else {
        throw TKVLMGroundingFailure(
            code: "vlm_coordinate_contract_invalid",
            message: "Normalized scale must be greater than zero",
            hint: "Use normalized_0_1000 points"
        )
    }
    guard (0...point.scale).contains(point.x), (0...point.scale).contains(point.y) else {
        throw TKVLMGroundingFailure(
            code: "vlm_point_out_of_bounds",
            message: "Normalized point (\(point.x), \(point.y)) is outside 0...\(point.scale)",
            hint: "Grounding providers must return a point inside normalized_0_1000"
        )
    }
    let imageX = image.width * point.x / point.scale
    let imageY = image.height * point.y / point.scale
    let runtimeX = imageX * contract.runtimeGeometry.width / image.width
    let runtimeY = imageY * contract.runtimeGeometry.height / image.height
    return TKVLMRuntimePoint(x: runtimeX, y: runtimeY)
}

func validateVLMRuntimePoint(_ point: TKVLMRuntimePoint, contract: TKVLMCoordinateContract) throws {
    guard point.x >= 0, point.y >= 0,
          point.x <= contract.runtimeGeometry.width,
          point.y <= contract.runtimeGeometry.height else {
        throw TKVLMGroundingFailure(
            code: "vlm_point_out_of_bounds",
            message: "Runtime point (\(point.x), \(point.y)) is outside runtime geometry \(contract.runtimeGeometry.width)x\(contract.runtimeGeometry.height)",
            hint: "Check coordinate-contract.json and provider response"
        )
    }
}

func resolveVLMOutputDirectory(_ outputDirectory: String?, imageURL: URL) throws -> URL {
    if let outputDirectory {
        return URL(fileURLWithPath: outputDirectory)
    }
    return imageURL.deletingLastPathComponent().appendingPathComponent("vlm-grounding", isDirectory: true)
}

func writeVLMJSON<T: Encodable>(_ value: T, to url: URL) throws {
    do {
        try encodeJSON(value).data(using: .utf8)?.write(to: url, options: .atomic)
    } catch let failure as TKVLMGroundingFailure {
        throw failure
    } catch {
        throw TKVLMGroundingFailure(
            code: "vlm_artifact_write_failed",
            message: "Could not write VLM artifact \(url.path): \(error)",
            hint: "Check --output-dir permissions"
        )
    }
}

func writeVLMOverlay(
    imageURL: URL,
    outputURL: URL,
    target: String,
    normalized: TKVLMNormalizedPoint,
    runtimePoint: TKVLMRuntimePoint,
    sha256: String
) throws {
    guard let source = NSImage(contentsOf: imageURL),
          let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw TKVLMGroundingFailure(
            code: "vlm_overlay_failed",
            message: "Could not read image for overlay at \(imageURL.path)",
            hint: "Use a PNG or JPEG screenshot artifact"
        )
    }

    let width = cgImage.width
    let height = cgImage.height
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw TKVLMGroundingFailure(code: "vlm_overlay_failed", message: "Could not allocate overlay bitmap", hint: nil)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let x = CGFloat(runtimePoint.x)
    let y = CGFloat(Double(height) - runtimePoint.y)
    NSColor.systemRed.setStroke()
    NSColor.systemRed.withAlphaComponent(0.18).setFill()
    let circle = NSBezierPath(ovalIn: NSRect(x: x - 16, y: y - 16, width: 32, height: 32))
    circle.lineWidth = 3
    circle.fill()
    circle.stroke()

    let cross = NSBezierPath()
    cross.move(to: NSPoint(x: x - 24, y: y))
    cross.line(to: NSPoint(x: x + 24, y: y))
    cross.move(to: NSPoint(x: x, y: y - 24))
    cross.line(to: NSPoint(x: x, y: y + 24))
    cross.lineWidth = 2
    cross.stroke()

    let label = "target: \(target)  normalized: \(formatDouble(normalized.x)),\(formatDouble(normalized.y))  runtime: \(formatDouble(runtimePoint.x)),\(formatDouble(runtimePoint.y))  sha: \(String(sha256.prefix(12)))"
    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor.white,
        .backgroundColor: NSColor.black.withAlphaComponent(0.72),
    ]
    let labelRect = NSRect(x: 12, y: max(12, CGFloat(height) - 52), width: CGFloat(width - 24), height: 40)
    (label as NSString).draw(in: labelRect, withAttributes: labelAttributes)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw TKVLMGroundingFailure(code: "vlm_overlay_failed", message: "Could not encode overlay PNG", hint: nil)
    }
    do {
        try data.write(to: outputURL, options: .atomic)
    } catch {
        throw TKVLMGroundingFailure(
            code: "vlm_artifact_write_failed",
            message: "Could not write overlay \(outputURL.path): \(error)",
            hint: "Check --output-dir permissions"
        )
    }
}

func formatDouble(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(format: "%.2f", value)
}
