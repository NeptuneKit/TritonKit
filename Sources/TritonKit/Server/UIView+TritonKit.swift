import UIKit

extension UIView {
    var tk_hostViewController: UIViewController? {
        guard let responder = next, let vc = responder as? UIViewController, vc.view == self else {
            return nil
        }
        return vc
    }

    var tk_classChain: [String] {
        var chain: [String] = []
        var cls: AnyClass = type(of: self)
        while true {
            chain.append(NSStringFromClass(cls))
            guard let superCls = cls.superclass() else { break }
            cls = superCls
        }
        return chain
    }

    var tk_memoryAddress: String {
        String(format: "%p", unsafeBitCast(self, to: Int.self))
    }
}
