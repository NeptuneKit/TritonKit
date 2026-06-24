import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
@MainActor
func performHitTest(_ request: TKHitTestRequest) -> TKHitTestResponse {
    guard let window = keyWindows().first else {
        return TKHitTestResponse(x: request.x, y: request.y, node: nil)
    }
    let point = CGPoint(x: request.x, y: request.y)
    guard window.bounds.contains(point),
          let view = window.hitTest(point, with: nil) else {
        return TKHitTestResponse(x: request.x, y: request.y, node: nil)
    }
    let target = nearestAXSafeSuperview(of: view) ?? view
    return TKHitTestResponse(x: request.x, y: request.y, node: buildAXLeafNode(for: target, in: window))
}

@MainActor
func currentGeometry() -> TKGeometryResponse {
    guard let window = keyWindows().first else {
        return TKGeometryResponse(
            bounds: TKRect(x: 0, y: 0, width: 0, height: 0),
            safeArea: TKInsets(top: 0, left: 0, bottom: 0, right: 0),
            scale: UIScreen.main.scale,
            orientation: "unknown"
        )
    }
    let insets = window.safeAreaInsets
    return TKGeometryResponse(
        bounds: tkRect(window.bounds),
        safeArea: TKInsets(
            top: Double(insets.top),
            left: Double(insets.left),
            bottom: Double(insets.bottom),
            right: Double(insets.right)
        ),
        scale: Double(window.screen.scale),
        orientation: currentOrientationName()
    )
}

struct ScreenshotCapture {
    let format: String
    let width: Double
    let height: Double
    let scale: Double
    let data: Data
}

