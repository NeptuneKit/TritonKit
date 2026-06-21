import Darwin
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("P22 VLM model cache")
struct VLMModelCacheTests {
    @Test("model cache list inspect preflight prune and remove stay local")
    func modelCacheLifecycle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tritonkit-vlm-cache-\(UUID().uuidString)", isDirectory: true)
        defer {
            unsetenv("TRITON_MLX_MODEL_CACHE")
            try? FileManager.default.removeItem(at: root)
        }
        setenv("TRITON_MLX_MODEL_CACHE", root.path, 1)

        let ready = root.appendingPathComponent("mlx-community__Fake-VL-4bit", isDirectory: true)
        try FileManager.default.createDirectory(at: ready, withIntermediateDirectories: true)
        try #"{"architectures":["FakeVLForConditionalGeneration"],"vision_config":{}}"#.data(using: .utf8)!.write(to: ready.appendingPathComponent("config.json"))
        try Data("{}".utf8).write(to: ready.appendingPathComponent("tokenizer.json"))
        try Data("weights".utf8).write(to: ready.appendingPathComponent("model.safetensors"))

        let incomplete = root.appendingPathComponent("download-incomplete", isDirectory: true)
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)

        let list = try listVLMModels(provider: "mlx-swift-lm")
        #expect(list.cacheDir == root.path)
        #expect(list.models.contains { $0.status == "ready" && $0.id == "mlx-community/Fake-VL-4bit" })

        let inspect = try inspectVLMModel(ready.path, provider: "mlx-swift-lm")
        #expect(inspect.model.hasConfig)
        #expect(inspect.model.hasTokenizer)
        #expect(inspect.model.hasWeights)
        #expect(inspect.model.status == "ready")
        #expect(inspect.model.metadata.quantization == "4bit")

        let preflight = try preflightVLMModel(ready.path, provider: "mlx-swift-lm")
        #expect(preflight.ok)
        #expect(preflight.checks.contains { $0.name == "path_exists" && $0.status == "passed" })

        let prune = try pruneVLMModels(provider: "mlx-swift-lm")
        #expect(prune.kept.map { URL(fileURLWithPath: $0).lastPathComponent }.contains(ready.lastPathComponent))
        #expect(prune.removed.map { URL(fileURLWithPath: $0).lastPathComponent }.contains(incomplete.lastPathComponent))
        #expect(FileManager.default.fileExists(atPath: ready.path))
        #expect(!FileManager.default.fileExists(atPath: incomplete.path))

        let remove = try removeVLMModel(ready.path, provider: "mlx-swift-lm")
        #expect(remove.removed == [ready.path])
        #expect(!FileManager.default.fileExists(atPath: ready.path))
    }
}
