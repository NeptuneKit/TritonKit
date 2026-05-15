import Foundation
import TritonKitShared

// These types are re-exported from TritonKitShared for convenience
@_exported import enum TritonKitShared.TKRequestType
@_exported import struct TritonKitShared.TKMessage
@_exported import struct TritonKitShared.TKErrorPayload

// MARK: - iOS-specific Enums

public enum TKDeviceType: Int, Codable {
    case simulator = 0
    case iPad = 1
    case others = 2
}

public enum TKDoNotFetchScreenshotReason: Int, Codable {
    case permitted = 0
    case tooLarge = 1
    case userConfig = 2
}

public enum TKConstraintItemType: Int, Codable {
    case unknown = 0
    case null = 1
    case view = 2
    case selfRef = 3
    case superRef = 4
    case layoutGuide = 5
}

public enum TKEventHandlerType: Int, Codable {
    case targetAction = 0
    case gesture = 1
}

public enum TKAttributesSectionStyle: Int, Codable {
    case defaultStyle = 0
    case style0 = 1
    case style1 = 2
    case style2 = 3
}

// MARK: - Type Aliases

public typealias TKAttrIdentifier = String
public typealias TKAttrGroupIdentifier = String
public typealias TKAttrSectionIdentifier = String
