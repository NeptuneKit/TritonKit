import Foundation

public struct TKVLMModelListResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let provider: String
    public let cacheDir: String
    public let models: [TKVLMModelCacheEntry]

    public init(ok: Bool = true, schemaVersion: Int = 1, kind: String = "triton.vlm.model-list-result", provider: String, cacheDir: String, models: [TKVLMModelCacheEntry]) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.provider = provider
        self.cacheDir = cacheDir
        self.models = models
    }
}

public struct TKVLMModelInspectResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let provider: String
    public let model: TKVLMModelCacheEntry

    public init(ok: Bool = true, schemaVersion: Int = 1, kind: String = "triton.vlm.model-inspect-result", provider: String, model: TKVLMModelCacheEntry) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.provider = provider
        self.model = model
    }
}

public struct TKVLMModelPreflightResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let provider: String
    public let modelPath: String
    public let checks: [TKVLMModelPreflightCheck]

    public init(ok: Bool, schemaVersion: Int = 1, kind: String = "triton.vlm.model-preflight-result", provider: String, modelPath: String, checks: [TKVLMModelPreflightCheck]) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.provider = provider
        self.modelPath = modelPath
        self.checks = checks
    }
}

public struct TKVLMModelMutationResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let provider: String
    public let cacheDir: String
    public let removed: [String]
    public let kept: [String]

    public init(ok: Bool = true, schemaVersion: Int = 1, kind: String, provider: String, cacheDir: String, removed: [String], kept: [String]) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.provider = provider
        self.cacheDir = cacheDir
        self.removed = removed
        self.kept = kept
    }
}

public struct TKVLMModelDownloadResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let provider: String
    public let model: String
    public let cacheDir: String
    public let modelPath: String
    public let status: String
    public let downloaded: Bool
    public let bytesDownloaded: Int64?
    public let modelEntry: TKVLMModelCacheEntry

    public init(
        ok: Bool = true,
        schemaVersion: Int = 1,
        kind: String = "triton.vlm.model-download-result",
        provider: String,
        model: String,
        cacheDir: String,
        modelPath: String,
        status: String,
        downloaded: Bool,
        bytesDownloaded: Int64?,
        modelEntry: TKVLMModelCacheEntry
    ) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.provider = provider
        self.model = model
        self.cacheDir = cacheDir
        self.modelPath = modelPath
        self.status = status
        self.downloaded = downloaded
        self.bytesDownloaded = bytesDownloaded
        self.modelEntry = modelEntry
    }
}

public struct TKVLMModelCacheEntry: Codable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let sizeBytes: Int64
    public let createdAt: String?
    public let lastUsedAt: String?
    public let hasTokenizer: Bool
    public let hasConfig: Bool
    public let hasWeights: Bool
    public let status: String
    public let metadata: TKVLMModelCacheMetadata

    public init(
        id: String,
        path: String,
        sizeBytes: Int64,
        createdAt: String?,
        lastUsedAt: String?,
        hasTokenizer: Bool,
        hasConfig: Bool,
        hasWeights: Bool,
        status: String,
        metadata: TKVLMModelCacheMetadata
    ) {
        self.id = id
        self.path = path
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.hasTokenizer = hasTokenizer
        self.hasConfig = hasConfig
        self.hasWeights = hasWeights
        self.status = status
        self.metadata = metadata
    }
}

public struct TKVLMModelCacheMetadata: Codable, Equatable, Sendable {
    public let architecture: String
    public let quantization: String
    public let supportsImageInput: Bool

    public init(architecture: String, quantization: String, supportsImageInput: Bool) {
        self.architecture = architecture
        self.quantization = quantization
        self.supportsImageInput = supportsImageInput
    }
}

public struct TKVLMModelPreflightCheck: Codable, Equatable, Sendable {
    public let name: String
    public let status: String
    public let message: String?

    public init(name: String, status: String, message: String? = nil) {
        self.name = name
        self.status = status
        self.message = message
    }
}
