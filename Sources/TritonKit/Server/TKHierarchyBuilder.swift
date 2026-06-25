#if canImport(UIKit)
import Foundation
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
        guard TritonKit.isRuntimeEnabled else { return [] }

        // Collect all layer data in one MainActor hop (sync recursion)
        let rootLayerData = await MainActor.run { () -> [LayerData] in
            var remainingScreenshotItems = max(0, maxScreenshotItems)
            let windows: [UIWindow]
            if #available(iOS 15.0, *) {
                windows = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
            } else {
                windows = UIApplication.shared.windows
            }
            return windows.compactMap {
                collectLayerData(
                    from: $0.layer,
                    depth: 0,
                    maxDepth: maxDepth,
                    maxChildrenPerNode: maxChildrenPerNode,
                    includeScreenshots: includeScreenshots,
                    remainingScreenshotItems: &remainingScreenshotItems
                )
            }
        }

        // Build items from collected data (no MainActor needed)
        return rootLayerData.compactMap { buildItem(from: $0) }
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
        let classChain: [String]
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
        let screenshot: Data?
        let children: [LayerData]
    }

    @MainActor
    private static func collectLayerData(
        from layer: CALayer,
        depth: Int,
        maxDepth: Int,
        maxChildrenPerNode: Int,
        includeScreenshots: Bool,
        remainingScreenshotItems: inout Int
    ) -> LayerData? {
        guard depth < maxDepth else { return nil }
        guard let view = layer.tk_hostView else { return nil }

        let rawChildren = layer.sublayers ?? []
        let limitedChildren = rawChildren.prefix(maxChildrenPerNode)
        let children = limitedChildren.compactMap {
            collectLayerData(
                from: $0,
                depth: depth + 1,
                maxDepth: maxDepth,
                maxChildrenPerNode: maxChildrenPerNode,
                includeScreenshots: includeScreenshots,
                remainingScreenshotItems: &remainingScreenshotItems
            )
        }

        let hostViewController = view.tk_hostViewController
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

        let absoluteFrame = view.superview?.convert(layer.frame, to: nil) ?? layer.frame
        let screenshot: Data?
        if shouldCaptureScreenshot(
            includeScreenshots: includeScreenshots,
            remaining: remainingScreenshotItems,
            view: view,
            layer: layer,
            frame: absoluteFrame,
            depth: depth
        ) {
            screenshot = captureScreenshot(for: view)
            if screenshot != nil {
                remainingScreenshotItems -= 1
            }
        } else {
            screenshot = nil
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
            classChain: view.tk_classChain,
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
            screenshot: screenshot,
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
        view: UIView,
        layer: CALayer,
        frame: CGRect,
        depth: Int
    ) -> Bool {
        guard includeScreenshots, remaining > 0 else { return false }
        guard depth > 0 else { return false }
        guard !view.isHidden, !layer.isHidden, view.alpha > 0.01, layer.opacity > 0.01 else { return false }
        guard frame.width >= 4, frame.height >= 4, view.bounds.width >= 4, view.bounds.height >= 4 else { return false }
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        let pixelArea = view.bounds.width * view.bounds.height * scale * scale
        guard pixelArea <= 260_000 else { return false }
        return true
    }

    @MainActor
    private static func captureScreenshot(for view: UIView) -> Data? {
        let bounds = view.bounds
        guard bounds.width >= 1, bounds.height >= 1 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = view.window?.screen.scale ?? UIScreen.main.scale
        format.opaque = view.isOpaque
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        return renderer.pngData { context in
            context.cgContext.translateBy(x: 0, y: bounds.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            view.layer.render(in: context.cgContext)
        }
    }

    // MARK: - Item Building (no MainActor needed)

    private static func buildItem(
        from data: LayerData,
        indent: Int = 0
    ) -> TKDisplayItem {
        let registry = TKObjectRegistry.shared
        let viewOid = data.view.map { registry.register($0) } ?? 0
        let layerOid = registry.register(data.layer)

        let viewObj = TKObject(
            oid: viewOid,
            memoryAddress: data.view.map { "\(Unmanaged.passUnretained($0).toOpaque())" } ?? "",
            classChainList: data.classChain
        )
        let layerObj = TKObject(
            oid: layerOid,
            memoryAddress: "\(Unmanaged.passUnretained(data.layer).toOpaque())",
            classChainList: data.classChain
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
            shouldCaptureImage: data.screenshot != nil,
            indentLevel: indent
        )
        item.groupScreenshot = data.screenshot
        return item
    }
}
#else
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
}
#endif
