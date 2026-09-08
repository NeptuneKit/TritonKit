import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

/// A public control callback or content-offset mutation cannot create UIKit
/// touch sequences. Keep the same typed contract on every unsupported target.
func unsupportedEmbeddedGesture(
    _ request: TKInputRequest,
    strategy: String,
    matchedOID: UInt? = nil,
    matchedClassName: String? = nil,
    activationOID: UInt? = nil,
    activationClassName: String? = nil
) -> TKInputResult {
    let message = request.type == .longPress
        ? "Embedded UIKit cannot inject a long-press touch sequence into gesture recognizers"
        : "Embedded UIKit swipe supports public UIScrollView/UISlider updates only; this target requires gesture touch injection"
    return TKInputResult.unsupported(
        action: request.type.rawValue,
        message: message,
        strategy: strategy,
        matchedOID: matchedOID,
        matchedClassName: matchedClassName,
        activationOID: activationOID,
        activationClassName: activationClassName,
        error: TKCLIErrorDetail(
            code: "unsupported_capability",
            message: message,
            hint: "Discover app-owned semantic actions with snapshot, then use an app-provided DEBUG integration if available. A host gesture provider must explicitly support the requested duration and movement; the current Simulator tap path cannot substitute for a hold, and tap --duration is not a long press. The suggested commands inspect capabilities only and do not submit a gesture.",
            nextAction: TKCLINextAction(command: "snapshot", args: ["--include", "semantic", "--json"]),
            suggestedCommands: [
                "triton snapshot --include semantic --json",
                "triton schema --command sim --json",
                "triton schema --command act --json",
            ]
        )
    )
}

#if canImport(UIKit)
import UIKit

@MainActor
func performLongPress(_ request: TKInputRequest) async -> TKInputResult {
    let resolved = resolveView(targetOID: request.targetOID, x: request.x, y: request.y)
    guard let view = resolved.view else {
        return TKInputResult.failure(action: request.type.rawValue, message: resolved.message)
    }
    let matched = tapMatchedContext(request, fallback: view)
    let candidate = nearestLongPressGestureCandidate(from: view)
    let activationView = candidate?.view ?? nearestSuperview(of: view, matching: UIControl.self) ?? view
    // sendActions(.touchDown/.touchUpInside) bypasses gesture recognition and
    // must never be reported as a successful long press, even on a UIControl.
    return unsupportedEmbeddedGesture(
        request,
        strategy: candidate == nil ? "embedded-long-press-unsupported" : "long-press-gesture-recognizer",
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: oid(for: activationView),
        activationClassName: NSStringFromClass(type(of: activationView))
    )
}

func nearestLongPressGestureCandidate(from view: UIView) -> (view: UIView, gesture: UILongPressGestureRecognizer)? {
    var current: UIView? = view
    while let view = current {
        if view.isUserInteractionEnabled,
           let gesture = view.gestureRecognizers?.compactMap({ $0 as? UILongPressGestureRecognizer }).first(where: { $0.isEnabled }) {
            return (view, gesture)
        }
        current = view.superview
    }
    return nil
}

func nearestTapGestureCandidate(
    from view: UIView,
    stoppingAt boundary: UIView? = nil
) -> (view: UIView, gesture: UITapGestureRecognizer)? {
    if let boundary,
       view !== boundary,
       !view.isDescendant(of: boundary) {
        return nil
    }

    var current: UIView? = view
    while let view = current {
        if view.isUserInteractionEnabled,
           let gesture = view.gestureRecognizers?.compactMap({ $0 as? UITapGestureRecognizer }).first(where: { gesture in
               gesture.isEnabled && gesture.numberOfTapsRequired <= 1 && gesture.numberOfTouchesRequired <= 1
           }) {
            return (view, gesture)
        }
        if let boundary, view === boundary {
            break
        }
        current = view.superview
    }
    return nil
}

@MainActor
func performSwipe(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    guard let startX = request.startX,
          let startY = request.startY,
          let endX = request.endX,
          let endY = request.endY else {
        return TKInputResult.failure(action: action, message: "Missing swipe coordinates")
    }

    let deltaX = endX - startX
    let deltaY = endY - startY
    let resolved = resolveView(targetOID: nil, x: startX, y: startY)
    guard let view = resolved.view else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }
    if let slider = nearestSuperview(of: view, matching: UISlider.self) {
        return performSliderDrag(slider, endX: endX, endY: endY, action: action)
    }
    let scrollTarget = swipeScrollTarget(from: view, deltaX: deltaX, deltaY: deltaY)
    guard let scrollView = scrollTarget.view else {
        return unsupportedEmbeddedGesture(
            request,
            strategy: "embedded-swipe-gesture-unsupported",
            matchedOID: oid(for: view),
            matchedClassName: NSStringFromClass(type(of: view)),
            activationOID: oid(for: view),
            activationClassName: NSStringFromClass(type(of: view))
        )
    }

    let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right)
    let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
    let minX = -scrollView.adjustedContentInset.left
    let minY = -scrollView.adjustedContentInset.top
    let newOffset = CGPoint(
        x: min(max(scrollView.contentOffset.x - deltaX, minX), maxX),
        y: min(max(scrollView.contentOffset.y - deltaY, minY), maxY)
    )
    scrollView.setContentOffset(newOffset, animated: false)

    return TKInputResult.success(
        action: action,
        message: String(format: "Set contentOffset to %.1f,%.1f", newOffset.x, newOffset.y),
        targetOID: oid(for: scrollView),
        targetClassName: NSStringFromClass(type(of: scrollView)),
        strategy: scrollTarget.strategy
    )
}

