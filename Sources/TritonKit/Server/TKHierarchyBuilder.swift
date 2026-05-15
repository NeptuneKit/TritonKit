import UIKit

public enum TKHierarchyBuilder {

    public static func buildHierarchy(
        includeScreenshots: Bool = false,
        uploader: TritonKitDataUploader? = nil
    ) async -> [TKDisplayItem] {
        // Collect all layer data in one MainActor hop (sync recursion)
        let rootLayerData = await MainActor.run { () -> [LayerData] in
            let windows: [UIWindow]
            if #available(iOS 15.0, *) {
                windows = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
            } else {
                windows = UIApplication.shared.windows
            }
            return windows.compactMap { collectLayerData(from: $0.layer, depth: 0) }
        }

        // Build items from collected data (no MainActor needed)
        return rootLayerData.compactMap { buildItem(from: $0, includeScreenshots: includeScreenshots, uploader: uploader) }
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
        let vcClassChain: [String]?
        let children: [LayerData]
    }

    @MainActor
    private static func collectLayerData(from layer: CALayer, depth: Int, maxDepth: Int = 10) -> LayerData? {
        guard depth < maxDepth else { return nil }
        guard let view = layer.tk_hostView else { return nil }

        let rawChildren = layer.sublayers ?? []
        let limitedChildren = rawChildren.prefix(100)
        let children = limitedChildren.compactMap {
            collectLayerData(from: $0, depth: depth + 1, maxDepth: maxDepth)
        }

        let vcChain: [String]? = view.tk_hostViewController.map { vc in
            var chain: [String] = []
            var cls: AnyClass = type(of: vc)
            while true {
                chain.append(NSStringFromClass(cls))
                guard let sup = cls.superclass() else { break }
                cls = sup
            }
            return chain
        }

        return LayerData(
            view: view,
            layer: layer,
            isHidden: layer.isHidden,
            alpha: Float(layer.opacity),
            frame: view.superview?.convert(layer.frame, to: nil) ?? layer.frame,
            bounds: layer.bounds,
            isKeyWindow: (view as? UIWindow)?.isKeyWindow ?? false,
            bgCGColor: layer.backgroundColor,
            classChain: view.tk_classChain,
            vcClassChain: vcChain,
            children: children
        )
    }

    // MARK: - Item Building (no MainActor needed)

    private static func buildItem(
        from data: LayerData,
        includeScreenshots: Bool,
        uploader: TritonKitDataUploader?,
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
        if let vc = data.view?.tk_hostViewController, let vcChain = data.vcClassChain {
            let oid = registry.register(vc)
            vcObj = TKObject(oid: oid, memoryAddress: "\(Unmanaged.passUnretained(vc).toOpaque())", classChainList: vcChain)
        }

        let bgColor = data.bgCGColor.flatMap { TKColor(uiColor: UIColor(cgColor: $0)) }

        let subitems = data.children.map { child in
            buildItem(from: child, includeScreenshots: includeScreenshots, uploader: uploader, indent: indent + 1)
        }

        return TKDisplayItem(
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
            shouldCaptureImage: false,
            indentLevel: indent
        )
    }
}

extension CALayer {
    var classChain: [String] {
        var chain: [String] = []
        var cls: AnyClass = type(of: self)
        while true {
            chain.append(NSStringFromClass(cls))
            guard let superCls = cls.superclass() else { break }
            cls = superCls
        }
        return chain
    }
}

extension UIViewController {
    var classChain: [String] {
        var chain: [String] = []
        var cls: AnyClass = type(of: self)
        while true {
            chain.append(NSStringFromClass(cls))
            guard let superCls = cls.superclass() else { break }
            cls = superCls
        }
        return chain
    }
}
