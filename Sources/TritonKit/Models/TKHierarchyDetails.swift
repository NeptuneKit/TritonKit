import Foundation
import TritonKitShared

/// The selected layer's own pixels (solo), its rendered subtree (group), or both.
public enum TKNodeScreenshotMode: String, Codable, CaseIterable {
    case none, solo, group, both
}

public struct TKHierarchyDetailsRequest: Codable, Equatable {
    public static let maximumOIDCount = 8
    public static let maximumPixelCount = 1_048_576
    public let oids: [UInt]
    public let screenshots: TKNodeScreenshotMode
    public let includeAttributes: Bool
    public let maxPixelCount: Int

    public init(oids: [UInt], screenshots: TKNodeScreenshotMode = .both,
                includeAttributes: Bool = true, maxPixelCount: Int = 262_144) {
        self.oids = oids
        self.screenshots = screenshots
        self.includeAttributes = includeAttributes
        self.maxPixelCount = maxPixelCount
    }

    public var validationError: String? {
        guard !oids.isEmpty, oids.count <= Self.maximumOIDCount else {
            return "Provide between 1 and \(Self.maximumOIDCount) object IDs"
        }
        guard oids.allSatisfy({ $0 > 0 }), Set(oids).count == oids.count else {
            return "Object IDs must be positive and unique"
        }
        guard (1...Self.maximumPixelCount).contains(maxPixelCount) else {
            return "maxPixelCount must be between 1 and \(Self.maximumPixelCount)"
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey { case oids, screenshots, includeAttributes, maxPixelCount }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(oids: try values.decode([UInt].self, forKey: .oids),
                  screenshots: try values.decodeIfPresent(TKNodeScreenshotMode.self, forKey: .screenshots) ?? .both,
                  includeAttributes: try values.decodeIfPresent(Bool.self, forKey: .includeAttributes) ?? true,
                  maxPixelCount: try values.decodeIfPresent(Int.self, forKey: .maxPixelCount) ?? 262_144)
    }
}

public struct TKHierarchyDetailsError: Codable, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct TKHierarchyDetailsResponse: Codable {
    public let ok: Bool
    public let partial: Bool
    public let details: [TKDisplayItemDetail]
    public let error: TKHierarchyDetailsError?
    public let outcome: String?
    public let uiHealth: TKRuntimeUIHealthSnapshot?

    public init(ok: Bool, partial: Bool = false, details: [TKDisplayItemDetail] = [],
                error: TKHierarchyDetailsError? = nil, outcome: String? = nil,
                uiHealth: TKRuntimeUIHealthSnapshot? = nil) {
        self.ok = ok
        self.partial = partial
        self.details = details
        self.error = error
        self.outcome = outcome
        self.uiHealth = uiHealth
    }
}
