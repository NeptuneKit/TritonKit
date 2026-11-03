#if canImport(UIKit)
import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif
import UIKit

public enum TKHierarchyBuilder {
    public static let defaultMaxDepth = 64
    public static let defaultMaxChildrenPerNode = 200
    public static let defaultMaxScreenshotItems = 32

    public static func buildHierarchy(
        maxDepth: Int = defaultMaxDepth,
        maxChildrenPerNode: Int = defaultMaxChildrenPerNode,
        includeScreenshots: Bool = false,
        maxScreenshotItems: Int = defaultMaxScreenshotItems
    ) async -> [TKDisplayItem] {
        await buildHierarchyWithBudget(maxDepth: maxDepth, maxChildrenPerNode: maxChildrenPerNode,
            includeScreenshots: includeScreenshots, maxScreenshotItems: maxScreenshotItems).nodes
    }

    public static func buildHierarchyWithBudget(
        maxDepth: Int = defaultMaxDepth,
        maxChildrenPerNode: Int = defaultMaxChildrenPerNode,
        includeScreenshots: Bool = false,
        maxScreenshotItems: Int = defaultMaxScreenshotItems,
        maxNodes: Int = 800,
        timeoutMilliseconds: Double = 2_000
    ) async -> TKBoundedNodeCollection<TKDisplayItem> {
        guard TritonKit.isRuntimeEnabled else {
            return .init(nodes: [], collection: .init(visitedNodes: 0, limitReasons: []))
        }
        let collected = await MainActor.run { () -> ([LayerData], TKCollectionBudgetSummary) in
            var context = TKCollectionBudgetState(limits: .init(maxNodes: maxNodes,
                maxDepth: max(0, maxDepth - 1), maxChildren: maxChildrenPerNode, timeoutMilliseconds: timeoutMilliseconds))
            var remainingScreenshotItems = max(0, maxScreenshotItems)
            var remainingScreenshotPixels = 4_194_304
            let windows: [UIWindow]
            if #available(iOS 15.0, *) {
                windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
            } else { windows = UIApplication.shared.windows }
            var data: [LayerData] = []
            let businessWindows = windows.filter { !($0 is TKRuntimeInspectorOverlayWindow) }
            let count = context.childCount(businessWindows.count)
            for window in businessWindows.prefix(count) {
                if context.isExhausted() { break }
                if let item = collectLayerData(from: window.layer, depth: 0, context: &context,
                    includeScreenshots: includeScreenshots, remainingScreenshotItems: &remainingScreenshotItems,
                    remainingScreenshotPixels: &remainingScreenshotPixels) {
                    data.append(item)
                }
            }
            return (data, context.summary)
        }
        return .init(nodes: collected.0.map { buildItem(from: $0) }, collection: collected.1)
    }

    // MARK: - Data Collection (sync, on MainActor)

    private struct LayerData {
        let view: UIView?
        let layer: CALayer
        let isHidden: Bool
        let alpha: Float
        let frame: CGRect
        let bounds: CGRect
        let isKeyWindow: Bool
        let bgCGColor: CGColor?
        let viewClassChain: [String]?
        let layerClassChain: [String]
        let hostViewController: UIViewController?
        let vcClassChain: [String]?
        let layerPosition: CGPoint
        let layerAnchorPoint: CGPoint
        let layerZPosition: CGFloat
        let layerTransform: [Double]
        let layerSublayerTransform: [Double]
        let layerMasksToBounds: Bool
        let layerCornerRadius: CGFloat
        let layerOpacity: Float
        let layerIsHidden: Bool
        let layerContentsScale: CGFloat
        let layerContentsGravity: String
        let layerContentsRect: CGRect
        let layerBorderWidth: CGFloat
        let layerBorderColor: CGColor?
        let layerShadowOpacity: Float
        let layerShadowRadius: CGFloat
        let layerShadowOffset: CGSize
        let layerShadowColor: CGColor?
        let groupScreenshot: Data?
        let soloScreenshot: Data?
        let children: [LayerData]
    }

    @MainActor
    private static func collectLayerData(
        from layer: CALayer,
        depth: Int,
        context: inout TKCollectionBudgetState,
        includeScreenshots: Bool,
        remainingScreenshotItems: inout Int,
        remainingScreenshotPixels: inout Int
    ) -> LayerData? {
        guard context.admit(depth: depth) else { return nil }
        let view = layer.tk_hostView
        guard !layer.tk_isInspectorOverlay else { return nil }
        let rawChildren = layer.sublayers ?? []
        let count = context.childCount(rawChildren.count)
        var children: [LayerData] = []
        for child in rawChildren.prefix(count) {
            if context.isExhausted() { break }
            if let data = collectLayerData(from: child, depth: depth + 1, context: &context,
                includeScreenshots: includeScreenshots, remainingScreenshotItems: &remainingScreenshotItems,
                    remainingScreenshotPixels: &remainingScreenshotPixels) { children.append(data) }
        }

        let hostViewController = view?.tk_hostViewController
        let vcChain: [String]? = hostViewController.map { vc in
            var chain: [String] = []
            var cls: AnyClass = type(of: vc)
            while true {
                chain.append(NSStringFromClass(cls))
                guard let sup = cls.superclass() else { break }
                cls = sup
            }
            return chain
        }

        let absoluteFrame = layer.tk_inspectionFrame
        var groupScreenshot: Data?
        var soloScreenshot: Data?
        if !context.isExhausted(), shouldCaptureScreenshot(
            includeScreenshots: includeScreenshots,
            remaining: remainingScreenshotItems,
            view: view,
            layer: layer,
            frame: absoluteFrame,
            depth: depth
        ) {
            let pixelLimit = min(260_000, remainingScreenshotPixels / 2)
            if pixelLimit > 0 {
                let group = TKLayerScreenshotCapture.capture(layer, solo: false, maxPixelCount: pixelLimit)
                remainingScreenshotPixels -= group.pixelCount
                groupScreenshot = group.data
                if !context.isExhausted(), !Task.isCancelled {
                    let solo = TKLayerScreenshotCapture.capture(layer, solo: true, maxPixelCount: pixelLimit)
                    remainingScreenshotPixels -= solo.pixelCount
                    soloScreenshot = solo.data
                }
                if groupScreenshot != nil || soloScreenshot != nil { remainingScreenshotItems -= 1 }
            }
        }

        return LayerData(
            view: view,
            layer: layer,
            isHidden: layer.isHidden,
            alpha: Float(layer.opacity),
            frame: absoluteFrame,
            bounds: layer.bounds,
            isKeyWindow: (view as? UIWindow)?.isKeyWindow ?? false,
            bgCGColor: layer.backgroundColor,
            viewClassChain: view?.tk_classChain,
            layerClassChain: layer.tk_classChain,
            hostViewController: hostViewController,
            vcClassChain: vcChain,
            layerPosition: layer.position,
            layerAnchorPoint: layer.anchorPoint,
            layerZPosition: layer.zPosition,
            layerTransform: transformArray(layer.transform),
            layerSublayerTransform: transformArray(layer.sublayerTransform),
            layerMasksToBounds: layer.masksToBounds,
            layerCornerRadius: layer.cornerRadius,
            layerOpacity: layer.opacity,
            layerIsHidden: layer.isHidden,
            layerContentsScale: layer.contentsScale,
            layerContentsGravity: layer.contentsGravity.rawValue,
            layerContentsRect: layer.contentsRect,
            layerBorderWidth: layer.borderWidth,
            layerBorderColor: layer.borderColor,
            layerShadowOpacity: layer.shadowOpacity,
            layerShadowRadius: layer.shadowRadius,
            layerShadowOffset: layer.shadowOffset,
            layerShadowColor: layer.shadowColor,
            groupScreenshot: groupScreenshot,
            soloScreenshot: soloScreenshot,
            children: children
        )
    }

    private static func transformArray(_ transform: CATransform3D) -> [Double] {
        [
            transform.m11, transform.m12, transform.m13, transform.m14,
            transform.m21, transform.m22, transform.m23, transform.m24,
            transform.m31, transform.m32, transform.m33, transform.m34,
            transform.m41, transform.m42, transform.m43, transform.m44,
        ].map(Double.init)
    }

    @MainActor
    private static func shouldCaptureScreenshot(
        includeScreenshots: Bool,
        remaining: Int,
        view: UIView?,
        layer: CALayer,
        frame: CGRect,
        depth: Int
    ) -> Bool {
        guard includeScreenshots, remaining > 0 else { return false }
        guard depth > 0 else { return false }
        guard !(view?.isHidden ?? false), !layer.isHidden, (view?.alpha ?? 1) > 0.01, layer.opacity > 0.01 else { return false }
        guard frame.width >= 4, frame.height >= 4, layer.bounds.width >= 4, layer.bounds.height >= 4 else { return false }
        guard frame.width.isFinite, frame.height.isFinite else { return false }
        return true
    }

    // MARK: - Item Building (no MainActor needed)

    private static func buildItem(
        from data: LayerData,
        indent: Int = 0
    ) -> TKDisplayItem {
        let registry = TKObjectRegistry.shared
        let layerOid = registry.register(data.layer)
        let viewObj = data.view.map { view in
            TKObject(oid: registry.register(view),
                     memoryAddress: "\(Unmanaged.passUnretained(view).toOpaque())",
                     classChainList: data.viewClassChain ?? [])
        }
        let layerObj = TKObject(
            oid: layerOid,
            memoryAddress: "\(Unmanaged.passUnretained(data.layer).toOpaque())",
            classChainList: data.layerClassChain
        )

        var vcObj: TKObject? = nil
        if let vc = data.hostViewController, let vcChain = data.vcClassChain {
            let oid = registry.register(vc)
            vcObj = TKObject(oid: oid, memoryAddress: "\(Unmanaged.passUnretained(vc).toOpaque())", classChainList: vcChain)
        }

        let bgColor = data.bgCGColor.flatMap { TKColor(uiColor: UIColor(cgColor: $0)) }
        let borderColor = data.layerBorderColor.flatMap { TKColor(uiColor: UIColor(cgColor: $0)) }
        let shadowColor = data.layerShadowColor.flatMap { TKColor(uiColor: UIColor(cgColor: $0)) }

        let subitems = data.children.map { child in
            buildItem(from: child, indent: indent + 1)
        }

        var item = TKDisplayItem(
            subitems: subitems,
            isHidden: data.isHidden,
            alpha: data.alpha,
            frame: data.frame,
            bounds: data.bounds,
            viewObject: viewObj,
            layerObject: layerObj,
            hostViewControllerObject: vcObj,
            representedAsKeyWindow: data.isKeyWindow,
            backgroundColor: bgColor,
            layerPosition: data.layerPosition,
            layerAnchorPoint: data.layerAnchorPoint,
            layerZPosition: data.layerZPosition,
            layerTransform: data.layerTransform,
            layerSublayerTransform: data.layerSublayerTransform,
            layerMasksToBounds: data.layerMasksToBounds,
            layerCornerRadius: data.layerCornerRadius,
            layerOpacity: data.layerOpacity,
            layerIsHidden: data.layerIsHidden,
            layerContentsScale: data.layerContentsScale,
            layerContentsGravity: data.layerContentsGravity,
            layerContentsRect: data.layerContentsRect,
            layerBorderWidth: data.layerBorderWidth,
            layerBorderColor: borderColor,
            layerShadowOpacity: data.layerShadowOpacity,
            layerShadowRadius: data.layerShadowRadius,
            layerShadowOffset: data.layerShadowOffset,
            layerShadowColor: shadowColor,
            shouldCaptureImage: data.groupScreenshot != nil || data.soloScreenshot != nil,
            indentLevel: indent
        )
        item.groupScreenshot = data.groupScreenshot
        item.soloScreenshot = data.soloScreenshot
        return item
    }
}
#else
import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif
public enum TKHierarchyBuilder {
    public static let defaultMaxDepth = 64
    public static let defaultMaxChildrenPerNode = 200

    public static func buildHierarchy(
        maxDepth: Int = defaultMaxDepth,
        maxChildrenPerNode: Int = defaultMaxChildrenPerNode,
        includeScreenshots: Bool = false,
        maxScreenshotItems: Int = 0
    ) async -> [TKDisplayItem] {
        []
    }
    public static func buildHierarchyWithBudget(
        maxDepth: Int = defaultMaxDepth, maxChildrenPerNode: Int = defaultMaxChildrenPerNode,
        includeScreenshots: Bool = false, maxScreenshotItems: Int = 0,
        maxNodes: Int = 800, timeoutMilliseconds: Double = 2_000
    ) async -> TKBoundedNodeCollection<TKDisplayItem> {
        .init(nodes: [], collection: .init(visitedNodes: 0, limitReasons: []))
    }

}
#endif
