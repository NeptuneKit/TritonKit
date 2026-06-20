import Foundation
import TritonKitShared
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
@MainActor
func performInput(_ request: TKInputRequest) async -> TKInputResult {
    switch request.type {
    case .tap:
        return performTap(request)
    case .longPress:
        return await performLongPress(request)
    case .swipe:
        return performSwipe(request)
    case .pinch:
        return performPinch(request)
    case .typeText:
        return await performExactTextInsertion(request)
    case .paste:
        return await performExactTextInsertion(request)
    case .clear:
        return performClear(request)
    case .deleteBackward:
        return await performDeleteBackward(request)
    case .button:
        return TKInputResult.unsupported(
            action: request.type.rawValue,
            message: "Host-side HID is not available in the embedded TritonKit runtime"
        )
    }
}

@MainActor
func performLongPress(_ request: TKInputRequest) async -> TKInputResult {
    let action = request.type.rawValue
    let resolved = resolveView(targetOID: request.targetOID, x: request.x, y: request.y)
    guard let view = resolved.view else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }

    if let control = nearestSuperview(of: view, matching: UIControl.self) {
        return await performControlLongPress(control, request: request, action: action, matchedView: view)
    }

    let matched = tapMatchedContext(request, fallback: view)
    let activationOID = oid(for: view)
    let activationClassName = NSStringFromClass(type(of: view))
    if nearestLongPressGestureCandidate(from: view) != nil {
        return TKInputResult.unsupported(
            action: action,
            message: "UILongPressGestureRecognizer target actions are not exposed through public UIKit runtime APIs",
            strategy: "long-press-gesture-recognizer",
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName
        )
    }

    return TKInputResult.failure(
        action: action,
        message: "Hit view does not expose a public UIControl long-press action",
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: "control-long-press-required"
    )
}

@MainActor
func performControlLongPress(
    _ control: UIControl,
    request: TKInputRequest,
    action: String,
    matchedView: UIView?
) async -> TKInputResult {
    let matched = tapMatchedContext(request, fallback: matchedView)
    let activationOID = oid(for: control)
    let activationClassName = NSStringFromClass(type(of: control))
    guard control.isEnabled else {
        return TKInputResult.failure(
            action: action,
            message: "Target UIControl is disabled",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: "control-long-press-touch-events"
        )
    }

    control.sendActions(for: .touchDown)
    try? await Task.sleep(nanoseconds: UInt64(longPressHoldDuration(from: request) * 1_000_000_000))
    control.sendActions(for: .touchUpInside)

    return TKInputResult.success(
        action: action,
        message: "Submitted UIControl long press touch events",
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: "control-long-press-touch-events"
    )
}

func longPressHoldDuration(from request: TKInputRequest) -> Double {
    guard let duration = request.duration, duration.isFinite, duration > 0 else {
        return 0.52
    }
    return min(max(duration, 0.05), 2)
}

@MainActor
func performTap(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    let resolved = resolveView(targetOID: request.targetOID, x: request.x, y: request.y)
    guard let view = resolved.view else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }

    if let textView = nearestSuperview(of: view, matching: UITextView.self) {
        let matched = tapMatchedContext(request, fallback: view)
        let activationOID = oid(for: textView)
        let activationClassName = NSStringFromClass(type(of: textView))
        textView.becomeFirstResponder()
        return TKInputResult.success(
            action: action,
            message: "Focused text view",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: request.activationStrategy?.rawValue
        )
    }

    if let responder = nearestTextInputResponder(from: view) {
        let matched = tapMatchedContext(request, fallback: view)
        let activationOID = oid(for: responder)
        let activationClassName = NSStringFromClass(type(of: responder))
        responder.becomeFirstResponder()
        return TKInputResult.success(
            action: action,
            message: "Focused text input responder",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: request.activationStrategy?.rawValue
        )
    }

    if shouldUseAncestorTapActivation(request),
       let result = performAncestorTapActivation(from: view, request: request, action: action) {
        return result
    }

    guard let control = nearestSuperview(of: view, matching: UIControl.self) else {
        if let tableCell = nearestSuperview(of: view, matching: UITableViewCell.self)
            ?? tableCellContaining(request: request),
           let result = performTableCellTap(tableCell, request: request, action: action, matchedView: view) {
            return result
        }

        if let collectionCell = nearestSuperview(of: view, matching: UICollectionViewCell.self)
            ?? collectionCellContaining(request: request),
           let result = performCollectionCellTap(collectionCell, request: request, action: action, matchedView: view) {
            return result
        }

        if let result = performTapGestureActivation(from: view, request: request, action: action, matchedView: view) {
            return result
        }
        return tapActivationFailure(
            request: request,
            action: action,
            view: view,
            message: "Hit view does not expose a public UIControl or UITapGestureRecognizer tap action"
        )
    }

    return performControlTap(
        control,
        request: request,
        action: action,
        matchedView: nil,
        strategy: request.activationStrategy?.rawValue
    )
}

