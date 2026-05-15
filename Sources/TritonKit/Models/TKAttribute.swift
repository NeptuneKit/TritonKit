import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct TKAttribute: Codable {
    public let identifier: TKAttrIdentifier
    public let displayTitle: String?
    public let attrType: Int
    public let value: TKAttributeValue?
    public let extraValue: TKAttributeValue?
    public let customSetterID: String?

    public init(identifier: TKAttrIdentifier, displayTitle: String? = nil, attrType: Int, value: TKAttributeValue? = nil, extraValue: TKAttributeValue? = nil, customSetterID: String? = nil) {
        self.identifier = identifier
        self.displayTitle = displayTitle
        self.attrType = attrType
        self.value = value
        self.extraValue = extraValue
        self.customSetterID = customSetterID
    }
}

public enum TKAttributeValue: Codable {
    case null
    case string(String)
    case number(Double)
    case bool(Bool)
    case stringArray([String])
    case numberArray([Double])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let str = try? container.decode(String.self) { self = .string(str); return }
        if let num = try? container.decode(Double.self) { self = .number(num); return }
        if let bol = try? container.decode(Bool.self) { self = .bool(bol); return }
        if let arr = try? container.decode([String].self) { self = .stringArray(arr); return }
        if let arr = try? container.decode([Double].self) { self = .numberArray(arr); return }
        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .stringArray(let v): try container.encode(v)
        case .numberArray(let v): try container.encode(v)
        }
    }
}
