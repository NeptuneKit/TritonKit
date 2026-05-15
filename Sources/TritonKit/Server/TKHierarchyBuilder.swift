import UIKit

public enum TKHierarchyBuilder {

    public static func buildHierarchy(includeScreenshots: Bool = false) -> [TKDisplayItem] {
        UIApplication.shared.windows.compactMap { window in
            buildItem(for: window.layer, includeScreenshots: includeScreenshots)
        }
    }

    public static func buildItem(for layer: CALayer, includeScreenshots: Bool = false, indent: Int = 0) -> TKDisplayItem? {
        guard let view = layer.tk_hostView else { return nil }

        let registry = TKObjectRegistry.shared
        let viewOid = registry.register(view)
        let layerOid = registry.register(layer)

        let viewObj = TKObject(
            oid: viewOid,
            memoryAddress: view.tk_memoryAddress,
            classChainList: view.tk_classChain
        )
        let layerObj = TKObject(
            oid: layerOid,
            memoryAddress: String(format: "%p", unsafeBitCast(layer, to: Int.self)),
            classChainList: layer.classChain
        )

        let vcObj: TKObject? = {
            guard let vc = view.tk_hostViewController else { return nil }
            let oid = registry.register(vc)
            return TKObject(oid: oid, memoryAddress: String(format: "%p", unsafeBitCast(vc, to: Int.self)), classChainList: vc.classChain)
        }()

        let frameInWindow: CGRect = {
            if let superview = view.superview {
                return superview.convert(layer.frame, to: nil)
            }
            return layer.frame
        }()

        let bgColor: TKColor? = TKColor(uiColor: layer.backgroundColor.flatMap { UIColor(cgColor: $0) })

        let subitems: [TKDisplayItem] = layer.sublayers?.enumerated().compactMap { idx, sublayer in
            buildItem(for: sublayer, includeScreenshots: includeScreenshots, indent: indent + 1)
        } ?? []

        return TKDisplayItem(
            subitems: subitems,
            isHidden: layer.isHidden,
            alpha: Float(layer.opacity),
            frame: frameInWindow,
            bounds: layer.bounds,
            viewObject: viewObj,
            layerObject: layerObj,
            hostViewControllerObject: vcObj,
            representedAsKeyWindow: (view as? UIWindow)?.isKeyWindow ?? false,
            backgroundColor: bgColor,
            shouldCaptureImage: includeScreenshots,
            customDisplayTitle: nil,
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
