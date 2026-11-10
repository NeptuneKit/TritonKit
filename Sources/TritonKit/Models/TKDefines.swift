import Foundation
import TritonKitShared

// These types are re-exported from TritonKitShared for convenience
@_exported import enum TritonKitShared.TKRequestType
@_exported import enum TritonKitShared.TKJSONValue
@_exported import struct TritonKitShared.TKMessage
@_exported import struct TritonKitShared.TKErrorPayload
@_exported import struct TritonKitShared.TKRuntimeSemanticActionArgument
@_exported import struct TritonKitShared.TKRuntimeSemanticActionDescriptor
@_exported import struct TritonKitShared.TKRuntimeSemanticDomainManifest
@_exported import struct TritonKitShared.TKRuntimeSemanticDomainState
@_exported import struct TritonKitShared.TKRuntimeSemanticRedaction
@_exported import struct TritonKitShared.TKRuntimeSemanticStateField
@_exported import struct TritonKitShared.TKRuntimeSemanticStateResponse

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

public enum TKEventHandlerType: Int, Codable {
    case targetAction = 0
    case gesture = 1
}

// MARK: - Type Aliases

public typealias TKAttrIdentifier = String
public typealias TKAttrGroupIdentifier = String
public typealias TKAttrSectionIdentifier = String
