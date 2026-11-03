#if canImport(UIKit)
import UIKit

extension CALayer {
    var tk_hostView: UIView? {
        guard let view = delegate as? UIView, view.layer === self else { return nil }
        return view
    }

    var tk_classChain: [String] {
        var chain: [String] = []
        var cls: AnyClass = type(of: self)
        while true {
            chain.append(NSStringFromClass(cls))
            guard let superClass = cls.superclass() else { break }
            cls = superClass
        }
        return chain
    }

    @MainActor
    var tk_inspectionFrame: CGRect {
        var root = self
        while let parent = root.superlayer { root = parent }
        let rootRect = convert(bounds, to: root)
        if let window = root.tk_hostView as? UIWindow {
            return window.convert(rootRect, to: nil)
        }
        // Detached objects have no screen space. Keep their root-parent frame
        // instead of inventing a screen origin or adding only the leaf frame.
        return root.convert(rootRect, to: root.superlayer)
    }

    @MainActor
    var tk_inspectionScale: CGFloat {
        var candidate: CALayer? = self
        while let layer = candidate {
            if let window = layer.tk_hostView?.window { return window.screen.scale }
            candidate = layer.superlayer
        }
        return max(1, contentsScale.isFinite ? contentsScale : 1)
    }

    @MainActor
    var tk_isInspectorOverlay: Bool {
        var candidate: CALayer? = self
        while let layer = candidate {
            if layer.tk_hostView is TKRuntimeInspectorOverlayWindow { return true }
            candidate = layer.superlayer
        }
        return false
    }
}
#endif
