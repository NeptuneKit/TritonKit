import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

/// Only SDK-owned inspector windows opt out of business observation and actions.
/// Unknown high-level windows still participate in foreground safety checks.
protocol TKRuntimeInspectorOverlayWindow: AnyObject {}

#if canImport(UIKit)
import UIKit

/// Single selection authority. Validation and action dispatch share one synchronous
/// MainActor turn; no caller can replace the selection between the two operations.
@MainActor
final class TKPickerSessionManager {
    let runtimeInstanceID: String
    private(set) weak var selectedView: UIView?
    private weak var selectedWindow: UIWindow?
    private weak var rawHitView: UIView?
    private var revision: UInt64 = 0
    private var stored: Selection?
    private var navigationMemory: [ChildMemory] = []

    private struct ChildMemory {
        weak var parent: UIView?
        weak var child: UIView?
        let identity: [Identity]
    }
    private let ttlSeconds: TimeInterval
    private let now: () -> Date

    private struct Identity: Equatable {
        let oid: UInt
        let identifier: String?
        let label: String?
        let title: String?
    }

    private struct Selection {
        let id: String
        let selectedAt: Double
        let expiresAt: Double
        let sceneID: String
        let windowID: UInt
        let rawHitOID: UInt
        let identity: [Identity]
        let resolutionReason: String
        var node: TKAXNode
        var staleReason: String?
    }

    init(ttlSeconds: Int = 300, runtimeInstanceID: String = UUID().uuidString, now: @escaping () -> Date = Date.init) {
        self.ttlSeconds = TimeInterval(max(1, min(300, ttlSeconds)))
        self.runtimeInstanceID = runtimeInstanceID
        self.now = now
    }

    @discardableResult
    func select(_ view: UIView, rawHit: UIView? = nil) -> TKSelectionResponse {
        navigationMemory.removeAll()
        return commit(view, rawHit: rawHit ?? view, resolutionReason: "exact-view")
    }

    enum NavigationDirection { case parent, child, previousSibling, nextSibling }

    func canNavigate(_ direction: NavigationDirection) -> Bool {
        navigationTarget(direction) != nil
    }

    @discardableResult
    func navigate(_ direction: NavigationDirection) -> TKSelectionResponse {
        guard let target = navigationTarget(direction), let view = selectedView else {
            return rejected("selection_unsupported", "No selectable node in this direction")
        }
        let reason: String
        switch direction {
        case .parent: reason = "explicit-parent"
        case .child: reason = "explicit-child"
        case .previousSibling: reason = "explicit-previous-sibling"
        case .nextSibling: reason = "explicit-next-sibling"
        }
        // A previous hit may have left the hierarchy while its parent remained
        // selected. Preserve its provenance only while it belongs to this window.
        let rawHit = rawHitView.flatMap { $0.window === view.window ? $0 : nil } ?? view
        let result = commit(target, rawHit: rawHit, resolutionReason: reason)
        if result.ok, direction == .parent, let identity = Self.identityChain(for: view) {
            navigationMemory.removeAll { $0.parent == nil || $0.child == nil || $0.parent === target }
            navigationMemory.append(ChildMemory(parent: target, child: view, identity: identity))
            if navigationMemory.count > 128 { navigationMemory.removeFirst() }
        }
        return result
    }

    @discardableResult
    func selectParent() -> TKSelectionResponse { navigate(.parent) }

    private func navigationTarget(_ direction: NavigationDirection) -> UIView? {
        guard status().state != "stale", let view = selectedView, let window = view.window else { return nil }
        let candidates: [UIView]
        switch direction {
        case .parent: candidates = view.superview.map { [$0] } ?? []
        case .child:
            if let memory = navigationMemory.last(where: { $0.parent === view }),
               let child = memory.child, child.superview === view, child.window === window,
               Self.identityChain(for: child) == memory.identity,
               Self.visibilityFailure(for: child, in: window) == nil {
                return child
            }
            candidates = view.subviews
        case .previousSibling, .nextSibling:
            guard let siblings = view.superview?.subviews,
                  let index = siblings.firstIndex(where: { $0 === view }) else { return nil }
            candidates = direction == .previousSibling
                ? Array(siblings[..<index].reversed()) : Array(siblings.dropFirst(index + 1))
        }
        return candidates.prefix(512).first {
            !($0 is UIWindow) && $0.window === window && Self.visibilityFailure(for: $0, in: window) == nil
        }
    }

    @discardableResult
    func clear() -> TKSelectionResponse {
        navigationMemory.removeAll()
        revision &+= 1
        stored = nil
        selectedView = nil
        selectedWindow = nil
        rawHitView = nil
        return status()
    }

    func shutdown() { _ = clear() }

