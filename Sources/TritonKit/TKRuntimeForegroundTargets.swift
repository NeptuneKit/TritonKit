import Foundation

/// Internal policy facts; no new transport or public schema is introduced.
enum RuntimeForegroundSceneState: Equatable {
    case foregroundActive, foregroundInactive, background, unattached
}

struct RuntimeForegroundWindowFact {
    let index: Int
    let sceneState: RuntimeForegroundSceneState?
    let visible: Bool
    let level: Double
    let key: Bool
    var isKnownInputOverlay: Bool = false
}

/// Read-only identity check for the exact system overlay observed by hosted
/// acceptance. Unknown windows remain conservative action candidates.
func isRuntimeKnownInputOverlay(windowClassName: String, rootClassName: String?, windowDefinedByUIKit: Bool, rootDefinedByUIKit: Bool) -> Bool {
    windowDefinedByUIKit && rootDefinedByUIKit
        && windowClassName == "UITextEffectsWindow"
        && rootClassName == "UITrackingElementWindowController"
}

func orderedRuntimeForegroundWindowIndices(_ facts: [RuntimeForegroundWindowFact], hasSceneEnvironment: Bool) -> [Int] {
    facts.filter {
        !$0.isKnownInputOverlay && $0.visible && $0.level.isFinite && (hasSceneEnvironment ? $0.sceneState == .foregroundActive : $0.sceneState == nil)
    }.sorted {
        if $0.level != $1.level { return $0.level > $1.level }
        if $0.key != $1.key { return $0.key }
        return $0.index < $1.index
    }.map(\.index)
}

#if canImport(UIKit)
import UIKit

@MainActor
func keyWindows() -> [UIWindow] {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    // A scene app never falls back to registry windows when all its scenes are
    // background/inactive. Only a genuinely scene-less host uses this path.
    let candidates = scenes.isEmpty
        ? UIApplication.shared.windows + TKObjectRegistry.shared.objects(of: UIWindow.self)
        : scenes.flatMap(\.windows)
    var seen = Set<ObjectIdentifier>()
    let windows = candidates.filter { seen.insert(ObjectIdentifier($0)).inserted }
    let facts = windows.enumerated().map { index, window in
        RuntimeForegroundWindowFact(
            index: index,
            sceneState: window.windowScene.map { runtimeForegroundSceneState($0.activationState) },
            visible: !window.isHidden && window.alpha > 0.01 && window.isUserInteractionEnabled,
            level: Double(window.windowLevel.rawValue),
            key: window.isKeyWindow,
            isKnownInputOverlay: runtimeKnownInputOverlay(window)
        )
    }
    return orderedRuntimeForegroundWindowIndices(facts, hasSceneEnvironment: !scenes.isEmpty).map { windows[$0] }
}

/// This exact UIKit-owned pair was observed on iOS 27 with Xcode 27. It has
/// a controller and can become key, so those public facts cannot distinguish
/// it. No private class is instantiated or messaged; unfamiliar identities
/// remain eligible and can conservatively block lower business windows.
@MainActor
private func runtimeKnownInputOverlay(_ window: UIWindow) -> Bool {
    guard let root = window.rootViewController else { return false }
    let uiKitBundleURL = Bundle(for: UIWindow.self).bundleURL
    return isRuntimeKnownInputOverlay(
        windowClassName: NSStringFromClass(type(of: window)),
        rootClassName: NSStringFromClass(type(of: root)),
        windowDefinedByUIKit: Bundle(for: type(of: window)).bundleURL == uiKitBundleURL,
        rootDefinedByUIKit: Bundle(for: type(of: root)).bundleURL == uiKitBundleURL
    )
}

private func runtimeForegroundSceneState(_ state: UIScene.ActivationState) -> RuntimeForegroundSceneState {
    switch state {
    case .foregroundActive: return .foregroundActive
    case .foregroundInactive: return .foregroundInactive
    case .background: return .background
    case .unattached: return .unattached
    @unknown default: return .unattached
    }
}

@MainActor
private func runtimeForegroundPresentedController(from controller: UIViewController) -> UIViewController? {
    if let presented = controller.presentedViewController {
        return runtimeForegroundPresentedController(from: presented) ?? presented
    }
    if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
        return runtimeForegroundPresentedController(from: visible)
    }
    if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
        return runtimeForegroundPresentedController(from: selected)
    }
    for child in controller.children.reversed() where child.viewIfLoaded?.window != nil {
        if let presented = runtimeForegroundPresentedController(from: child) { return presented }
    }
    return nil
}

/// Restrict actions to the presented surface, while retaining navigation/tab
/// chrome and scene-less UIWindow fixtures when there is no modal.
@MainActor
func runtimeForegroundActionRoot(in window: UIWindow) -> UIView? {
    guard let root = window.rootViewController,
          let presented = runtimeForegroundPresentedController(from: root) else { return window }
    // Do not force-load controllers or unblock the background during a pending
    // presentation/dismissal. Real attachment/relationship completion decides.
    guard let view = presented.viewIfLoaded, view.window === window else { return nil }
    return view
}

@MainActor
func runtimeForegroundTargetFailure(for view: UIView) -> String? {
    guard let window = view.window else {
        return "stale_runtime_hierarchy: target is no longer attached to a window"
    }
    guard let foreground = keyWindows().first, foreground === window else {
        return "stale_runtime_hierarchy: target is not in the frontmost active window"
    }
    guard let root = runtimeForegroundActionRoot(in: window), view === root || view.isDescendant(of: root) else {
        return "stale_runtime_hierarchy: target is behind the current presented surface"
    }
    var ancestor: UIView? = view
    while let current = ancestor {
        if current.isHidden || current.alpha <= 0.01 {
            return "stale_runtime_hierarchy: target is hidden in its current hierarchy"
        }
        if current === window { break }
        ancestor = current.superview
    }
    return nil
}

@MainActor
func resolveView(targetOID: UInt?, x: Double?, y: Double?) -> (view: UIView?, message: String) {
    if let targetOID {
        guard let view = TKObjectRegistry.shared.object(for: targetOID) as? UIView else {
            return (nil, "Target oid is not a UIView: \(targetOID)")
        }
        if let reason = runtimeForegroundTargetFailure(for: view) { return (nil, reason) }
        return (view, "Resolved target oid")
    }
    guard let x, let y else { return (nil, "Missing x/y or target oid") }
    guard let window = keyWindows().first else { return (nil, "No key window") }
    let point = CGPoint(x: x, y: y)
    guard window.bounds.contains(point) else { return (nil, "Point is outside key window bounds") }
    guard let view = window.hitTest(point, with: nil) else { return (nil, "No view hit at point") }
    if let reason = runtimeForegroundTargetFailure(for: view) { return (nil, reason) }
    return (view, "Hit-tested point")
}
#endif
