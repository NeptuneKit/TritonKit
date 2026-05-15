import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Enums

public enum TKRequestType: String, Codable {
    case ping
    case appInfo
    case hierarchy
    case hierarchyDetails
    case modifyAttribute
    case modifyAttributePatch
    case invokeMethod
    case fetchObject
    case fetchImageViewImage
    case modifyRecognizerEnable
    case allAttrGroups
    case allSelectorNames
    case modifyCustomAttribute
    case cancelHierarchyDetails
}

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

// MARK: - Message Protocol

public struct TKMessage: Codable {
    public let id: Int
    public let type: TKRequestType
    public let payload: Data?

    public init(id: Int, type: TKRequestType, payload: Data? = nil) {
        self.id = id
        self.type = type
        self.payload = payload
    }
}

public struct TKErrorPayload: Codable {
    public let message: String
    public let code: Int

    public init(message: String, code: Int = -1) {
        self.message = message
        self.code = code
    }
}

// MARK: - Type Aliases

public typealias TKAttrIdentifier = String
public typealias TKAttrGroupIdentifier = String
public typealias TKAttrSectionIdentifier = String