    func status() -> TKSelectionResponse {
        guard var selection = stored else {
            return TKSelectionResponse(runtimeInstanceID: runtimeInstanceID, revision: revision)
        }
        if selection.staleReason == nil {
            selection.staleReason = staleReason(for: selection)
        }
        var actions: [String] = []
        var observationReason: String?
        if selection.staleReason == nil, let view = selectedView, let window = selectedWindow {
            selection.node = Self.node(for: view, in: window)
            observationReason = Self.observationOnlyReason(for: view)
            if observationReason == nil { actions = ["tap"] }
        }
        stored = selection
        let state = selection.staleReason != nil ? "stale" : actions.isEmpty ? "observeOnly" : "valid"
        let snapshot = TKSelectionSnapshot(
            id: selection.id, revision: revision,
            selectedAt: selection.selectedAt, expiresAt: selection.expiresAt,
            sceneID: selection.sceneID, windowID: selection.windowID, rawHitOID: selection.rawHitOID,
            target: selection.node, validity: state,
            invalidReason: selection.staleReason ?? observationReason,
            supportedActions: actions, resolutionReason: selection.resolutionReason
        )
        return TKSelectionResponse(runtimeInstanceID: runtimeInstanceID, revision: revision, state: state, selection: snapshot)
    }

    func performGuardedTap(_ guardValue: TKSelectionGuard) -> TKInputResult {
        do { try guardValue.validate() }
        catch { return actionFailure("validation_failed", "Selection runtime, id and a positive revision are required") }
        guard guardValue.runtimeInstanceID == runtimeInstanceID else {
            return actionFailure("selection_stale", "Selection belongs to another runtime instance")
        }
        guard let stored else { return actionFailure("selection_missing", "No current selection") }
        guard guardValue.selectionID == stored.id, guardValue.revision == revision else {
            return actionFailure("selection_revision_mismatch", "Selection changed; read and select the target again")
        }
        let current = status()
        guard current.state != "stale" else {
            return actionFailure("selection_stale", current.selection?.invalidReason ?? "Selection is stale")
        }
        guard current.selection?.supportedActions.contains("tap") == true, let view = selectedView else {
            return actionFailure("selection_identity_unverifiable", current.selection?.invalidReason ?? "Selection is observation only")
        }
        // Only exact UIButton targets pass admission. No coordinate fallback,
        // ancestor activation, responder focus, alert or cell selection is allowed.
        return performTap(.tap(targetOID: oid(for: view)))
    }

    private func commit(_ view: UIView, rawHit: UIView, resolutionReason: String) -> TKSelectionResponse {
        guard !(view is UIWindow), let window = view.window,
              !(window is TKRuntimeInspectorOverlayWindow),
              rawHit.window === window,
              let identity = Self.identityChain(for: view),
              Self.visibilityFailure(for: view, in: window) == nil else {
            return rejected("selection_stale", "Target is not a visible foreground business view")
        }
        revision &+= 1
        selectedView = view
        selectedWindow = window
        rawHitView = rawHit
        let timestamp = now().timeIntervalSince1970
        stored = Selection(
            id: UUID().uuidString, selectedAt: timestamp, expiresAt: timestamp + ttlSeconds,
            sceneID: Self.sceneID(window), windowID: TKObjectRegistry.shared.register(window), rawHitOID: TKObjectRegistry.shared.register(rawHit),
            identity: identity, resolutionReason: resolutionReason, node: Self.node(for: view, in: window)
        )
        return status()
    }

    private func staleReason(for selection: Selection) -> String? {
        guard now().timeIntervalSince1970 < selection.expiresAt else { return "expired" }
        guard let view = selectedView, let window = selectedWindow else { return "target_released" }
        guard view.window === window else { return "target_detached_or_window_changed" }
        guard Self.sceneID(window) == selection.sceneID else { return "scene_changed" }
        guard Self.identityChain(for: view) == selection.identity else { return "target_identity_changed" }
        return Self.visibilityFailure(for: view, in: window)
    }

    private func rejected(_ code: String, _ message: String) -> TKSelectionResponse {
        let current = status()
        return TKSelectionResponse(ok: false, runtimeInstanceID: runtimeInstanceID, revision: revision,
            state: current.state, selection: current.selection, error: TKSelectionError(code: code, message: message))
    }

    private func actionFailure(_ code: String, _ message: String) -> TKInputResult {
        .failure(action: "tap", message: message, error: TKCLIErrorDetail(code: code, message: message), outcome: "not_started")
    }

    private static func sceneID(_ window: UIWindow) -> String {
        window.windowScene?.session.persistentIdentifier ?? "scene-less"
    }

