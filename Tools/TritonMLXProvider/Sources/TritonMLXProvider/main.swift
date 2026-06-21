import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers

struct HelperRequest: Decodable {
    struct Image: Decodable {
        let path: String
        let width: Int?
        let height: Int?
        let sha256: String?
    }

    let schemaVersion: Int
    let provider: String
    let model: String?
    let modelPath: String?
    let image: Image
    let target: String
    let maxTokens: Int
    let temperature: Double
    let seed: Int?
    let promptTemplate: String?
    let allowModelDownload: Bool
}

enum HelperError: LocalizedError {
    case invalidArguments
    case unsupportedCommand(String)
    case requestNotFound(String)
    case invalidRequest(String)
    case missingModel
    case downloadNotAllowed(String)
    case modelPathNotFound(String)
    case imageNotFound(String)
    case invalidModelResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "usage: triton-mlx-provider ground --request <request.json>"
        case .unsupportedCommand(let command):
            return "unsupported command: \(command)"
        case .requestNotFound(let path):
            return "request file does not exist: \(path)"
        case .invalidRequest(let reason):
            return "invalid request: \(reason)"
        case .missingModel:
            return "request must include modelPath or model"
        case .downloadNotAllowed(let model):
            return "model download is disabled for \(model)"
        case .modelPathNotFound(let path):
            return "modelPath is not a directory: \(path)"
        case .imageNotFound(let path):
            return "image file does not exist: \(path)"
        case .invalidModelResponse(let reason):
            return "invalid model response: \(reason)"
        }
    }
}

struct ModelPointResponse: Decodable {
    let x: Double?
    let y: Double?
    let scale: Double?
    let error: String?
}

struct ProviderPoint: Encodable {
    let x: Double
    let y: Double
    let scale: Double
}

struct ProviderResponse: Encodable {
    let schemaVersion: Int
    let provider: String
    let model: String?
    let coordinateSpace: String
    let point: ProviderPoint
    let confidence: Double
    let rationale: String
    let rawText: String
}

@main
struct TritonMLXProvider {
    static func main() async {
        do {
            let response = try await run(arguments: Array(CommandLine.arguments.dropFirst()))
            FileHandle.standardOutput.write(Data(response.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            FileHandle.standardError.write(Data("triton-mlx-provider: \(message)\n".utf8))
            exit(1)
        }
    }

    private static func run(arguments: [String]) async throws -> String {
        guard let command = arguments.first else {
            throw HelperError.invalidArguments
        }
        guard command == "ground" else {
            throw HelperError.unsupportedCommand(command)
        }
        guard let requestIndex = arguments.firstIndex(of: "--request"),
              arguments.indices.contains(requestIndex + 1) else {
            throw HelperError.invalidArguments
        }
        let requestPath = arguments[requestIndex + 1]
        guard FileManager.default.fileExists(atPath: requestPath) else {
            throw HelperError.requestNotFound(requestPath)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: requestPath))
        let request: HelperRequest
        do {
            request = try JSONDecoder().decode(HelperRequest.self, from: data)
        } catch {
            throw HelperError.invalidRequest(error.localizedDescription)
        }
        return try await ground(request)
    }

    private static func ground(_ request: HelperRequest) async throws -> String {
        guard request.schemaVersion == 1 else {
            throw HelperError.invalidRequest("schemaVersion must be 1")
        }
        guard request.provider == "mlx-swift-lm" else {
            throw HelperError.invalidRequest("provider must be mlx-swift-lm")
        }
        guard FileManager.default.fileExists(atPath: request.image.path) else {
            throw HelperError.imageNotFound(request.image.path)
        }

        let modelContext: ModelContext
        if let modelPath = nonEmpty(request.modelPath) {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: modelPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw HelperError.modelPathNotFound(modelPath)
            }
            modelContext = try await loadModel(
                from: URL(fileURLWithPath: modelPath, isDirectory: true),
                using: #huggingFaceTokenizerLoader()
            )
        } else if let model = nonEmpty(request.model) {
            guard request.allowModelDownload else {
                throw HelperError.downloadNotAllowed(model)
            }
            modelContext = try await loadModel(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                id: model,
                progressHandler: { progress in
                    let text = "download \(model): \(Int(progress.fractionCompleted * 100))%\n"
                    FileHandle.standardError.write(Data(text.utf8))
                }
            )
        } else {
            throw HelperError.missingModel
        }

        let parameters = GenerateParameters(
            maxTokens: max(1, request.maxTokens),
            temperature: Float(request.temperature),
            topP: 1,
            topK: 0
        )
        let session = ChatSession(modelContext, generateParameters: parameters)
        let prompt = prompt(for: request.target, template: request.promptTemplate)
        let rawText = try await session.respond(
            to: prompt,
            image: .url(URL(fileURLWithPath: request.image.path))
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let point = try parsePoint(rawText)
        let response = ProviderResponse(
            schemaVersion: 1,
            provider: "mlx-swift-lm",
            model: request.model ?? request.modelPath,
            coordinateSpace: "normalized_0_1000",
            point: point,
            confidence: 1,
            rationale: "local MLX VLM point grounding response",
            rawText: rawText
        )
        let data = try JSONEncoder.sorted.encode(response)
        return String(decoding: data, as: UTF8.self)
    }

    private static func prompt(for target: String, template: String?) -> String {
        if let template = nonEmpty(template) {
            return template.replacingOccurrences(of: "{{target}}", with: target)
        }
        return """
        You are a GUI visual grounding model.
        Given the screenshot and this target description, locate the center point of the target UI element:
        \(target)

        Return ONLY compact JSON:
        {"x": <number>, "y": <number>, "scale": 1000}

        Coordinates must be normalized to [0, 1000].
        If the target is not visible, return {"error":"target_not_visible"}.
        Do not return explanations, markdown, actions, or multiple points.
        """
    }

    private static func parsePoint(_ rawText: String) throws -> ProviderPoint {
        guard let jsonRange = rawText.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) else {
            throw HelperError.invalidModelResponse("expected compact JSON object with x, y, and scale")
        }
        let jsonText = String(rawText[jsonRange])
        let decoded: ModelPointResponse
        do {
            decoded = try JSONDecoder().decode(ModelPointResponse.self, from: Data(jsonText.utf8))
        } catch {
            throw HelperError.invalidModelResponse(error.localizedDescription)
        }
        if let error = decoded.error, !error.isEmpty {
            throw HelperError.invalidModelResponse(error)
        }
        guard let x = decoded.x, let y = decoded.y else {
            throw HelperError.invalidModelResponse("response must include numeric x and y")
        }
        let scale = decoded.scale ?? 1000
        guard (0...scale).contains(x), (0...scale).contains(y), scale > 0 else {
            throw HelperError.invalidModelResponse("point must be within normalized output scale")
        }
        return ProviderPoint(x: x, y: y, scale: scale)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
