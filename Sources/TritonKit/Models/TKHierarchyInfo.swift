import Foundation
import TritonKitShared

public struct TKHierarchyInfo: Codable {
    public let displayItems: [TKDisplayItem]
    public let appInfo: TKAppInfo
    public let serverVersion: Int
    public let colorAlias: [String: String]
    public let collapsedClassList: [String]
    public let controllerContext: TKHierarchyControllerContext?

    public init(
        displayItems: [TKDisplayItem],
        appInfo: TKAppInfo = TKAppInfo(),
        serverVersion: Int = 7,
        controllerContext: TKHierarchyControllerContext? = nil
    ) {
        self.displayItems = displayItems
        self.appInfo = appInfo
        self.serverVersion = serverVersion
        self.colorAlias = [:]
        self.collapsedClassList = []
        self.controllerContext = controllerContext
    }
}