@MainActor
func performControlTap(
    _ control: UIControl,
    request: TKInputRequest,
    action: String,
    matchedView: UIView?,
    strategy: String?
) -> TKInputResult {
    let matched = tapMatchedContext(request, fallback: matchedView)
    let activationOID = oid(for: control)
    let activationClassName = NSStringFromClass(type(of: control))

    guard control.isEnabled else {
        return TKInputResult.failure(
            action: action,
            message: "Target UIControl is disabled",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }

    if let textField = control as? UITextField {
        textField.becomeFirstResponder()
        return TKInputResult.success(
            action: action,
            message: "Focused text field",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }

    if let toggle = control as? UISwitch {
        toggle.setOn(!toggle.isOn, animated: false)
        toggle.sendActions(for: .valueChanged)
        return TKInputResult.success(
            action: action,
            message: "Toggled UISwitch",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }

    if let segmented = control as? UISegmentedControl {
        let nextIndex: Int
        if let x = request.x, let y = request.y {
            let point = segmented.convert(CGPoint(x: x, y: y), from: nil)
            let segmentWidth = segmented.bounds.width / CGFloat(max(segmented.numberOfSegments, 1))
            nextIndex = min(max(Int(point.x / max(segmentWidth, 1)), 0), segmented.numberOfSegments - 1)
        } else {
            nextIndex = (segmented.selectedSegmentIndex + 1) % max(segmented.numberOfSegments, 1)
        }
        segmented.selectedSegmentIndex = nextIndex
        dispatchValueChangedActions(for: segmented)
        return TKInputResult.success(
            action: action,
            message: "Selected UISegmentedControl index \(nextIndex)",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }

    if let slider = control as? UISlider {
        let nextValue: Float
        if let x = request.x {
            let point = slider.convert(CGPoint(x: x, y: request.y ?? Double(slider.bounds.midY)), from: nil)
            let ratio = Float(min(max(point.x / max(slider.bounds.width, 1), 0), 1))
            nextValue = slider.minimumValue + ratio * (slider.maximumValue - slider.minimumValue)
        } else {
            nextValue = min(slider.maximumValue, slider.value + (slider.maximumValue - slider.minimumValue) * 0.1)
        }
        slider.setValue(nextValue, animated: false)
        slider.sendActions(for: .valueChanged)
        return TKInputResult.success(
            action: action,
            message: String(format: "Set UISlider value to %.2f", nextValue),
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }

    if let stepper = control as? UIStepper {
        let shouldDecrement: Bool
        if let x = request.x {
            let point = stepper.convert(CGPoint(x: x, y: request.y ?? Double(stepper.bounds.midY)), from: nil)
            shouldDecrement = point.x < stepper.bounds.midX
        } else {
            shouldDecrement = false
        }
        let delta = shouldDecrement ? -stepper.stepValue : stepper.stepValue
        let nextValue = min(max(stepper.value + delta, stepper.minimumValue), stepper.maximumValue)
        stepper.value = nextValue
        stepper.sendActions(for: .valueChanged)
        return TKInputResult.success(
            action: action,
            message: String(format: "Set UIStepper value to %.0f", nextValue),
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }

    if let result = performTabBarControlTap(control, request: request, action: action, matchedView: matchedView, strategy: strategy) {
        return result
    }

    if control.accessibilityActivate() {
        return TKInputResult.success(
            action: action,
            message: "Activated UIControl via accessibilityActivate",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy ?? "uikit-accessibility-activate"
        )
    }

    guard let dispatch = preferredTapDispatch(for: control) else {
        return TKInputResult.failure(
            action: action,
            message: "Target UIControl has no primary or touchUpInside action and did not activate through public UIKit accessibilityActivate",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }
    dispatchControlActions(dispatch.actions, for: control, fallbackEvent: dispatch.event)
    return TKInputResult.success(
        action: action,
        message: "Dispatched \(dispatch.eventName)",
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: strategy
    )
}

@MainActor
func performTabBarControlTap(
    _ control: UIControl,
    request: TKInputRequest,
    action: String,
    matchedView: UIView?,
    strategy: String?
) -> TKInputResult? {
    let className = NSStringFromClass(type(of: control))
    let tabBar = nearestSuperview(of: control, matching: UITabBar.self) ?? tabBarContaining(control, request: request)
    guard let tabBar,
          let items = tabBar.items,
          !items.isEmpty else {
        return nil
    }

    let buttons = allSubviews(of: tabBar, matching: UIControl.self)
        .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 0 && $0.bounds.height > 0 }
        .sorted { $0.frame.minX < $1.frame.minX }
    let slots = tabBarButtonSlots(buttons)
    let requestPoint = request.x.flatMap { x in request.y.map { CGPoint(x: x, y: $0) } }
    let indexFromButton = slots.firstIndex(where: { slot in
        slot.contains { $0 === control || control.isDescendant(of: $0) }
    })
    let indexFromPoint = requestPoint.flatMap { point in
        slots.firstIndex(where: { slot in
            slot.contains { button in button.convert(button.bounds, to: nil).contains(point) }
        })
    }
    let indexFromClass = className.contains("_UITabButton") ? indexFromPoint : nil
    guard let index = indexFromButton ?? indexFromPoint ?? indexFromClass,
          index < items.count else {
        return nil
    }

    let matched = tapMatchedContext(request, fallback: matchedView)
    let activationOID = oid(for: control)
    let activationClassName = NSStringFromClass(type(of: control))
    let item = items[index]
    DispatchQueue.main.async { [weak tabBar] in
        guard let tabBar else { return }
        if let controller = nearestTabBarController(from: tabBar) {
            controller.selectedIndex = index
        } else {
            tabBar.selectedItem = item
            tabBar.delegate?.tabBar?(tabBar, didSelect: item)
        }
    }

    return TKInputResult.success(
        action: action,
        message: "Submitted UITabBar item selection",
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: strategy ?? "tab-bar-selection"
    )
}

@MainActor
func tabBarButtonSlots(_ buttons: [UIControl]) -> [[UIControl]] {
    let sorted = buttons.sorted {
        let lhs = $0.convert($0.bounds, to: nil).midX
        let rhs = $1.convert($1.bounds, to: nil).midX
        if abs(lhs - rhs) > 1 {
            return lhs < rhs
        }
        return $0.convert($0.bounds, to: nil).minY < $1.convert($1.bounds, to: nil).minY
    }
    return sorted.reduce(into: [[UIControl]]()) { slots, button in
        let midX = button.convert(button.bounds, to: nil).midX
        if let last = slots.last,
           let representativeMidX = last.map({ $0.convert($0.bounds, to: nil).midX }).min(),
           abs(midX - representativeMidX) <= 2 {
            slots[slots.count - 1].append(button)
        } else {
            slots.append([button])
        }
    }
}

@MainActor
func tabBarContaining(_ control: UIControl, request: TKInputRequest) -> UITabBar? {
    let className = NSStringFromClass(type(of: control))
    guard className.contains("_UITabButton"),
          let x = request.x,
          let y = request.y else {
        return nil
    }
    let point = CGPoint(x: x, y: y)
    for window in keyWindows() {
        for tabBar in allSubviews(of: window, matching: UITabBar.self) {
            if !tabBar.isHidden,
               tabBar.alpha > 0.01,
               tabBar.convert(tabBar.bounds, to: nil).contains(point) {
                return tabBar
            }
        }
    }
    return nil
}

func allSubviews<T: UIView>(of root: UIView, matching type: T.Type) -> [T] {
    var matches: [T] = []
    for subview in root.subviews {
        if let match = subview as? T {
            matches.append(match)
        }
        matches.append(contentsOf: allSubviews(of: subview, matching: type))
    }
    return matches
}

@MainActor
func performAncestorTapActivation(from view: UIView, request: TKInputRequest, action: String) -> TKInputResult? {
    if let control = nearestSuperview(of: view, matching: UIControl.self) {
        return performControlTap(
            control,
            request: request,
            action: action,
            matchedView: view,
            strategy: "ancestor-control-action"
        )
    }

    if let tableCell = nearestSuperview(of: view, matching: UITableViewCell.self)
        ?? tableCellContaining(request: request),
       let result = performTableCellTap(tableCell, request: request, action: action, matchedView: view) {
        return result
    }

    if let collectionCell = nearestSuperview(of: view, matching: UICollectionViewCell.self)
        ?? collectionCellContaining(request: request),
       let result = performCollectionCellTap(collectionCell, request: request, action: action, matchedView: view) {
        return result
    }

    if let gestureView = nearestTapGestureView(from: view) {
        return performTapGestureActivation(
            from: gestureView,
            request: request,
            action: action,
            matchedView: view,
            strategy: "ancestor-tap-gesture-recognizer"
        )
    }

    return nil
}

@MainActor
func performTapGestureActivation(
    from view: UIView,
    request: TKInputRequest,
    action: String,
    matchedView: UIView?,
    strategy: String = "tap-gesture-recognizer"
) -> TKInputResult? {
    guard let candidate = nearestTapGestureCandidate(from: view) else {
        return nil
    }
    let matched = tapMatchedContext(request, fallback: matchedView ?? view)
    let activationOID = oid(for: candidate.view)
    let activationClassName = NSStringFromClass(type(of: candidate.view))

    if candidate.view.accessibilityActivate() {
        return TKInputResult.success(
            action: action,
            message: "Activated tap gesture view via accessibilityActivate",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: "tap-gesture-accessibility-activate"
        )
    }

    return tapActivationFailure(
        request: request,
        action: action,
        view: candidate.view,
        message: "UITapGestureRecognizer target actions are not exposed through public UIKit runtime APIs",
        strategy: strategy
    )
}

func nearestTapGestureCandidate(from view: UIView) -> (view: UIView, gesture: UITapGestureRecognizer)? {
    var current: UIView? = view
    while let view = current {
        if view.isUserInteractionEnabled,
           let gesture = view.gestureRecognizers?.compactMap({ $0 as? UITapGestureRecognizer }).first(where: { gesture in
               gesture.isEnabled && gesture.numberOfTapsRequired <= 1 && gesture.numberOfTouchesRequired <= 1
           }) {
            return (view, gesture)
        }
        current = view.superview
    }
    return nil
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

func tapActivationFailure(
    request: TKInputRequest,
    action: String,
    view: UIView,
    message: String,
    strategy: String? = nil
) -> TKInputResult {
    let matched = tapMatchedContext(request, fallback: view)
    let activationOID = oid(for: view)
    let activationClassName = NSStringFromClass(type(of: view))
    return TKInputResult.failure(
        action: action,
        message: message,
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: strategy ?? request.activationStrategy?.rawValue
    )
}

@MainActor
func tableCellContaining(request: TKInputRequest) -> UITableViewCell? {
    guard let point = inputPoint(from: request) else { return nil }
    for window in keyWindows() {
        for tableView in allSubviews(of: window, matching: UITableView.self) where isInteractable(tableView) {
            let tablePoint = tableView.convert(point, from: nil)
            guard tableView.bounds.contains(tablePoint),
                  let indexPath = tableView.indexPathForRow(at: tablePoint) else {
                continue
            }
            if let cell = tableView.cellForRow(at: indexPath) {
                return cell
            }
        }
    }
    return nil
}

@MainActor
func collectionCellContaining(request: TKInputRequest) -> UICollectionViewCell? {
    guard let point = inputPoint(from: request) else { return nil }
    for window in keyWindows() {
        for collectionView in allSubviews(of: window, matching: UICollectionView.self) where isInteractable(collectionView) {
            let collectionPoint = collectionView.convert(point, from: nil)
            guard collectionView.bounds.contains(collectionPoint),
                  let indexPath = collectionView.indexPathForItem(at: collectionPoint) else {
                continue
            }
            if let cell = collectionView.cellForItem(at: indexPath) {
                return cell
            }
        }
    }
    return nil
}

func inputPoint(from request: TKInputRequest) -> CGPoint? {
    guard let x = request.x, let y = request.y else { return nil }
    return CGPoint(x: x, y: y)
}

func isInteractable(_ view: UIView) -> Bool {
    !view.isHidden && view.alpha > 0.01 && view.isUserInteractionEnabled
}

@MainActor
func performTableCellTap(
    _ cell: UITableViewCell,
    request: TKInputRequest,
    action: String,
    matchedView: UIView
) -> TKInputResult? {
    guard let tableView = nearestSuperview(of: cell, matching: UITableView.self),
          let indexPath = tableView.indexPath(for: cell) else {
        return nil
    }

    let matched = tapMatchedContext(request, fallback: matchedView)
    let activationOID = oid(for: cell)
    let activationClassName = NSStringFromClass(type(of: cell))
    guard tableView.allowsSelection, cell.isUserInteractionEnabled else {
        return TKInputResult.failure(
            action: action,
            message: "UITableViewCell ancestor is not selectable",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: "ancestor-table-cell-selection-blocked"
        )
    }
    if tableView.delegate?.responds(to: #selector(UITableViewDelegate.tableView(_:willSelectRowAt:))) == true,
       tableView.delegate?.tableView?(tableView, willSelectRowAt: indexPath) == nil {
        return TKInputResult.failure(
            action: action,
            message: "UITableViewCell ancestor selection was denied by delegate",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: "ancestor-table-cell-selection-denied"
        )
    }

    DispatchQueue.main.async { [weak tableView] in
        guard let tableView else { return }
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
    }

    return TKInputResult.success(
        action: action,
        message: "Submitted UITableViewCell ancestor selection",
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: "ancestor-table-cell-selection"
    )
}

@MainActor
func performCollectionCellTap(
    _ cell: UICollectionViewCell,
    request: TKInputRequest,
    action: String,
    matchedView: UIView
) -> TKInputResult? {
    guard let collectionView = nearestSuperview(of: cell, matching: UICollectionView.self),
          let indexPath = collectionView.indexPath(for: cell) else {
        return nil
    }

    let matched = tapMatchedContext(request, fallback: matchedView)
    let activationOID = oid(for: cell)
    let activationClassName = NSStringFromClass(type(of: cell))
    guard collectionView.allowsSelection, cell.isUserInteractionEnabled else {
        return TKInputResult.failure(
            action: action,
            message: "UICollectionViewCell ancestor is not selectable",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: "ancestor-collection-cell-selection-blocked"
        )
    }
    if collectionView.delegate?.responds(to: #selector(UICollectionViewDelegate.collectionView(_:shouldSelectItemAt:))) == true,
       collectionView.delegate?.collectionView?(collectionView, shouldSelectItemAt: indexPath) == false {
        return TKInputResult.failure(
            action: action,
            message: "UICollectionViewCell ancestor selection was denied by delegate",
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: "ancestor-collection-cell-selection-denied"
        )
    }

    DispatchQueue.main.async { [weak collectionView] in
        guard let collectionView else { return }
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
    }

    return TKInputResult.success(
        action: action,
        message: "Submitted UICollectionViewCell ancestor selection",
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: "ancestor-collection-cell-selection"
    )
}

func shouldUseAncestorTapActivation(_ request: TKInputRequest) -> Bool {
    request.activationStrategy == .smart || request.activationStrategy == .ancestor
}

func tapMatchedContext(_ request: TKInputRequest, fallback view: UIView?) -> (oid: UInt?, className: String?) {
    (
        oid: request.matchedOID ?? view.flatMap { oid(for: $0) },
        className: request.matchedClassName ?? view.map { NSStringFromClass(type(of: $0)) }
    )
}

func nearestTapGestureView(from view: UIView) -> UIView? {
    var current: UIView? = view
    while let view = current {
        if view.gestureRecognizers?.contains(where: { gesture in
            gesture is UITapGestureRecognizer && gesture.isEnabled
        }) == true {
            return view
        }
        current = view.superview
    }
    return nil
}

@MainActor
func preferredTapDispatch(for control: UIControl) -> (event: UIControl.Event, eventName: String, actions: [(target: Any?, action: Selector)])? {
    let preferredEvents: [(UIControl.Event, String)] = [
        (.primaryActionTriggered, "UIControl.primaryActionTriggered"),
        (.touchUpInside, "UIControl.touchUpInside"),
    ]

    for (event, eventName) in preferredEvents {
        let actions = targetActions(for: control, event: event)
        if !actions.isEmpty {
            return (event, eventName, actions)
        }
    }
    return nil
}

@MainActor
func targetActions(for control: UIControl, event: UIControl.Event) -> [(target: Any?, action: Selector)] {
    control.allTargets.flatMap { target in
        (control.actions(forTarget: target, forControlEvent: event) ?? []).map { action in
            (target: target is NSNull ? nil : target, action: Selector(action))
        }
    }
}

@MainActor
func dispatchControlActions(
    _ targetActions: [(target: Any?, action: Selector)],
    for control: UIControl,
    fallbackEvent: UIControl.Event
) {
    guard !targetActions.isEmpty else {
        control.sendActions(for: fallbackEvent)
        return
    }
    var dispatched = false
    for targetAction in targetActions {
        guard let target = targetAction.target as AnyObject? else { continue }
        dispatchTargetAction(targetAction.action, to: target, sender: control)
        dispatched = true
    }
    if !dispatched {
        control.sendActions(for: fallbackEvent)
    }
}

@MainActor
func dispatchValueChangedActions(for control: UIControl) {
    let targetActions = targetActions(for: control, event: .valueChanged)

    guard !targetActions.isEmpty else {
        control.sendActions(for: .valueChanged)
        return
    }
    var dispatched = false
    for targetAction in targetActions {
        guard let target = targetAction.target as AnyObject? else { continue }
        dispatchTargetAction(targetAction.action, to: target, sender: control)
        dispatched = true
    }
    if !dispatched {
        control.sendActions(for: .valueChanged)
    }
}

@MainActor
func dispatchTargetAction(_ action: Selector, to target: AnyObject, sender: AnyObject) {
    let argumentCount = NSStringFromSelector(action).filter { $0 == ":" }.count
    switch argumentCount {
    case 0:
        _ = target.perform(action)
    case 1:
        _ = target.perform(action, with: sender)
    default:
        _ = target.perform(action, with: sender, with: nil)
    }
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
        return TKInputResult.failure(
            action: action,
            message: "Hit view is not inside a UIScrollView",
            targetOID: oid(for: view),
            targetClassName: NSStringFromClass(type(of: view))
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

@MainActor
func performExactTextInsertion(_ request: TKInputRequest) async -> TKInputResult {
    let action = request.type.rawValue
    guard let text = request.text else {
        return TKInputResult.failure(action: action, message: "Missing text")
    }

    let resolved = resolveTextInputResponder(request)
    guard let responder = resolved.responder else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }

    #if canImport(WebKit)
    if let webViewResult = await performFocusedWebViewTextInsertionIfAvailable(
        responder: responder,
        text: text,
        action: action,
        secure: request.secure == true
    ) {
        return webViewResult
    }
    #endif

    return performUIKeyInputTextInsertion(request, responder: responder, text: text, action: action)
}

@MainActor
func performUIKeyInputTextInsertion(
    _ request: TKInputRequest,
    responder: UIResponder,
    text: String,
    action: String
) -> TKInputResult {
    guard let keyInput = responder as? UIKeyInput else {
        return TKInputResult.failure(
            action: action,
            message: "Target does not conform to UIKeyInput",
            targetOID: oid(for: responder),
            targetClassName: NSStringFromClass(type(of: responder))
        )
    }

    keyInput.insertText(text)
    notifyTextDidChange(for: responder)

    let secure = request.secure == true
    return TKInputResult.success(
        action: action,
        message: secure ? "Inserted redacted text" : "Inserted text",
        targetOID: oid(for: responder),
        targetClassName: NSStringFromClass(type(of: responder)),
        secure: secure,
        redacted: secure,
        insertedLength: text.count
    )
}

@MainActor
func performDeleteBackward(_ request: TKInputRequest) async -> TKInputResult {
    let action = request.type.rawValue
    let resolved = resolveTextInputResponder(request)
    guard let responder = resolved.responder else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }

    #if canImport(WebKit)
    if let webViewResult = await performFocusedWebViewDeleteBackwardIfAvailable(
        responder: responder,
        action: action
    ) {
        return webViewResult
    }
    #endif

    guard let keyInput = responder as? UIKeyInput else {
        return TKInputResult.failure(
            action: action,
            message: "Target does not conform to UIKeyInput",
            targetOID: oid(for: responder),
            targetClassName: NSStringFromClass(type(of: responder))
        )
    }

    guard keyInput.hasText else {
        return TKInputResult.success(
            action: action,
            message: "No text to delete",
            targetOID: oid(for: responder),
            targetClassName: NSStringFromClass(type(of: responder)),
            deletedLength: 0
        )
    }

    keyInput.deleteBackward()
    notifyTextDidChange(for: responder)

    return TKInputResult.success(
        action: action,
        message: "Deleted backward",
        targetOID: oid(for: responder),
        targetClassName: NSStringFromClass(type(of: responder)),
        deletedLength: 1
    )
}

@MainActor
func performClear(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    let resolved = resolveTextInputResponder(request)
    guard let responder = resolved.responder else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }

    if let textField = responder as? UITextField {
        textField.text = ""
    } else if let textView = responder as? UITextView {
        textView.text = ""
    } else if let keyInput = responder as? UIKeyInput {
        var guardCount = 0
        while keyInput.hasText && guardCount < 10_000 {
            keyInput.deleteBackward()
            guardCount += 1
        }
        if keyInput.hasText {
            return TKInputResult.failure(
                action: action,
                message: "Target still has text after clear limit",
                targetOID: oid(for: responder),
                targetClassName: NSStringFromClass(type(of: responder))
            )
        }
    } else {
        return TKInputResult.failure(
            action: action,
            message: "Target does not conform to UIKeyInput",
            targetOID: oid(for: responder),
            targetClassName: NSStringFromClass(type(of: responder))
        )
    }

    notifyTextDidChange(for: responder)
    return TKInputResult.success(
        action: action,
        message: "Cleared text",
        targetOID: oid(for: responder),
        targetClassName: NSStringFromClass(type(of: responder)),
        insertedLength: 0
    )
}

@MainActor
func resolveTextInputResponder(_ request: TKInputRequest) -> (responder: UIResponder?, message: String) {
    if let targetOID = request.targetOID {
        guard let responder = TKObjectRegistry.shared.object(for: targetOID) as? UIResponder else {
            return (nil, "Target oid is not a UIResponder: \(targetOID)")
        }
        return (responder, "Resolved target oid")
    }

    if request.x != nil || request.y != nil {
        let resolved = resolveView(targetOID: nil, x: request.x, y: request.y)
        guard let view = resolved.view else {
            return (nil, resolved.message)
        }
        if let textField = nearestSuperview(of: view, matching: UITextField.self) {
            textField.becomeFirstResponder()
            return (textField, "Focused text field")
        }
        if let textView = nearestSuperview(of: view, matching: UITextView.self) {
            textView.becomeFirstResponder()
            return (textView, "Focused text view")
        }
        if let responder = nearestTextInputResponder(from: view) {
            responder.becomeFirstResponder()
            return (responder, "Focused text input responder")
        }
        return (nil, "Hit view does not expose a UIKeyInput responder")
    }

    guard let responder = keyWindows().compactMap({ findFirstResponder(in: $0) }).first else {
        return (nil, "No target responder")
    }
    return (responder, "Resolved first responder")
}

func nearestTextInputResponder(from view: UIView) -> UIResponder? {
    var current: UIView? = view
    while let view = current {
        if view is UIKeyInput {
            return view
        }
        current = view.superview
    }
    return nil
}

@MainActor
func performSemanticAction(_ request: TKSemanticActionRequest) -> TKSemanticActionResponse {
    let startedAt = Date()

    func success(
        strategy: String,
        targetOID: UInt?,
        targetClassName: String?,
        message: String?,
        redaction: TKSemanticActionRedaction? = nil
    ) -> TKSemanticActionResponse {
        TKSemanticActionResponse(
            ok: true,
            action: request.action,
            strategy: strategy,
            targetOID: targetOID,
            targetClassName: targetClassName,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            message: message,
            redaction: redaction
        )
    }

    func failure(
        code: String,
        message: String,
        strategy: String? = nil,
        targetOID: UInt? = nil,
        targetClassName: String? = nil,
        redaction: TKSemanticActionRedaction? = nil
    ) -> TKSemanticActionResponse {
        TKSemanticActionResponse(
            ok: false,
            action: request.action,
            strategy: strategy ?? request.strategy ?? "runtime",
            targetOID: targetOID,
            targetClassName: targetClassName,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            message: message,
            error: TKCLIErrorDetail(code: code, message: message),
            redaction: redaction
        )
    }

    switch request.action {
    case .focus:
        let input = TKInputRequest.tap(x: request.x, y: request.y, targetOID: request.targetOID)
        let resolved = resolveTextInputResponder(input)
        guard let responder = resolved.responder else {
            return failure(code: "action_not_supported", message: resolved.message)
        }
        responder.becomeFirstResponder()
        return success(
            strategy: request.strategy ?? "focus-responder",
            targetOID: oid(for: responder),
            targetClassName: NSStringFromClass(type(of: responder)),
            message: "Focused text input responder"
        )

    case .setText:
        guard let text = request.text else {
            return failure(code: "invalid_payload", message: "Missing text")
        }
        let input = TKInputRequest(type: .typeText, targetOID: request.targetOID, x: request.x, y: request.y, text: text, secure: request.secure)
        let clear = performClear(TKInputRequest.clear(targetOID: request.targetOID, x: request.x, y: request.y))
        guard clear.ok else {
            return failure(
                code: "action_not_supported",
                message: clear.message ?? "Could not clear text",
                targetOID: clear.targetOID,
                targetClassName: clear.targetClassName,
                redaction: semanticRedaction(secure: request.secure == true, length: text.count)
            )
        }
        let insertedResolved = resolveTextInputResponder(input)
        guard let insertedResponder = insertedResolved.responder else {
            return failure(
                code: "action_not_supported",
                message: insertedResolved.message,
                redaction: semanticRedaction(secure: request.secure == true, length: text.count)
            )
        }
        let inserted = performUIKeyInputTextInsertion(
            input,
            responder: insertedResponder,
            text: text,
            action: input.type.rawValue
        )
        guard inserted.ok else {
            return failure(
                code: "action_not_supported",
                message: inserted.message ?? "Could not set text",
                targetOID: inserted.targetOID,
                targetClassName: inserted.targetClassName,
                redaction: semanticRedaction(secure: request.secure == true, length: text.count)
            )
        }
        return success(
            strategy: request.strategy ?? "set-text-ui-key-input",
            targetOID: inserted.targetOID,
            targetClassName: inserted.targetClassName,
            message: request.secure == true ? "Set redacted text" : "Set text",
            redaction: semanticRedaction(secure: request.secure == true, length: text.count)
        )

    case .selectSegment:
        guard let segmented = resolveControl(request, as: UISegmentedControl.self) else {
            return failure(code: "action_not_supported", message: "Target is not a UISegmentedControl")
        }
        let index: Int?
        if let segmentIndex = request.segmentIndex {
            index = segmentIndex
        } else if let title = request.segmentTitle {
            index = (0..<segmented.numberOfSegments).first { segmented.titleForSegment(at: $0) == title }
        } else {
            index = nil
        }
        guard let index, index >= 0, index < segmented.numberOfSegments else {
            return failure(
                code: "ambiguous_target",
                message: "Segment title or index did not match",
                targetOID: oid(for: segmented),
                targetClassName: NSStringFromClass(type(of: segmented))
            )
        }
        segmented.selectedSegmentIndex = index
        dispatchValueChangedActions(for: segmented)
        return success(
            strategy: request.strategy ?? "segmented-control",
            targetOID: oid(for: segmented),
            targetClassName: NSStringFromClass(type(of: segmented)),
            message: "Selected segment index \(index)"
        )

    case .setSwitch:
        guard let toggle = resolveControl(request, as: UISwitch.self) else {
            return failure(code: "action_not_supported", message: "Target is not a UISwitch")
        }
        let nextValue: Bool
        switch request.switchValue?.lowercased() {
        case "on", "true", "1":
            nextValue = true
        case "off", "false", "0":
            nextValue = false
        case "toggle", nil:
            nextValue = !toggle.isOn
        default:
            return failure(
                code: "invalid_payload",
                message: "Switch value must be on, off, or toggle",
                targetOID: oid(for: toggle),
                targetClassName: NSStringFromClass(type(of: toggle))
            )
        }
        toggle.setOn(nextValue, animated: false)
        toggle.sendActions(for: .valueChanged)
        return success(
            strategy: request.strategy ?? "switch-value",
            targetOID: oid(for: toggle),
            targetClassName: NSStringFromClass(type(of: toggle)),
            message: nextValue ? "Set switch on" : "Set switch off"
        )
    }
}

@MainActor
func resolveControl<T: UIControl>(_ request: TKSemanticActionRequest, as type: T.Type) -> T? {
    if let targetOID = request.targetOID {
        if let direct = TKObjectRegistry.shared.object(for: targetOID) as? T {
            return direct
        }
        if let view = TKObjectRegistry.shared.object(for: targetOID) as? UIView {
            return nearestSuperview(of: view, matching: type)
        }
    }
    let resolved = resolveView(targetOID: request.targetOID, x: request.x, y: request.y)
    guard let view = resolved.view else { return nil }
    return nearestSuperview(of: view, matching: type)
}

func semanticRedaction(secure: Bool, length: Int?) -> TKSemanticActionRedaction {
    TKSemanticActionRedaction(
        secure: secure,
        text: secure ? "length-only" : "not-collected",
        insertedLength: length
    )
}

func notifyTextDidChange(for responder: UIResponder) {
    if let textField = responder as? UITextField {
        textField.sendActions(for: .editingChanged)
    } else if let textView = responder as? UITextView {
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: textView)
    }
}

@MainActor
func resolveView(targetOID: UInt?, x: Double?, y: Double?) -> (view: UIView?, message: String) {
    if let targetOID {
        guard let view = TKObjectRegistry.shared.object(for: targetOID) as? UIView else {
            return (nil, "Target oid is not a UIView: \(targetOID)")
        }
        return (view, "Resolved target oid")
    }

    guard let x, let y else {
        return (nil, "Missing x/y or target oid")
    }
    guard let window = keyWindows().first else {
        return (nil, "No key window")
    }
    let point = CGPoint(x: x, y: y)
    guard window.bounds.contains(point) else {
        return (nil, "Point is outside key window bounds")
    }
    guard let view = window.hitTest(point, with: nil) else {
        return (nil, "No view hit at point")
    }
    return (view, "Hit-tested point")
}

@MainActor
func keyWindows() -> [UIWindow] {
    let sceneWindows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .filter { !$0.isHidden && $0.alpha > 0 }
    let fallbackWindows = sceneWindows.isEmpty
        ? UIApplication.shared.windows.filter { !$0.isHidden && $0.alpha > 0 }
        : []
    let registryWindows = sceneWindows.isEmpty && fallbackWindows.isEmpty
        ? TKObjectRegistry.shared.objects(of: UIWindow.self).filter { !$0.isHidden && $0.alpha > 0 }
        : []
    let key = sceneWindows.filter(\.isKeyWindow)
    if !key.isEmpty { return key }
    let fallbackKey = fallbackWindows.filter(\.isKeyWindow)
    if !fallbackKey.isEmpty { return fallbackKey }
    let registryKey = registryWindows.filter(\.isKeyWindow)
    if !registryKey.isEmpty { return registryKey }
    if !sceneWindows.isEmpty { return sceneWindows }
    return fallbackWindows.isEmpty ? registryWindows : fallbackWindows
}

func nearestTabBarController(from view: UIView) -> UITabBarController? {
    var current: UIView? = view
    while let view = current {
        var responder: UIResponder? = view
        while let next = responder {
            if let controller = next as? UITabBarController {
                return controller
            }
            if let controller = next as? UIViewController,
               let tabBarController = controller.tabBarController {
                return tabBarController
            }
            responder = next.next
        }
        current = view.superview
    }
    return nil
}
#endif
