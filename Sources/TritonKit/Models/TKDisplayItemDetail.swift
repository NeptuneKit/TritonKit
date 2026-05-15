import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct TKDisplayItemDetail: Codable {
    public let displayItemOid: UInt
    public let groupScreenshot: Data?
    public let soloScreenshot: Data?
    public let frameValue: CGRect
    public let boundsValue: CGRect
    public let hiddenValue: Bool
    public let alphaValue: Float
    public let customDisplayTitle: String?
    public let danceUISource: String?
    public let attributesGroupList: [TKAttributesGroup]
    public let customAttrGroupList: [TKAttributesGroup]
    public let subitems: [TKDisplayItem]?
    public let failureCode: Int

    public init(
        displayItemOid: UInt,
        groupScreenshot: Data? = nil,
        soloScreenshot: Data? = nil,
        frameValue: CGRect = .zero,
        boundsValue: CGRect = .zero,
        hiddenValue: Bool = false,
        alphaValue: Float = 1,
        customDisplayTitle: String? = nil,
        danceUISource: String? = nil,
        attributesGroupList: [TKAttributesGroup] = [],
        customAttrGroupList: [TKAttributesGroup] = [],
        subitems: [TKDisplayItem]? = nil,
        failureCode: Int = 0
    ) {
        self.displayItemOid = displayItemOid
        self.groupScreenshot = groupScreenshot
        self.soloScreenshot = soloScreenshot
        self.frameValue = frameValue
        self.boundsValue = boundsValue
        self.hiddenValue = hiddenValue
        self.alphaValue = alphaValue
        self.customDisplayTitle = customDisplayTitle
        self.danceUISource = danceUISource
        self.attributesGroupList = attributesGroupList
        self.customAttrGroupList = customAttrGroupList
        self.subitems = subitems
        self.failureCode = failureCode
    }
}
