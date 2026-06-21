import Darwin
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("P22 VLM model cache", .serialized)
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

    @Test("model download invokes external helper and records ready cache entry")
    func modelDownloadInvokesExternalHelper() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tritonkit-vlm-download-\(UUID().uuidString)", isDirectory: true)
        defer {
            unsetenv("TRITON_MLX_MODEL_CACHE")
            try? FileManager.default.removeItem(at: root)
        }
        setenv("TRITON_MLX_MODEL_CACHE", root.path, 1)

        let helper = root.appendingPathComponent("download-helper.sh")
        let marker = root.appendingPathComponent("download-request-path.txt")
        let script = """
        #!/bin/sh
        set -eu
        if [ "$1" != "download" ] || [ "$2" != "--request" ]; then
          echo unexpected-args >&2
          exit 64
        fi
        printf "%s" "$3" > "\(marker.path)"
        python3 - "$3" <<'PY'
        import json
        import pathlib
        import sys

        request = json.load(open(sys.argv[1]))
        assert request["provider"] == "mlx-swift-lm"
        assert request["model"] == "mlx-community/Fake-VL-4bit"
        out = pathlib.Path(request["outputPath"])
        out.mkdir(parents=True, exist_ok=True)
        (out / "config.json").write_text('{"model_type":"fake_vl"}')
        (out / "tokenizer.json").write_text("{}")
        (out / "model.safetensors").write_text("weights")
        print(json.dumps({"modelPath": str(out), "bytesDownloaded": 7}))
        PY
        """
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try script.write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)

        let response = try downloadVLMModel(
            "mlx-community/Fake-VL-4bit",
            provider: "mlx-swift-lm",
            helperPath: helper.path
        )

        #expect(response.kind == "triton.vlm.model-download-result")
        #expect(response.provider == "mlx-swift-lm")
        #expect(response.model == "mlx-community/Fake-VL-4bit")
        #expect(response.status == "downloaded")
        #expect(response.downloaded)
        #expect(response.bytesDownloaded == 7)
        #expect(response.modelEntry.status == "ready")
        #expect(response.modelEntry.id == "mlx-community/Fake-VL-4bit")
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test("model download fails closed without helper")
    func modelDownloadRequiresHelper() throws {
        do {
            _ = try downloadVLMModel("mlx-community/Fake-VL-4bit", provider: "mlx-swift-lm")
            Issue.record("Expected mlx_helper_required")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "mlx_helper_required")
        }
    }
}
