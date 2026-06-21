import Foundation
import HuggingFace
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
    case invalidRepositoryID(String)

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
        case .invalidRepositoryID(let id):
            return "invalid Hugging Face repository id: \(id)"
        }
    }
}

struct HubDownloader: MLXLMCommon.Downloader {
    private let upstream = HubClient()

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repoID = Repo.ID(rawValue: id) else {
            throw HelperError.invalidRepositoryID(id)
        }
        return try await upstream.downloadSnapshot(
            of: repoID,
            revision: revision ?? "main",
            matching: patterns,
            localFilesOnly: false,
            progressHandler: { progress in
                progressHandler(progress)
            }
        )
    }
}

struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return TransformersTokenizerAdapter(upstream: upstream)
    }
}

struct TransformersTokenizerAdapter: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        try upstream.applyChatTemplate(
            messages: messages,
            tools: tools,
            additionalContext: additionalContext
        )
    }
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
                using: TransformersTokenizerLoader()
            )
        } else if let model = nonEmpty(request.model) {
            guard request.allowModelDownload else {
                throw HelperError.downloadNotAllowed(model)
            }
            modelContext = try await loadModel(
                from: HubDownloader(),
                using: TransformersTokenizerLoader(),
                id: model,
                useLatest: false,
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
        let prompt = prompt(for: request.target)
        return try await session.respond(
            to: prompt,
            image: .url(URL(fileURLWithPath: request.image.path))
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func prompt(for target: String) -> String {
        """
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

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