@MainActor
func performSliderDrag(_ slider: UISlider, endX: Double, endY: Double, action: String) -> TKInputResult {
    let point = slider.convert(CGPoint(x: endX, y: endY), from: nil)
    let ratio = Float(min(max(point.x / max(slider.bounds.width, 1), 0), 1))
    let nextValue = slider.minimumValue + ratio * (slider.maximumValue - slider.minimumValue)
    slider.setValue(nextValue, animated: false)
    slider.sendActions(for: .valueChanged)
    return TKInputResult.success(
        action: action,
        message: String(format: "Dragged UISlider value to %.2f", nextValue),
        targetOID: oid(for: slider),
        targetClassName: NSStringFromClass(type(of: slider)),
        strategy: "slider-drag"
    )
}

@MainActor
func performPinch(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    guard let scale = pinchScale(from: request) else {
        return TKInputResult.failure(action: action, message: "Missing or invalid pinch scale")
    }

    let resolved = resolveView(targetOID: request.targetOID, x: request.centerX, y: request.centerY)
    guard let view = resolved.view else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }
    guard let scrollView = nearestZoomableScrollView(from: view) else {
        let activationOID = oid(for: view)
        let activationClassName = NSStringFromClass(type(of: view))
        return TKInputResult.unsupported(
            action: action,
            message: "Hit view is not inside a zoomable UIScrollView",
            strategy: "zoomable-scroll-view-required",
            matchedOID: activationOID,
            matchedClassName: activationClassName,
            activationOID: activationOID,
            activationClassName: activationClassName
        )
    }

    let currentZoomScale = scrollView.zoomScale
    let nextZoomScale = min(
        max(currentZoomScale * CGFloat(scale), scrollView.minimumZoomScale),
        scrollView.maximumZoomScale
    )
    scrollView.setZoomScale(nextZoomScale, animated: false)

    return TKInputResult.success(
        action: action,
        message: String(format: "Set zoomScale to %.2f", nextZoomScale),
        targetOID: oid(for: scrollView),
        targetClassName: NSStringFromClass(type(of: scrollView)),
        matchedOID: oid(for: view),
        matchedClassName: NSStringFromClass(type(of: view)),
        activationOID: oid(for: scrollView),
        activationClassName: NSStringFromClass(type(of: scrollView)),
        strategy: "scroll-view-pinch-zoom"
    )
}

func pinchScale(from request: TKInputRequest) -> Double? {
    if let scale = request.scale, scale > 0, scale.isFinite {
        return scale
    }
    guard let startDistance = request.startDistance,
          let endDistance = request.endDistance,
          startDistance > 0,
          endDistance > 0,
          startDistance.isFinite,
          endDistance.isFinite else {
        return nil
    }
    return endDistance / startDistance
}

func nearestZoomableScrollView(from view: UIView) -> UIScrollView? {
    var current: UIView? = view
    while let candidate = current {
        if let scrollView = candidate as? UIScrollView,
           scrollView.maximumZoomScale > scrollView.minimumZoomScale,
           !scrollView.isHidden,
           scrollView.alpha > 0.01,
           scrollView.isUserInteractionEnabled {
            return scrollView
        }
        current = candidate.superview
    }
    return nil
}

func swipeScrollTarget(from view: UIView, deltaX: Double, deltaY: Double) -> (view: UIScrollView?, strategy: String?) {
    let axis = abs(deltaX) >= abs(deltaY) ? SwipeAxis.horizontal : .vertical
    var nearestScrollView: UIScrollView?
    var current: UIView? = view
    while let candidate = current {
        if let scrollView = candidate as? UIScrollView {
            nearestScrollView = nearestScrollView ?? scrollView
            if scrollView.canScroll(along: axis) {
                return (scrollView, "axis-matched-scroll-ancestor")
            }
        }
        current = candidate.superview
    }
    return (nearestScrollView, nearestScrollView == nil ? nil : "nearest-scroll-ancestor")
}

private enum SwipeAxis {
    case horizontal
    case vertical
}

private extension UIScrollView {
    func canScroll(along axis: SwipeAxis) -> Bool {
        switch axis {
        case .horizontal:
            contentSize.width + adjustedContentInset.left + adjustedContentInset.right > bounds.width + 0.5
        case .vertical:
            contentSize.height + adjustedContentInset.top + adjustedContentInset.bottom > bounds.height + 0.5
        }
    }
}

#endif