@MainActor
func captureCurrentScreenshotData() -> ScreenshotCapture {
    guard let window = keyWindows().first else {
        return ScreenshotCapture(format: "png", width: 0, height: 0, scale: UIScreen.main.scale, data: Data())
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = window.isOpaque
    let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
    let image = renderer.image { context in
        window.layer.render(in: context.cgContext)
    }
    let data = image.pngData() ?? Data()
    return ScreenshotCapture(
        format: "png",
        width: Double(window.bounds.width),
        height: Double(window.bounds.height),
        scale: Double(format.scale),
        data: data
    )
}

struct AXBuildContext {
    var remaining: Int
    let maxDepth: Int

    init(maxNodes: Int = 800, maxDepth: Int = 32) {
        self.remaining = maxNodes
        self.maxDepth = maxDepth
    }
}

@MainActor
func buildAXWindowNode(
    for window: UIWindow,
    context: inout AXBuildContext
) -> TKAXNode {
    TKAXNode(
        role: "window",
        label: nil,
        value: nil,
        identifier: nil,
        title: nil,
        frame: tkRect(window.bounds),
        enabled: window.isUserInteractionEnabled,
        focused: window.isKeyWindow,
        hidden: window.isHidden || window.alpha <= 0.01,
        targetOID: oid(for: window),
        className: NSStringFromClass(type(of: window)),
        children: collectAXLeafNodes(from: window, in: window, context: &context)
    )
}

@MainActor
func collectAXLeafNodes(
    from view: UIView,
    in window: UIWindow,
    context: inout AXBuildContext,
    depth: Int = 0
) -> [TKAXNode] {
    guard isAXVisible(view), context.remaining > 0, depth <= context.maxDepth else { return [] }

    let children: [TKAXNode]
    if shouldCollectAXChildren(from: view), depth < context.maxDepth {
        var collected: [TKAXNode] = []
        for subview in view.subviews {
            collected.append(contentsOf: collectAXLeafNodes(from: subview, in: window, context: &context, depth: depth + 1))
            if context.remaining <= 0 {
                break
            }
        }
        children = collected
    } else {
        children = []
    }

    guard context.remaining > 0,
          isAXSafeView(view),
          let node = buildAXNode(for: view, in: window, children: shouldNestAXChildren(for: view) ? children : []),
          shouldEmitAXNode(node, for: view) else {
        return children
    }
    context.remaining -= 1
    return [node]
}

@MainActor
func buildAXLeafNode(for view: UIView, in window: UIWindow) -> TKAXNode? {
    buildAXNode(for: view, in: window, children: [])
}

@MainActor
func buildAXNode(for view: UIView, in window: UIWindow, children: [TKAXNode]) -> TKAXNode? {
    guard isAXVisible(view) else { return nil }
    let identifier = identifier(for: view)
    let viewOID = oid(for: view)
    return TKAXNode(
        role: role(for: view),
        label: label(for: view),
        value: value(for: view),
        identifier: identifier,
        title: title(for: view),
        frame: tkRect(view.convert(view.bounds, to: window)),
        enabled: enabled(for: view),
        focused: view.isFirstResponder,
        hidden: view.isHidden || view.alpha <= 0.01,
        targetOID: viewOID,
        viewOID: identifier == nil ? nil : viewOID,
        className: NSStringFromClass(type(of: view)),
        children: children
    )
}

func nearestAXSafeSuperview(of view: UIView) -> UIView? {
    var current: UIView? = view
    while let view = current {
        if isAXSafeView(view) {
            return view
        }
        current = view.superview
    }
    return nil
}

func isAXSafeView(_ view: UIView) -> Bool {
    switch view {
    case is UIControl, is UILabel, is UITextView, is UIScrollView, is UIImageView:
        return true
    default:
        return false
    }
}

func shouldCollectAXChildren(from view: UIView) -> Bool {
    if view is UITextView {
        return false
    }
    if view is UIScrollView {
        return true
    }
    switch view {
    case is UIControl, is UILabel, is UIImageView:
        return false
    default:
        return true
    }
}

func shouldNestAXChildren(for view: UIView) -> Bool {
    view is UIScrollView && !(view is UITextView)
}

func shouldEmitAXNode(_ node: TKAXNode, for view: UIView) -> Bool {
    if view is UIControl {
        return true
    }
    if view is UIScrollView, !(view is UITextView) {
        return hasAXSemantics(node) || !node.children.isEmpty
    }
    return hasAXSemantics(node)
}

func hasAXSemantics(_ node: TKAXNode) -> Bool {
    nonEmptyText(node.label) != nil
        || nonEmptyText(node.value) != nil
        || nonEmptyText(node.identifier) != nil
        || nonEmptyText(node.title) != nil
}

func isAXVisible(_ view: UIView) -> Bool {
    !view.isHidden && view.alpha > 0.01 && view.bounds.width > 0 && view.bounds.height > 0
}

func tkRect(_ rect: CGRect) -> TKRect {
    TKRect(
        x: Double(rect.origin.x),
        y: Double(rect.origin.y),
        width: Double(rect.size.width),
        height: Double(rect.size.height)
    )
}

func role(for view: UIView) -> String {
    switch view {
    case is UIWindow: return "window"
    case is UISegmentedControl: return "segmentedControl"
    case is UISlider: return "slider"
    case is UIStepper: return "stepper"
    case is UIButton: return "button"
    case is UISwitch: return "switch"
    case is UITextField: return "textField"
    case is UITextView: return "textView"
    case is UILabel: return "text"
    case is UIImageView: return "image"
    case is UIScrollView: return "scrollView"
    case is UIControl: return "control"
    default: return "view"
    }
}

func label(for view: UIView) -> String? {
    if let accessibilityLabel = nonEmptyText(view.accessibilityLabel) {
        return accessibilityLabel
    }
    if let label = view as? UILabel {
        return nonEmptyText(label.text) ?? nonEmptyText(label.attributedText?.string)
    }
    if let button = view as? UIButton {
        return nonEmptyText(button.currentTitle) ?? nonEmptyText(button.currentAttributedTitle?.string)
    }
    if let field = view as? UITextField {
        return nonEmptyText(field.placeholder)
    }
    return nil
}

func value(for view: UIView) -> String? {
    if let field = view as? UITextField {
        return nonEmptyText(field.text) ?? nonEmptyText(field.placeholder)
    }
    if let textView = view as? UITextView {
        return nonEmptyText(textView.text)
    }
    if let toggle = view as? UISwitch {
        return toggle.isOn ? "1" : "0"
    }
    if let segmented = view as? UISegmentedControl {
        guard segmented.selectedSegmentIndex >= 0 else { return nil }
        return segmented.titleForSegment(at: segmented.selectedSegmentIndex)
    }
    if let slider = view as? UISlider {
        return String(format: "%.2f", slider.value)
    }
    if let stepper = view as? UIStepper {
        return String(format: "%.0f", stepper.value)
    }
    return nonEmptyText(view.accessibilityValue)
}

func identifier(for view: UIView) -> String? {
    switch view {
    case is UIControl, is UILabel, is UITextView, is UIImageView, is UIScrollView:
        return nonEmptyText(view.accessibilityIdentifier)
    default:
        return nil
    }
}

func title(for view: UIView) -> String? {
    if let button = view as? UIButton {
        return nonEmptyText(button.currentTitle) ?? nonEmptyText(button.currentAttributedTitle?.string)
    }
    return nil
}

func nonEmptyText(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func enabled(for view: UIView) -> Bool {
    if let control = view as? UIControl {
        return control.isEnabled
    }
    return view.isUserInteractionEnabled
}

@MainActor
func currentOrientationName() -> String {
    let orientation = keyWindows().first?.windowScene?.interfaceOrientation
    switch orientation {
    case .portrait: return "portrait"
    case .portraitUpsideDown: return "portraitUpsideDown"
    case .landscapeLeft: return "landscapeLeft"
    case .landscapeRight: return "landscapeRight"
    case .unknown, nil: return "unknown"
    @unknown default: return "unknown"
    }
}

func interfaceOrientationName(_ orientation: UIInterfaceOrientation) -> String {
    switch orientation {
    case .portrait: return "portrait"
    case .portraitUpsideDown: return "portraitUpsideDown"
    case .landscapeLeft: return "landscapeLeft"
    case .landscapeRight: return "landscapeRight"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
}

func activationStateName(_ state: UIScene.ActivationState) -> String {
    switch state {
    case .foregroundActive: return "foregroundActive"
    case .foregroundInactive: return "foregroundInactive"
    case .background: return "background"
    case .unattached: return "unattached"
    @unknown default: return "unknown"
    }
}

func userInterfaceStyleName(_ style: UIUserInterfaceStyle) -> String {
    switch style {
    case .unspecified: return "unspecified"
    case .light: return "light"
    case .dark: return "dark"
    @unknown default: return "unknown"
    }
}

func keyboardTypeName(_ type: UIKeyboardType) -> String {
    switch type {
    case .default: return "default"
    case .asciiCapable: return "asciiCapable"
    case .numbersAndPunctuation: return "numbersAndPunctuation"
    case .URL: return "URL"
    case .numberPad: return "numberPad"
    case .phonePad: return "phonePad"
    case .namePhonePad: return "namePhonePad"
    case .emailAddress: return "emailAddress"
    case .decimalPad: return "decimalPad"
    case .twitter: return "twitter"
    case .webSearch: return "webSearch"
    case .asciiCapableNumberPad: return "asciiCapableNumberPad"
    @unknown default: return "unknown"
    }
}

func returnKeyTypeName(_ type: UIReturnKeyType) -> String {
    switch type {
    case .default: return "default"
    case .go: return "go"
    case .google: return "google"
    case .join: return "join"
    case .next: return "next"
    case .route: return "route"
    case .search: return "search"
    case .send: return "send"
    case .yahoo: return "yahoo"
    case .done: return "done"
    case .emergencyCall: return "emergencyCall"
    case .continue: return "continue"
    @unknown default: return "unknown"
    }
}
#endif
