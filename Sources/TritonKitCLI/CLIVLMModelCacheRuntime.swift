import Foundation
import TritonKitShared

func listVLMModels(provider: String) throws -> TKVLMModelListResponse {
    try validateModelCacheProvider(provider)
    let cache = mlxModelCacheDirectory()
    let models = try modelDirectories(in: cache).map { try inspectModelEntry($0, cache: cache) }
    return TKVLMModelListResponse(provider: provider, cacheDir: cache.path, models: models.sorted { $0.id < $1.id })
}

func inspectVLMModel(_ model: String, provider: String) throws -> TKVLMModelInspectResponse {
    try validateModelCacheProvider(provider)
    let cache = mlxModelCacheDirectory()
    let path = resolveModelPath(model, cache: cache)
    return TKVLMModelInspectResponse(provider: provider, model: try inspectModelEntry(path, cache: cache))
}

func preflightVLMModel(_ model: String, provider: String) throws -> TKVLMModelPreflightResponse {
    try validateModelCacheProvider(provider)
    let cache = mlxModelCacheDirectory()
    let path = resolveModelPath(model, cache: cache)
    let checks = buildModelPreflightChecks(path)
    return TKVLMModelPreflightResponse(
        ok: checks.allSatisfy { $0.status == "passed" || $0.status == "warning" },
        provider: provider,
        modelPath: path.path,
        checks: checks
    )
}

func pruneVLMModels(provider: String) throws -> TKVLMModelMutationResponse {
    try validateModelCacheProvider(provider)
    let cache = mlxModelCacheDirectory()
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    var removed: [String] = []
    var kept: [String] = []
    for url in try modelDirectories(in: cache) {
        let entry = try inspectModelEntry(url, cache: cache)
        if entry.status == "ready" {
            kept.append(url.path)
            continue
        }
        let name = url.lastPathComponent.lowercased()
        if name.contains("tmp") || name.contains("partial") || name.contains("incomplete") || entry.status == "incomplete" {
            try FileManager.default.removeItem(at: url)
            removed.append(url.path)
        } else {
            kept.append(url.path)
        }
    }
    return TKVLMModelMutationResponse(kind: "triton.vlm.model-prune-result", provider: provider, cacheDir: cache.path, removed: removed.sorted(), kept: kept.sorted())
}

func removeVLMModel(_ model: String, provider: String) throws -> TKVLMModelMutationResponse {
    try validateModelCacheProvider(provider)
    let cache = mlxModelCacheDirectory()
    let path = resolveModelPath(model, cache: cache)
    guard FileManager.default.fileExists(atPath: path.path) else {
        throw TKVLMGroundingFailure(code: "mlx_model_not_found", message: "Model does not exist at \(path.path)", hint: "Run triton vlm model list --provider mlx-swift-lm --json")
    }
    try FileManager.default.removeItem(at: path)
    return TKVLMModelMutationResponse(kind: "triton.vlm.model-remove-result", provider: provider, cacheDir: cache.path, removed: [path.path], kept: [])
}

func mlxModelCacheDirectory() -> URL {
    if let override = ProcessInfo.processInfo.environment["TRITON_MLX_MODEL_CACHE"], !override.isEmpty {
        return URL(fileURLWithPath: expandTilde(override), isDirectory: true)
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".cache/triton/mlx-models", isDirectory: true)
}

private func validateModelCacheProvider(_ provider: String) throws {
    guard provider == "mlx-swift-lm" else {
        throw TKVLMGroundingFailure(
            code: "vlm_unsupported_provider",
            message: "VLM model cache commands currently support provider=mlx-swift-lm only",
            hint: "Use --provider mlx-swift-lm"
        )
    }
}

private func resolveModelPath(_ model: String, cache: URL) -> URL {
    let expanded = expandTilde(model)
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
    return cache.appendingPathComponent(model.replacingOccurrences(of: "/", with: "__"), isDirectory: true)
}

