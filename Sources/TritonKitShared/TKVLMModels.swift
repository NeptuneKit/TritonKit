import Foundation

public struct TKVLMGroundResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let schemaVersion: Int
    public let kind: String
    public let provider: String
    public let model: String?
    public let baseURL: String?
    public let target: String
    public let image: TKVLMGroundImage
    public let coordinateContract: TKVLMGroundCoordinateContractRef
    public let point: TKVLMGroundPoint
    public let transform: TKVLMCoordinateTransform
    public let artifacts: TKVLMGroundArtifacts

    public init(
        ok: Bool = true,
        schemaVersion: Int = 1,
        kind: String = "triton.vlm.ground-result",
        provider: String,
        model: String? = nil,
        baseURL: String? = nil,
        target: String,
        image: TKVLMGroundImage,
        coordinateContract: TKVLMGroundCoordinateContractRef,
        point: TKVLMGroundPoint,
        transform: TKVLMCoordinateTransform,
        artifacts: TKVLMGroundArtifacts
    ) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.target = target
        self.image = image
        self.coordinateContract = coordinateContract
        self.point = point
        self.transform = transform
        self.artifacts = artifacts
    }
}

public struct TKVLMGroundImage: Codable, Equatable, Sendable {
    public let path: String
    public let width: Double
    public let height: Double
    public let sha256: String

    public init(path: String, width: Double, height: Double, sha256: String) {
        self.path = path
        self.width = width
        self.height = height
        self.sha256 = sha256
    }
}

public struct TKVLMGroundCoordinateContractRef: Codable, Equatable, Sendable {
    public let path: String
    public let canonicalTapSpace: String

    public init(path: String, canonicalTapSpace: String) {
        self.path = path
        self.canonicalTapSpace = canonicalTapSpace
    }
}

public struct TKVLMGroundPoint: Codable, Equatable, Sendable {
    public let normalized: TKVLMNormalizedPoint
    public let runtimePoint: TKVLMRuntimePoint
    public let coordinateSpace: String

    public init(normalized: TKVLMNormalizedPoint, runtimePoint: TKVLMRuntimePoint, coordinateSpace: String) {
        self.normalized = normalized
        self.runtimePoint = runtimePoint
        self.coordinateSpace = coordinateSpace
    }
}

public struct TKVLMNormalizedPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let scale: Double

    public init(x: Double, y: Double, scale: Double = 1000) {
        self.x = x
        self.y = y
        self.scale = scale
    }
}

public struct TKVLMRuntimePoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct TKVLMCoordinateTransform: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let inputSpace: String
    public let imageSpace: String
    public let outputSpace: String
    public let imageWidth: Double
    public let imageHeight: Double
    public let runtimeWidth: Double
    public let runtimeHeight: Double
    public let scale: Double
    public let orientation: String
    public let source: String

    public init(
        schemaVersion: Int = 1,
        inputSpace: String,
        imageSpace: String,
        outputSpace: String,
        imageWidth: Double,
        imageHeight: Double,
        runtimeWidth: Double,
        runtimeHeight: Double,
        scale: Double,
        orientation: String,
        source: String
    ) {
        self.schemaVersion = schemaVersion
        self.inputSpace = inputSpace
        self.imageSpace = imageSpace
        self.outputSpace = outputSpace
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.runtimeWidth = runtimeWidth
        self.runtimeHeight = runtimeHeight
        self.scale = scale
        self.orientation = orientation
        self.source = source
    }
}

public struct TKVLMGroundArtifacts: Codable, Equatable, Sendable {
    public let overlay: String
    public let request: String
    public let response: String

    public init(overlay: String, request: String, response: String) {
        self.overlay = overlay
        self.request = request
        self.response = response
    }
}
