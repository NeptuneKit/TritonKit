import Foundation

public struct TKVLMCompareResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let target: String
    public let image: TKVLMGroundImage
    public let results: [TKVLMCompareProviderResult]
    public let agreement: TKVLMCompareAgreement
    public let artifacts: TKVLMCompareArtifacts

    public init(
        ok: Bool = true,
        schemaVersion: Int = 1,
        kind: String = "triton.vlm.compare-result",
        target: String,
        image: TKVLMGroundImage,
        results: [TKVLMCompareProviderResult],
        agreement: TKVLMCompareAgreement,
        artifacts: TKVLMCompareArtifacts
    ) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.target = target
        self.image = image
        self.results = results
        self.agreement = agreement
        self.artifacts = artifacts
    }
}

public struct TKVLMCompareProviderResult: Codable, Equatable, Sendable {
    public let provider: String
    public let status: String
    public let model: String?
    public let runtimePoint: TKVLMRuntimePoint?
    public let latencyMs: Int
    public let errorCode: String?
    public let message: String?
    public let artifacts: TKVLMGroundArtifacts?

    public init(
        provider: String,
        status: String,
        model: String? = nil,
        runtimePoint: TKVLMRuntimePoint? = nil,
        latencyMs: Int,
        errorCode: String? = nil,
        message: String? = nil,
        artifacts: TKVLMGroundArtifacts? = nil
    ) {
        self.provider = provider
        self.status = status
        self.model = model
        self.runtimePoint = runtimePoint
        self.latencyMs = latencyMs
        self.errorCode = errorCode
        self.message = message
        self.artifacts = artifacts
    }
}

public struct TKVLMCompareAgreement: Codable, Equatable, Sendable {
    public let maxDistancePoints: Double?
    public let meanDistancePoints: Double?
    public let withinThreshold: Bool
    public let thresholdPoints: Double
    public let passedProviderCount: Int
    public let failedProviderCount: Int

    public init(
        maxDistancePoints: Double?,
        meanDistancePoints: Double?,
        withinThreshold: Bool,
        thresholdPoints: Double,
        passedProviderCount: Int,
        failedProviderCount: Int
    ) {
        self.maxDistancePoints = maxDistancePoints
        self.meanDistancePoints = meanDistancePoints
        self.withinThreshold = withinThreshold
        self.thresholdPoints = thresholdPoints
        self.passedProviderCount = passedProviderCount
        self.failedProviderCount = failedProviderCount
    }
}

public struct TKVLMCompareArtifacts: Codable, Equatable, Sendable {
    public let comparisonOverlay: String
    public let results: String

    public init(comparisonOverlay: String, results: String) {
        self.comparisonOverlay = comparisonOverlay
        self.results = results
    }
}