private func modelDirectories(in cache: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: cache.path) else {
        return []
    }
    return try FileManager.default.contentsOfDirectory(
        at: cache,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ).filter { url in
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

private func inspectModelEntry(_ url: URL, cache: URL) throws -> TKVLMModelCacheEntry {
    let hasConfig = fileExists(in: url, names: ["config.json", "model_config.json"])
    let hasTokenizer = fileExists(in: url, names: ["tokenizer.json", "tokenizer_config.json", "vocab.json", "merges.txt"])
    let hasWeights = containsWeightFile(url)
    let status = hasConfig && hasTokenizer && hasWeights ? "ready" : "incomplete"
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    let created = (attrs?[.creationDate] as? Date).map(isoTimestamp)
    let modified = (attrs?[.modificationDate] as? Date).map(isoTimestamp)
    return TKVLMModelCacheEntry(
        id: modelID(for: url, cache: cache),
        path: url.path,
        sizeBytes: directorySize(url),
        createdAt: created,
        lastUsedAt: modified,
        hasTokenizer: hasTokenizer,
        hasConfig: hasConfig,
        hasWeights: hasWeights,
        status: status,
        metadata: TKVLMModelCacheMetadata(
            architecture: readArchitecture(url) ?? "unknown-or-detected",
            quantization: detectQuantization(url),
            supportsImageInput: likelySupportsImageInput(url)
        )
    )
}

private func buildModelPreflightChecks(_ path: URL) -> [TKVLMModelPreflightCheck] {
    let exists = FileManager.default.fileExists(atPath: path.path)
    let hasConfig = exists && fileExists(in: path, names: ["config.json", "model_config.json"])
    let hasTokenizer = exists && fileExists(in: path, names: ["tokenizer.json", "tokenizer_config.json", "vocab.json", "merges.txt"])
    let hasWeights = exists && containsWeightFile(path)
    let appleSilicon = hostIsAppleSilicon()
    return [
        TKVLMModelPreflightCheck(name: "path_exists", status: exists ? "passed" : "failed", message: exists ? nil : path.path),
        TKVLMModelPreflightCheck(name: "config_exists", status: hasConfig ? "passed" : "failed"),
        TKVLMModelPreflightCheck(name: "tokenizer_exists", status: hasTokenizer ? "passed" : "failed"),
        TKVLMModelPreflightCheck(name: "weights_exist", status: hasWeights ? "passed" : "failed"),
        TKVLMModelPreflightCheck(name: "image_input_likely", status: likelySupportsImageInput(path) ? "passed" : "warning"),
        TKVLMModelPreflightCheck(name: "apple_silicon", status: appleSilicon ? "passed" : "warning", message: appleSilicon ? nil : "MLX real-model smoke requires Apple Silicon"),
        TKVLMModelPreflightCheck(name: "helper_available", status: "warning", message: "P18 real helper is manual-gate only; CI uses fake provider contract")
    ]
}

private func fileExists(in directory: URL, names: [String]) -> Bool {
    names.contains { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }
}

private func containsWeightFile(_ directory: URL) -> Bool {
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return false }
    for case let url as URL in enumerator {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".safetensors") || name.hasSuffix(".gguf") || name.hasSuffix(".bin") || name.hasSuffix(".mlx") || name.contains("weights") {
            return true
        }
    }
    return false
}

private func directorySize(_ directory: URL) -> Int64 {
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
    var total: Int64 = 0
    for case let url as URL in enumerator {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        total += size
    }
    return total
}

private func readArchitecture(_ directory: URL) -> String? {
    let config = directory.appendingPathComponent("config.json")
    guard let data = try? Data(contentsOf: config),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    return object["architectures"] as? String ??
        (object["architectures"] as? [String])?.first ??
        object["model_type"] as? String
}

private func detectQuantization(_ directory: URL) -> String {
    let path = directory.path.lowercased()
    if path.contains("4bit") || path.contains("4-bit") { return "4bit" }
    if path.contains("8bit") || path.contains("8-bit") { return "8bit" }
    return "unknown"
}

private func likelySupportsImageInput(_ directory: URL) -> Bool {
    let haystack = directory.path.lowercased()
    if haystack.contains("vl") || haystack.contains("vision") || haystack.contains("uground") || haystack.contains("ui-tars") {
        return true
    }
    let config = directory.appendingPathComponent("config.json")
    guard let text = try? String(contentsOf: config, encoding: .utf8).lowercased() else {
        return false
    }
    return text.contains("vision") || text.contains("image") || text.contains("multi_modal") || text.contains("multimodal")
}

private func modelID(for url: URL, cache: URL) -> String {
    let path = url.standardizedFileURL.path
    let cachePath = cache.standardizedFileURL.path
    if path.hasPrefix(cachePath) {
        return String(path.dropFirst(cachePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")).replacingOccurrences(of: "__", with: "/")
    }
    return url.lastPathComponent
}

private func hostIsAppleSilicon() -> Bool {
    #if arch(arm64)
    return true
    #else
    return false
    #endif
}

private func isoTimestamp(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

func expandTilde(_ path: String) -> String {
    if path == "~" {
        return FileManager.default.homeDirectoryForCurrentUser.path
    }
    if path.hasPrefix("~/") {
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(path.dropFirst(2))).path
    }
    return path
}
