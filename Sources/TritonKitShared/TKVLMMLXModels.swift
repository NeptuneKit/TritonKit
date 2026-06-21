import Foundation

public struct TKVLMProviderListResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let providers: [TKVLMProviderDescriptor]

    public init(
        ok: Bool = true,
        schemaVersion: Int = 1,
        kind: String = "triton.vlm.providers-result",
        providers: [TKVLMProviderDescriptor]
    ) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.providers = providers
    }
}

public struct TKVLMProviderDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let status: String
    public let requiresNetwork: Bool
    public let requiresModel: Bool
    public let defaultEnabledInCI: Bool
    public let supports: [String]
    public let coordinateOutputs: [String]
    public let runnerIntegration: TKVLMProviderRunnerIntegration?

    public init(
        id: String,
        kind: String,
        status: String,
        requiresNetwork: Bool,
        requiresModel: Bool,
        defaultEnabledInCI: Bool,
        supports: [String],
        coordinateOutputs: [String],
        runnerIntegration: TKVLMProviderRunnerIntegration? = nil
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.requiresNetwork = requiresNetwork
        self.requiresModel = requiresModel
        self.defaultEnabledInCI = defaultEnabledInCI
        self.supports = supports
        self.coordinateOutputs = coordinateOutputs
        self.runnerIntegration = runnerIntegration
    }
}

public struct TKVLMProviderRunnerIntegration: Codable, Equatable, Sendable {
    public let supported: Bool
    public let requiresAllowVLM: Bool
    public let defaultEnabled: Bool

    public init(supported: Bool, requiresAllowVLM: Bool, defaultEnabled: Bool) {
        self.supported = supported
        self.requiresAllowVLM = requiresAllowVLM
        self.defaultEnabled = defaultEnabled
    }
}

public struct TKVLMMLXParsedPointArtifact: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let provider: String
    public let rawOutput: String
    public let normalizedPoint: TKVLMNormalizedPoint

    public init(
        schemaVersion: Int = 1,
        provider: String = "mlx-swift-lm",
        rawOutput: String,
        normalizedPoint: TKVLMNormalizedPoint
    ) {
        self.schemaVersion = schemaVersion
        self.provider = provider
        self.rawOutput = rawOutput
        self.normalizedPoint = normalizedPoint
    }
}

public struct TKVLMMLXModelMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let provider: String
    public let model: String?
    public let modelPath: String?
    public let loadedAt: String
    public let quantization: String
    public let mlxSwiftLMVersion: String
    public let device: String
    public let downloadAllowed: Bool
    public let mode: String

    public init(
        schemaVersion: Int = 1,
        provider: String = "mlx-swift-lm",
        model: String?,
        modelPath: String?,
        loadedAt: String,
        quantization: String = "unknown",
        mlxSwiftLMVersion: String = "not-linked-p17-fake-helper",
        device: String = "apple-silicon",
        downloadAllowed: Bool,
        mode: String = "fake-helper"
    ) {
        self.schemaVersion = schemaVersion
        self.provider = provider
        self.model = model
        self.modelPath = modelPath
        self.loadedAt = loadedAt
        self.quantization = quantization
        self.mlxSwiftLMVersion = mlxSwiftLMVersion
        self.device = device
        self.downloadAllowed = downloadAllowed
        self.mode = mode
    }
}
