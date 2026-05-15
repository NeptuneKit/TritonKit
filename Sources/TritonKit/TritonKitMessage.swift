import Foundation

public struct TritonKitMessage: Codable {
    public let id: Int
    public let type: String
    public let payload: Data?

    public init(id: Int, type: String, payload: Data? = nil) {
        self.id = id
        self.type = type
        self.payload = payload
    }
}

public struct TritonKitError: Codable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

// Request types matching LookinServer protocol
public enum TritonKitRequestType: String, Codable {
    case ping = "ping"
    case appInfo = "appInfo"
    case hierarchy = "hierarchy"
    case hierarchyDetails = "hierarchyDetails"
    case inbuiltAttrModification = "modifyAttribute"
    case attrModificationPatch = "modifyAttributePatch"
    case invokeMethod = "invokeMethod"
    case fetchObject = "fetchObject"
    case fetchImageViewImage = "fetchImageViewImage"
    case modifyRecognizerEnable = "modifyRecognizerEnable"
    case allAttrGroups = "allAttrGroups"
    case allSelectorNames = "allSelectorNames"
    case customAttrModification = "modifyCustomAttribute"
    case cancelHierarchyDetails = "cancelHierarchyDetails"
}
