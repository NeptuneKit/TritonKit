import UIKit

extension CALayer {
    var tk_hostView: UIView? {
        guard let delegate = delegate as? UIView else { return nil }
        return delegate
    }

    /// Walk up the layer tree to find the topmost host view (considering superview hierarchy)
    var tk_topmostHostView: UIView? {
        var current: CALayer? = self
        while let layer = current {
            if let view = layer.tk_hostView { return view }
            current = layer.superlayer
        }
        return nil
    }
}