    private static func identityChain(for view: UIView) -> [Identity]? {
        var result: [Identity] = []
        var current: UIView? = view
        while let node = current {
            guard result.count < 128 else { return nil }
            result.append(Identity(oid: TKObjectRegistry.shared.register(node), identifier: node.accessibilityIdentifier,
                label: label(for: node), title: title(for: node)))
            if node is UIWindow { return result }
            current = node.superview
        }
        return nil
    }

    private static func observationOnlyReason(for view: UIView) -> String? {
        var current: UIView? = view
        while let node = current {
            if node is UITableViewCell || node is UICollectionViewCell { return "reusable_cell_identity_unverifiable" }
            if !node.isUserInteractionEnabled { return "interaction_disabled" }
            current = node.superview
        }
        guard let button = view as? UIButton else { return "exact_target_has_no_supported_action" }
        guard button.isEnabled else { return "control_disabled" }
        guard nearestAlertController(from: view) == nil, nearestTextInputResponder(from: view) == nil else {
            return "implicit_ancestor_action_forbidden"
        }
        guard preferredTapDispatch(for: button) != nil else { return "button_has_no_tap_action" }
        return nil
    }

    private static func node(for view: UIView, in window: UIWindow) -> TKAXNode {
        // Text entry values are never copied into selection DTOs. Secure fields
        // (including their private descendant labels) also suppress text labels.
        let textField = nearestSuperview(of: view, matching: UITextField.self)
        let textView = nearestSuperview(of: view, matching: UITextView.self)
        let safeLabel: String?
        if let textField { safeLabel = textField.isSecureTextEntry ? "Secure text field" : textField.placeholder }
        else if textView != nil { safeLabel = "Text view" }
        else { safeLabel = label(for: view) }
        func bounded(_ text: String?) -> String? { text.map { String($0.prefix(256)) } }
        return TKAXNode(role: role(for: view), label: bounded(safeLabel), value: nil,
            identifier: bounded(view.accessibilityIdentifier), title: textField == nil && textView == nil ? bounded(title(for: view)) : nil,
            frame: tkRect(view.convert(view.bounds, to: window)), enabled: enabled(for: view), focused: view.isFirstResponder,
            hidden: view.isHidden || view.alpha <= 0.01, targetOID: oid(for: view),
            className: NSStringFromClass(type(of: view)), children: [])
    }

    private static func visibilityFailure(for view: UIView, in window: UIWindow) -> String? {
        if let failure = runtimeForegroundTargetFailure(for: view) { return failure }
        var visibleRect = view.convert(view.bounds, to: window).intersection(window.bounds)
        var current = view.superview
        while let ancestor = current {
            if ancestor.clipsToBounds { visibleRect = visibleRect.intersection(ancestor.convert(ancestor.bounds, to: window)) }
            current = ancestor.superview
        }
        guard !visibleRect.isNull, !visibleRect.isEmpty,
              visibleRect.origin.x.isFinite, visibleRect.origin.y.isFinite,
              visibleRect.width.isFinite, visibleRect.height.isFinite else { return "target_outside_visible_bounds" }
        let center = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        guard let hit = candidate(at: center, in: window), hit === view || hit.isDescendant(of: view) else {
            return "target_obscured"
        }
        return nil
    }

    /// Window-local logical points; unlike UIKit hitTest, text and noninteractive
    /// views remain candidates. A finite traversal budget fails closed.
    static func candidate(at point: CGPoint, in window: UIWindow) -> UIView? {
        guard !(window is TKRuntimeInspectorOverlayWindow), !window.isHidden, window.alpha > 0.01,
              point.x.isFinite, point.y.isFinite, window.bounds.contains(point) else { return nil }
        var remaining = 4_000
        var exhausted = false
        func visit(_ view: UIView, point: CGPoint, depth: Int) -> UIView? {
            guard remaining > 0, depth < 128 else { exhausted = true; return nil }
            remaining -= 1
            guard !view.isHidden, view.alpha > 0.01, !view.layer.isHidden, view.layer.opacity > 0.01,
                  point.x.isFinite, point.y.isFinite else { return nil }
            let inside = view.bounds.contains(point)
            guard inside || !view.clipsToBounds else { return nil }
            let children = view.subviews.enumerated().sorted {
                if $0.element.layer.zPosition != $1.element.layer.zPosition { return $0.element.layer.zPosition > $1.element.layer.zPosition }
                return $0.offset > $1.offset
            }
            for child in children {
                if let hit = visit(child.element, point: child.element.convert(point, from: view), depth: depth + 1) { return hit }
                if exhausted { return nil }
            }
            let isBlankRoot = view === window.rootViewController?.viewIfLoaded
                && view.accessibilityIdentifier == nil && label(for: view) == nil
            return inside && !(view is UIWindow) && !isBlankRoot ? view : nil
        }
        let result = visit(window, point: point, depth: 0)
        return exhausted ? nil : result
    }
}
#endif
