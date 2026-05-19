#if canImport(UIKit)
import UIKit

extension CALayer {
    var tk_hostView: UIView? {
        guard let delegate = delegate as? UIView else { return nil }
        return delegate
    }
}
#endif
