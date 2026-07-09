import Foundation

// MARK: - Request Types

public enum TKRequestType: String, Codable, CaseIterable {
    case ping
    case appInfo
    case runtimeManifest
    case stateApp
    case stateScene
    case stateRoute
    case stateResponder
    case runtimeSnapshot
    case webViewList
    case webViewCurrent
    case webViewSnapshot
    case webViewBridgeCall
    case webViewBridgePost
    case webViewTap
    case webViewWait
    case webViewEvents
    case webViewLedger
    case semanticAction
    case runtimeLedger
    case hierarchy
    case hierarchyDetails
    case modifyAttribute
    case modifyAttributePatch
    case invokeMethod
    case fetchObject
    case input
    case accessibility
    case hitTest
    case screenshot
    case geometry
    case fetchImageViewImage
    case modifyRecognizerEnable
    case allAttrGroups
    case allSelectorNames
    case modifyCustomAttribute
    case cancelHierarchyDetails
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
