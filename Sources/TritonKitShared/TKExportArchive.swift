import Foundation

public enum TKJSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([TKJSONValue])
    case object([String: TKJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([TKJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: TKJSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }

    public static func fromJSONObject(_ value: Any) throws -> TKJSONValue {
        switch value {
        case is NSNull:
            return .null
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .int(value)
        case let value as Double:
            return .double(value)
        case let value as String:
            return .string(value)
        case let value as [Any]:
            return .array(try value.map { try TKJSONValue.fromJSONObject($0) })
        case let value as [String: Any]:
            return .object(try value.mapValues { try TKJSONValue.fromJSONObject($0) })
        default:
            throw NSError(
                domain: "TritonKitShared.TKJSONValue",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported JSON value: \(type(of: value))"]
            )
        }
    }
}

public struct TKExportArchive: Codable, Equatable {
    public let schemaVersion: Int
    public let exportedAt: String
    public let target: TKTargetSummary
    public let hierarchy: TKJSONValue
    public let geometry: TKGeometryResponse?
    public let accessibility: [TKAXNode]?
    public let screenshot: TKScreenshotResponse?

    public init(
        schemaVersion: Int = 1,
        exportedAt: String,
        target: TKTargetSummary,
        hierarchy: TKJSONValue,
        geometry: TKGeometryResponse? = nil,
        accessibility: [TKAXNode]? = nil,
        screenshot: TKScreenshotResponse? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.target = target
        self.hierarchy = hierarchy
        self.geometry = geometry
        self.accessibility = accessibility
        self.screenshot = screenshot
    }
}
