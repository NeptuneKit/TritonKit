import Foundation
import CoreGraphics
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
    public var screenshotRef: String?  // HTTP data ref from CLI's /data endpoint
    public var viewObject: TKObject?
    public var layerObject: TKObject?
    public var hostViewControllerObject: TKObject?
    public var attributesGroupList: [TKAttributesGroup]
    public var customAttrGroupList: [TKAttributesGroup]
    public var eventHandlers: [TKEventHandler]
    public var representedAsKeyWindow: Bool
    public var backgroundColor: TKColor?
    public var layerPosition: CGPoint?
    public var layerAnchorPoint: CGPoint?
    public var layerZPosition: CGFloat?
    public var layerTransform: [Double]?
    public var layerSublayerTransform: [Double]?
    public var layerMasksToBounds: Bool?
    public var layerCornerRadius: CGFloat?
    public var layerOpacity: Float?
    public var layerIsHidden: Bool?
    public var layerContentsScale: CGFloat?
    public var layerContentsGravity: String?
    public var layerContentsRect: CGRect?
    public var layerBorderWidth: CGFloat?
    public var layerBorderColor: TKColor?
    public var layerShadowOpacity: Float?
    public var layerShadowRadius: CGFloat?
    public var layerShadowOffset: CGSize?
    public var layerShadowColor: TKColor?
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
        screenshotRef: String? = nil,
        viewObject: TKObject? = nil,
        layerObject: TKObject? = nil,
        hostViewControllerObject: TKObject? = nil,
        attributesGroupList: [TKAttributesGroup] = [],
        customAttrGroupList: [TKAttributesGroup] = [],
        eventHandlers: [TKEventHandler] = [],
        representedAsKeyWindow: Bool = false,
        backgroundColor: TKColor? = nil,
        layerPosition: CGPoint? = nil,
        layerAnchorPoint: CGPoint? = nil,
        layerZPosition: CGFloat? = nil,
        layerTransform: [Double]? = nil,
        layerSublayerTransform: [Double]? = nil,
        layerMasksToBounds: Bool? = nil,
        layerCornerRadius: CGFloat? = nil,
        layerOpacity: Float? = nil,
        layerIsHidden: Bool? = nil,
        layerContentsScale: CGFloat? = nil,
        layerContentsGravity: String? = nil,
        layerContentsRect: CGRect? = nil,
        layerBorderWidth: CGFloat? = nil,
        layerBorderColor: TKColor? = nil,
        layerShadowOpacity: Float? = nil,
        layerShadowRadius: CGFloat? = nil,
        layerShadowOffset: CGSize? = nil,
        layerShadowColor: TKColor? = nil,
        shouldCaptureImage: Bool = true,
        customDisplayTitle: String? = nil,
        indentLevel: Int = 0
    ) {
        self.subitems = subitems
        self.isHidden = isHidden
        self.alpha = tkFinite(alpha)
        self.frame = tkFinite(frame)
        self.bounds = tkFinite(bounds)
        self.screenshotRef = screenshotRef
        self.viewObject = viewObject
        self.layerObject = layerObject
        self.hostViewControllerObject = hostViewControllerObject
        self.attributesGroupList = attributesGroupList
        self.customAttrGroupList = customAttrGroupList
        self.eventHandlers = eventHandlers
        self.representedAsKeyWindow = representedAsKeyWindow
        self.backgroundColor = backgroundColor
        self.layerPosition = layerPosition.map(tkFinite)
        self.layerAnchorPoint = layerAnchorPoint.map(tkFinite)
        self.layerZPosition = layerZPosition.map(tkFinite)
        self.layerTransform = layerTransform?.map(tkFinite)
        self.layerSublayerTransform = layerSublayerTransform?.map(tkFinite)
        self.layerMasksToBounds = layerMasksToBounds
        self.layerCornerRadius = layerCornerRadius.map(tkFinite)
        self.layerOpacity = layerOpacity.map(tkFinite)
        self.layerIsHidden = layerIsHidden
        self.layerContentsScale = layerContentsScale.map(tkFinite)
        self.layerContentsGravity = layerContentsGravity
        self.layerContentsRect = layerContentsRect.map(tkFinite)
        self.layerBorderWidth = layerBorderWidth.map(tkFinite)
        self.layerBorderColor = layerBorderColor
        self.layerShadowOpacity = layerShadowOpacity.map(tkFinite)
        self.layerShadowRadius = layerShadowRadius.map(tkFinite)
        self.layerShadowOffset = layerShadowOffset.map(tkFinite)
        self.layerShadowColor = layerShadowColor
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

private func tkFinite(_ value: Double) -> Double {
    value.isFinite ? value : 0
}

private func tkFinite(_ value: Float) -> Float {
    value.isFinite ? value : 0
}

private func tkFinite(_ value: CGFloat) -> CGFloat {
    value.isFinite ? value : 0
}

private func tkFinite(_ point: CGPoint) -> CGPoint {
    CGPoint(x: tkFinite(point.x), y: tkFinite(point.y))
}

private func tkFinite(_ size: CGSize) -> CGSize {
    CGSize(width: tkFinite(size.width), height: tkFinite(size.height))
}

private func tkFinite(_ rect: CGRect) -> CGRect {
    CGRect(origin: tkFinite(rect.origin), size: tkFinite(rect.size))
}

// MARK: - Color

public struct TKColor: Codable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = tkFinite(red)
        self.green = tkFinite(green)
        self.blue = tkFinite(blue)
        self.alpha = tkFinite(alpha)
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
