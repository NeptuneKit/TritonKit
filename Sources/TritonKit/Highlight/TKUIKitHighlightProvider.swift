#if canImport(UIKit)
import UIKit
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

/// Optional in-process provider. It never creates a view, loads a controller, or edits AX identity.
@MainActor
final class TKUIKitHighlightProvider {
    struct Border {
        let color: CGColor?
        let width: CGFloat
        init(_ layer: CALayer) { color = layer.borderColor; width = layer.borderWidth }
        init(color: CGColor?, width: CGFloat) { self.color = color; self.width = width }
        func matches(_ layer: CALayer) -> Bool { Self.same(color, layer.borderColor) && width == layer.borderWidth }
        static func same(_ a: CGColor?, _ b: CGColor?) -> Bool {
            switch (a, b) { case (nil, nil): return true; case let (a?, b?): return a == b; default: return false }
        }
    }
    @MainActor private final class WeakAncestor {
        weak var view: UIView?
        let identity: ObjectIdentifier
        init(_ view: UIView) { self.view = view; identity = ObjectIdentifier(view) }
    }
    @MainActor final class Target {
        weak var layer: CALayer?
        weak var view: UIView?
        weak var window: UIWindow?
        weak var originalSuperlayer: CALayer?
        let superlayerIdentity: ObjectIdentifier?
        weak var scene: UIWindowScene?
        let sceneIdentity: ObjectIdentifier?
        private let ancestors: [WeakAncestor]
        let token: String
        let oid: UInt
        init(layer: CALayer, view: UIView, window: UIWindow) {
            self.layer = layer; self.view = view; self.window = window; originalSuperlayer = layer.superlayer; superlayerIdentity = layer.superlayer.map(ObjectIdentifier.init); scene = window.windowScene; sceneIdentity = window.windowScene.map(ObjectIdentifier.init)
            var chain: [WeakAncestor] = []
            var ancestor: UIView? = view
            while let current = ancestor {
                chain.append(WeakAncestor(current))
                if current === window { break }
                ancestor = current.superview
            }
            ancestors = chain
            oid = TKObjectRegistry.shared.register(layer)
            token = "layer-\(oid)"
        }
        var identityValid: Bool {
            guard let layer, let view, let window else { return false }
            var current: UIView? = view
            for ancestor in ancestors {
                guard let value = current, value === ancestor.view, ObjectIdentifier(value) == ancestor.identity else { return false }
                current = value.superview
            }
            guard ancestors.last?.view === window, current == nil else { return false }
            return layer.superlayer === originalSuperlayer && layer.superlayer.map(ObjectIdentifier.init) == superlayerIdentity && view.window === window && window.windowScene === scene && window.windowScene.map(ObjectIdentifier.init) == sceneIdentity && TKUIKitHighlightProvider.anchor(for: layer) === view
        }
    }
    private let roots: @MainActor () -> [UIView]
    init(roots: (@MainActor () -> [UIView])? = nil) {
        self.roots = roots ?? { UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows } }
    }

    func resolve(_ selector: TKHighlightSelector) throws -> Target {
        guard selector.text == nil, selector.role == nil else { throw failure("highlight_unsupported", "This provider supports OID and scoped identifier selectors; text/role require a semantic provider.") }
        let object: AnyObject
        if let oid = selector.oid {
            guard let existing = TKObjectRegistry.shared.object(for: oid) else { throw failure("highlight_target_not_found", "The OID no longer resolves to a live object.") }
            object = existing
        } else {
            var candidates: [UIView] = []
            var seen: Set<ObjectIdentifier> = []
            let searchRoots: [UIView]
            if let within = selector.withinOID {
                guard let root = TKObjectRegistry.shared.object(for: within) as? UIView else { throw failure("highlight_target_not_found", "The ancestor OID does not resolve to a UIView.") }
                searchRoots = [root]
            } else { searchRoots = roots() }
            func walk(_ view: UIView) {
                guard seen.insert(ObjectIdentifier(view)).inserted else { return }
                if let identifier = selector.identifier, view.accessibilityIdentifier == identifier { candidates.append(view) }
                view.subviews.forEach(walk)
            }
            searchRoots.forEach(walk)
            guard candidates.count <= 1 else { throw failure("highlight_target_ambiguous", "The identifier matches multiple live views; use an OID or ancestor scope.") }
            guard let view = candidates.first else { throw failure("highlight_target_not_found", "No live view matches the identifier.") }
            object = view
        }
        let layer: CALayer
        if let view = object as? UIView { layer = view.layer }
        else if let existing = object as? CALayer { layer = existing }
        else { throw failure("highlight_unsupported", "Only existing UIView and CALayer targets are supported; controllers are never loaded.") }
        guard let view = Self.anchor(for: layer), let window = view.window else { throw failure("highlight_identity_unverifiable", "The layer has no live UIView/window context.") }
        if let within = selector.withinOID {
            guard let ancestor = TKObjectRegistry.shared.object(for: within) as? UIView, view === ancestor || view.isDescendant(of: ancestor) else { throw failure("highlight_target_not_found", "The target is outside the requested ancestor.") }
        }
        var ancestor: UIView? = view
        while let current = ancestor {
            if current is UITableViewCell || current is UICollectionViewCell { throw failure("highlight_identity_unverifiable", "Reusable cell subtrees require a verified content epoch provider.") }
            guard !current.isHidden, current.alpha > 0 else { throw failure("highlight_unsupported", "The target is hidden or transparent.") }
            ancestor = current.superview
        }
        var visibleLayer: CALayer? = layer
        while let current = visibleLayer {
            guard !current.isHidden, current.opacity > 0 else { throw failure("highlight_unsupported", "The target has a hidden or transparent layer ancestor.") }
            visibleLayer = current.superlayer
        }
        guard !layer.isHidden, layer.opacity > 0, layer.bounds.width > 0, layer.bounds.height > 0 else { throw failure("highlight_unsupported", "The target layer has no visible area.") }
        guard !(layer.animationKeys() ?? []).contains(where: { key in Self.borderAnimation(layer.animation(forKey: key)) }) else { throw failure("highlight_unsupported", "An active border animation makes snapshot restoration unverifiable.") }
        return Target(layer: layer, view: view, window: window)
    }
    static func anchor(for layer: CALayer) -> UIView? {
        var current: CALayer? = layer
        while let node = current {
            if let view = node.delegate as? UIView, view.layer === node { return view }
            current = node.superlayer
        }
        return nil
    }
    static func borderAnimation(_ animation: CAAnimation?) -> Bool {
        if let property = animation as? CAPropertyAnimation, let key = property.keyPath, key.hasPrefix("border") { return true }
        if let group = animation as? CAAnimationGroup { return (group.animations ?? []).contains { borderAnimation($0) } }
        return false
    }
    func color(_ value: String) throws -> CGColor {
        let hex = String(value.dropFirst())
        guard value.first == "#", hex.count == 6 || hex.count == 8, let raw = UInt64(hex, radix: 16) else { throw failure("validation_failed", "Outline color must be #RRGGBB or #RRGGBBAA.") }
        let rgb = hex.count == 8 ? raw >> 8 : raw
        let alpha = hex.count == 8 ? CGFloat(raw & 255) / 255 : 1
        return UIColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: alpha).cgColor
    }
    func failure(_ code: String, _ message: String) -> TKHighlightError { TKHighlightError(code: code, message: message) }
}
#endif
