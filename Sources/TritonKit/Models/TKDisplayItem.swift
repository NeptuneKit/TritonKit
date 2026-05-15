import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct TKDisplayItem: Codable {
    public var subitems: [TKDisplayItem]
    public var isHidden: Bool
    public var alpha: Float
    public var frame: CGRect
    public var bounds: CGRect
    public var soloScreenshot: Data?
    public var groupScreenshot: Data?
    public var viewObject: TKObject?
    public var layerObject: TKObject?
    public var hostViewControllerObject: TKObject?
    public var attributesGroupList: [TKAttributesGroup]
    public var customAttrGroupList: [TKAttributesGroup]
    public var eventHandlers: [TKEventHandler]
    public var representedAsKeyWindow: Bool
    public var backgroundColor: TKColor?
    public var shouldCaptureImage: Bool
    public var customDisplayTitle: String?
    public var danceuiSource: String?
    public var doNotFetchScreenshotReason: TKDoNotFetchScreenshotReason
    public var noPreview: Bool
    public var previewZIndex: Int
    public var preferToBeCollapsed: Bool
    public var isExpanded: Bool
    public var indentLevel: Int

    // MARK: - Computed

    public var isExpandable: Bool { !subitems.isEmpty }
    public var allAttrGroups: [TKAttributesGroup] { attributesGroupList + customAttrGroupList }

    public init(
        subitems: [TKDisplayItem] = [],
        isHidden: Bool = false,
        alpha: Float = 1,
        frame: CGRect = .zero,
        bounds: CGRect = .zero,
        viewObject: TKObject? = nil,
        layerObject: TKObject? = nil,
        hostViewControllerObject: TKObject? = nil,
        attributesGroupList: [TKAttributesGroup] = [],
        customAttrGroupList: [TKAttributesGroup] = [],
        eventHandlers: [TKEventHandler] = [],
        representedAsKeyWindow: Bool = false,
        backgroundColor: TKColor? = nil,
        shouldCaptureImage: Bool = true,
        customDisplayTitle: String? = nil,
        indentLevel: Int = 0
    ) {
        self.subitems = subitems
        self.isHidden = isHidden
        self.alpha = alpha
        self.frame = frame
        self.bounds = bounds
        self.viewObject = viewObject
        self.layerObject = layerObject
        self.hostViewControllerObject = hostViewControllerObject
        self.attributesGroupList = attributesGroupList
        self.customAttrGroupList = customAttrGroupList
        self.eventHandlers = eventHandlers
        self.representedAsKeyWindow = representedAsKeyWindow
        self.backgroundColor = backgroundColor
        self.shouldCaptureImage = shouldCaptureImage
        self.customDisplayTitle = customDisplayTitle
        self.doNotFetchScreenshotReason = .permitted
        self.noPreview = false
        self.previewZIndex = -1
        self.preferToBeCollapsed = false
        self.isExpanded = indentLevel <= 2
        self.indentLevel = indentLevel
        self.soloScreenshot = nil
        self.groupScreenshot = nil
        self.danceuiSource = nil
    }

    /// Flatten hierarchical items into a one-dimensional array (depth-first)
    public static func flatItems(from items: [TKDisplayItem]) -> [TKDisplayItem] {
        var result: [TKDisplayItem] = []
        for item in items {
            result.append(item)
            result.append(contentsOf: flatItems(from: item.subitems))
        }
        return result
    }
}

// MARK: - Color

public struct TKColor: Codable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    #if canImport(UIKit)
    public init?(uiColor: UIColor?) {
        guard let cgColor = uiColor?.cgColor, let components = cgColor.components else { return nil }
        let count = cgColor.numberOfComponents
        if count >= 3 {
            self.red = components[0]
            self.green = components[1]
            self.blue = components[2]
            self.alpha = count >= 4 ? components[3] : 1
        } else if count == 2 {
            self.red = components[0]
            self.green = components[0]
            self.blue = components[0]
            self.alpha = components[1]
        } else {
            return nil
        }
    }
    #endif
}
