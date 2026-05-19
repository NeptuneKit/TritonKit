import Foundation
import TritonKitShared
#if canImport(UIKit)
import UIKit
#endif

public class TritonKitRequestHandler: TritonKitDelegate {
    public weak var kit: TritonKit?

    public init() {}

    public func tritonKit(_ kit: TritonKit, didChangeState state: TritonKit.ConnectionState) {
        if state == .connected {
            self.kit = kit
        }
    }

    public func tritonKit(_ kit: TritonKit, didReceiveError error: Error) {
        // Errors handled by TritonKit itself (reconnect logic)
    }

    public func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) async -> TKMessage? {
        guard TritonKit.isRuntimeEnabled else {
            return TKMessage(id: message.id, type: .ping,
                payload: try? JSONEncoder().encode(TKErrorPayload(message: "TritonKit runtime is disabled outside DEBUG builds")))
        }
        self.kit = kit
        return await handle(message)
    }

    // MARK: - Message Routing

    private func handle(_ msg: TKMessage) async -> TKMessage? {
        switch msg.type {
        case .ping:
            let pong = PingResponse(pong: true, timestamp: Date().timeIntervalSince1970)
            return TKMessage(id: msg.id, type: .ping, payload: try? JSONEncoder().encode(pong))

        case .appInfo:
            let appInfo = TKAppInfo()
            let info = TKHierarchyInfo(displayItems: [], appInfo: appInfo)
            let payload = try? JSONEncoder().encode(info)
            return TKMessage(id: msg.id, type: .appInfo, payload: payload)

        case .hierarchy:
            let items = await TKHierarchyBuilder.buildHierarchy(includeScreenshots: false, uploader: nil)
            let appInfo = TKAppInfo()
            let hierarchy = TKHierarchyInfo(displayItems: items, appInfo: appInfo)
            let payload = try? JSONEncoder().encode(hierarchy)
            return TKMessage(id: msg.id, type: .hierarchy, payload: payload)

        case .hierarchyDetails:
            return handleHierarchyDetails(msg)

        case .allAttrGroups:
            return handleAllAttrGroups(msg)

        case .modifyAttribute:
            return handleModifyAttribute(msg)

        case .invokeMethod:
            return handleInvokeMethod(msg)

        case .fetchObject:
            return handleFetchObject(msg)

        case .input:
            return await handleInput(msg)

        case .accessibility:
            return await handleAccessibility(msg)

        case .hitTest:
            return await handleHitTest(msg)

        case .screenshot:
            return await handleScreenshot(msg)

        case .geometry:
            return await handleGeometry(msg)

        default:
            return TKMessage(id: msg.id, type: .ping,
                payload: try? JSONEncoder().encode(TKErrorPayload(message: "Unsupported: \(msg.type.rawValue)")))
        }
    }

    // MARK: - Handlers

    private func handleHierarchyDetails(_ msg: TKMessage) -> TKMessage? {
        // For now, return empty details list
        return TKMessage(id: msg.id, type: .hierarchyDetails, payload: try? JSONEncoder().encode([TKDisplayItemDetail]()))
    }

    private func handleAllAttrGroups(_ msg: TKMessage) -> TKMessage? {
        #if canImport(UIKit)
        guard let data = msg.payload,
              let oid = try? JSONDecoder().decode(UInt.self, from: data),
              let object = TKObjectRegistry.shared.object(for: oid) as? CALayer else {
            return TKMessage(id: msg.id, type: .allAttrGroups,
                payload: try? JSONEncoder().encode([TKAttributesGroup]()))
        }
        let groups = TKAttributeGroupsBuilder.build(for: object)
        let payload = try? JSONEncoder().encode(groups)
        return TKMessage(id: msg.id, type: .allAttrGroups, payload: payload)
        #else
        return TKMessage(id: msg.id, type: .allAttrGroups,
            payload: try? JSONEncoder().encode([TKAttributesGroup]()))
        #endif
    }

    private func handleModifyAttribute(_ msg: TKMessage) -> TKMessage? {
        let result = ModifyResult(success: true)
        return TKMessage(id: msg.id, type: .modifyAttribute, payload: try? JSONEncoder().encode(result))
    }

    private func handleInvokeMethod(_ msg: TKMessage) -> TKMessage? {
        guard let data = msg.payload else {
            return errorResponse(id: msg.id, message: "Missing params")
        }
        struct InvokeParams: Codable {
            let oid: UInt
            let selector: String
        }
        guard let params = try? JSONDecoder().decode(InvokeParams.self, from: data),
              let obj = TKObjectRegistry.shared.object(for: params.oid) else {
            return errorResponse(id: msg.id, message: "Object not found")
        }
        let selector = NSSelectorFromString(params.selector)
        guard obj.responds(to: selector) else {
            return errorResponse(id: msg.id, message: "Object doesn't respond to \(params.selector)")
        }
        let result = obj.perform(selector)?.takeUnretainedValue()
        let desc = result.map { String(describing: $0) } ?? "void"
        let invokeResult = InvokeResult(result: desc)
        let payload = try? JSONEncoder().encode(invokeResult)
        return TKMessage(id: msg.id, type: .invokeMethod, payload: payload)
    }

    private func handleFetchObject(_ msg: TKMessage) -> TKMessage? {
        guard let data = msg.payload,
              let oid = try? JSONDecoder().decode(UInt.self, from: data),
              let object = TKObjectRegistry.shared.object(for: oid) else {
            return errorResponse(id: msg.id, message: "Object not found")
        }
        let obj = TKObject(
            oid: oid,
            memoryAddress: "\(Unmanaged.passUnretained(object).toOpaque())",
            classChainList: classChain(for: object)
        )
        let payload = try? JSONEncoder().encode(obj)
        return TKMessage(id: msg.id, type: .fetchObject, payload: payload)
    }

    private func handleInput(_ msg: TKMessage) async -> TKMessage? {
        guard let data = msg.payload,
              let request = try? JSONDecoder().decode(TKInputRequest.self, from: data) else {
            let result = TKInputResult.failure(action: "input", message: "Missing or invalid input payload")
            return TKMessage(id: msg.id, type: .input, payload: try? JSONEncoder().encode(result))
        }

        #if canImport(UIKit)
        let result = await MainActor.run {
            performInput(request)
        }
        return TKMessage(id: msg.id, type: .input, payload: try? JSONEncoder().encode(result))
        #else
        let result = TKInputResult.unsupported(
            action: request.type.rawValue,
            message: "Input control requires UIKit runtime"
        )
        return TKMessage(id: msg.id, type: .input, payload: try? JSONEncoder().encode(result))
        #endif
    }

    private func handleAccessibility(_ msg: TKMessage) async -> TKMessage? {
        #if canImport(UIKit)
        let nodes = await MainActor.run {
            var context = AXBuildContext()
            return keyWindows().map { window in
                buildAXWindowNode(for: window, context: &context)
            }
        }
        return TKMessage(id: msg.id, type: .accessibility, payload: try? JSONEncoder().encode(nodes))
        #else
        return TKMessage(id: msg.id, type: .accessibility, payload: try? JSONEncoder().encode([TKAXNode]()))
        #endif
    }

    private func handleHitTest(_ msg: TKMessage) async -> TKMessage? {
        guard let data = msg.payload,
              let request = try? JSONDecoder().decode(TKHitTestRequest.self, from: data) else {
            return errorResponse(id: msg.id, message: "Missing or invalid hitTest payload")
        }
        #if canImport(UIKit)
        let response = await MainActor.run {
            performHitTest(request)
        }
        return TKMessage(id: msg.id, type: .hitTest, payload: try? JSONEncoder().encode(response))
        #else
        return TKMessage(id: msg.id, type: .hitTest,
            payload: try? JSONEncoder().encode(TKHitTestResponse(x: request.x, y: request.y, node: nil)))
        #endif
    }

    private func handleGeometry(_ msg: TKMessage) async -> TKMessage? {
        #if canImport(UIKit)
        let geometry = await MainActor.run {
            currentGeometry()
        }
        return TKMessage(id: msg.id, type: .geometry, payload: try? JSONEncoder().encode(geometry))
        #else
        let geometry = TKGeometryResponse(
            bounds: TKRect(x: 0, y: 0, width: 0, height: 0),
            safeArea: TKInsets(top: 0, left: 0, bottom: 0, right: 0),
            scale: 1,
            orientation: "unknown"
        )
        return TKMessage(id: msg.id, type: .geometry, payload: try? JSONEncoder().encode(geometry))
        #endif
    }

    private func handleScreenshot(_ msg: TKMessage) async -> TKMessage? {
        #if canImport(UIKit)
        let capture = await MainActor.run {
            captureCurrentScreenshotData()
        }
        let screenshot: TKScreenshotResponse
        if let dataRef = try? await kit?.uploader?.upload(capture.data) {
            screenshot = TKScreenshotResponse(
                format: capture.format,
                width: capture.width,
                height: capture.height,
                scale: capture.scale,
                dataBase64: "",
                dataRef: dataRef
            )
        } else {
            screenshot = TKScreenshotResponse(
                format: capture.format,
                width: capture.width,
                height: capture.height,
                scale: capture.scale,
                dataBase64: capture.data.base64EncodedString()
            )
        }
        return TKMessage(id: msg.id, type: .screenshot, payload: try? JSONEncoder().encode(screenshot))
        #else
        let screenshot = TKScreenshotResponse(format: "png", width: 0, height: 0, scale: 1, dataBase64: "")
        return TKMessage(id: msg.id, type: .screenshot, payload: try? JSONEncoder().encode(screenshot))
        #endif
    }

    // MARK: - Helpers

    private func errorResponse(id: Int, message: String) -> TKMessage {
        TKMessage(id: id, type: .ping,
            payload: try? JSONEncoder().encode(TKErrorPayload(message: message)))
    }

    private func classChain(for object: AnyObject) -> [String] {
        var chain: [String] = []
        var cls: AnyClass = type(of: object)
        while true {
            chain.append(NSStringFromClass(cls))
            guard let superCls = cls.superclass() else { break }
            cls = superCls
        }
        return chain
    }
}

#if canImport(UIKit)
@MainActor
private func performInput(_ request: TKInputRequest) -> TKInputResult {
    switch request.type {
    case .tap:
        return performTap(request)
    case .swipe:
        return performSwipe(request)
    case .typeText:
        return performType(request)
    case .button:
        return TKInputResult.unsupported(
            action: request.type.rawValue,
            message: "Host-side HID is not available in the embedded TritonKit runtime"
        )
    }
}

@MainActor
private func performTap(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    let resolved = resolveView(targetOID: request.targetOID, x: request.x, y: request.y)
    guard let view = resolved.view else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }

    if let textView = nearestSuperview(of: view, matching: UITextView.self) {
        textView.becomeFirstResponder()
        return TKInputResult.success(
            action: action,
            message: "Focused text view",
            targetOID: oid(for: textView),
            targetClassName: NSStringFromClass(type(of: textView))
        )
    }

    guard let control = nearestSuperview(of: view, matching: UIControl.self) else {
        return TKInputResult.failure(
            action: action,
            message: "Hit view does not expose a public UIControl tap action",
            targetOID: oid(for: view),
            targetClassName: NSStringFromClass(type(of: view))
        )
    }

    guard control.isEnabled else {
        return TKInputResult.failure(
            action: action,
            message: "Target UIControl is disabled",
            targetOID: oid(for: control),
            targetClassName: NSStringFromClass(type(of: control))
        )
    }

    if let textField = control as? UITextField {
        textField.becomeFirstResponder()
        return TKInputResult.success(
            action: action,
            message: "Focused text field",
            targetOID: oid(for: textField),
            targetClassName: NSStringFromClass(type(of: textField))
        )
    }

    if let toggle = control as? UISwitch {
        toggle.setOn(!toggle.isOn, animated: false)
        toggle.sendActions(for: .valueChanged)
        return TKInputResult.success(
            action: action,
            message: "Toggled UISwitch",
            targetOID: oid(for: toggle),
            targetClassName: NSStringFromClass(type(of: toggle))
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
            targetOID: oid(for: segmented),
            targetClassName: NSStringFromClass(type(of: segmented))
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
            targetOID: oid(for: slider),
            targetClassName: NSStringFromClass(type(of: slider))
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
            targetOID: oid(for: stepper),
            targetClassName: NSStringFromClass(type(of: stepper))
        )
    }

    guard let dispatch = preferredTapDispatch(for: control) else {
        return TKInputResult.failure(
            action: action,
            message: "Target UIControl has no primary or touchUpInside action",
            targetOID: oid(for: control),
            targetClassName: NSStringFromClass(type(of: control))
        )
    }
    dispatchControlActions(dispatch.actions, for: control, fallbackEvent: dispatch.event)
    return TKInputResult.success(
        action: action,
        message: "Dispatched \(dispatch.eventName)",
        targetOID: oid(for: control),
        targetClassName: NSStringFromClass(type(of: control))
    )
}

@MainActor
private func preferredTapDispatch(for control: UIControl) -> (event: UIControl.Event, eventName: String, actions: [(target: Any?, action: Selector)])? {
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
private func targetActions(for control: UIControl, event: UIControl.Event) -> [(target: Any?, action: Selector)] {
    control.allTargets.flatMap { target in
        (control.actions(forTarget: target, forControlEvent: event) ?? []).map { action in
            (target: target is NSNull ? nil : target, action: Selector(action))
        }
    }
}

@MainActor
private func dispatchControlActions(
    _ targetActions: [(target: Any?, action: Selector)],
    for control: UIControl,
    fallbackEvent: UIControl.Event
) {
    DispatchQueue.main.async {
        guard !targetActions.isEmpty else {
            control.sendActions(for: fallbackEvent)
            return
        }
        for targetAction in targetActions {
            UIApplication.shared.sendAction(targetAction.action, to: targetAction.target, from: control, for: nil)
        }
    }
}

@MainActor
private func dispatchValueChangedActions(for control: UIControl) {
    let targetActions = targetActions(for: control, event: .valueChanged)

    DispatchQueue.main.async {
        guard !targetActions.isEmpty else {
            control.sendActions(for: .valueChanged)
            return
        }
        for targetAction in targetActions {
            UIApplication.shared.sendAction(targetAction.action, to: targetAction.target, from: control, for: nil)
        }
    }
}

@MainActor
private func performSwipe(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    guard let startX = request.startX,
          let startY = request.startY,
          let endX = request.endX,
          let endY = request.endY else {
        return TKInputResult.failure(action: action, message: "Missing swipe coordinates")
    }

    let resolved = resolveView(targetOID: nil, x: startX, y: startY)
    guard let view = resolved.view else {
        return TKInputResult.failure(action: action, message: resolved.message)
    }
    guard let scrollView = nearestSuperview(of: view, matching: UIScrollView.self) else {
        return TKInputResult.failure(
            action: action,
            message: "Hit view is not inside a UIScrollView",
            targetOID: oid(for: view),
            targetClassName: NSStringFromClass(type(of: view))
        )
    }

    let deltaX = endX - startX
    let deltaY = endY - startY
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
        targetClassName: NSStringFromClass(type(of: scrollView))
    )
}

@MainActor
private func performType(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    guard let text = request.text else {
        return TKInputResult.failure(action: action, message: "Missing text")
    }

    let responder: UIResponder?
    if let targetOID = request.targetOID {
        responder = TKObjectRegistry.shared.object(for: targetOID) as? UIResponder
    } else {
        responder = keyWindows().compactMap { findFirstResponder(in: $0) }.first
    }

    guard let responder else {
        return TKInputResult.failure(action: action, message: "No target responder")
    }
    guard let keyInput = responder as? UIKeyInput else {
        return TKInputResult.failure(
            action: action,
            message: "Target does not conform to UIKeyInput",
            targetOID: oid(for: responder),
            targetClassName: NSStringFromClass(type(of: responder))
        )
    }

    keyInput.insertText(text)
    if let textField = responder as? UITextField {
        textField.sendActions(for: .editingChanged)
    } else if let textView = responder as? UITextView {
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: textView)
    }

    return TKInputResult.success(
        action: action,
        message: "Inserted text",
        targetOID: oid(for: responder),
        targetClassName: NSStringFromClass(type(of: responder))
    )
}

@MainActor
private func resolveView(targetOID: UInt?, x: Double?, y: Double?) -> (view: UIView?, message: String) {
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
private func keyWindows() -> [UIWindow] {
    let sceneWindows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .filter { !$0.isHidden && $0.alpha > 0 }
    let key = sceneWindows.filter(\.isKeyWindow)
    return key.isEmpty ? sceneWindows : key
}

private func nearestSuperview<T: UIView>(of view: UIView, matching type: T.Type) -> T? {
    var current: UIView? = view
    while let view = current {
        if let match = view as? T {
            return match
        }
        current = view.superview
    }
    return nil
}

private func findFirstResponder(in view: UIView) -> UIResponder? {
    if view.isFirstResponder {
        return view
    }
    for subview in view.subviews {
        if let responder = findFirstResponder(in: subview) {
            return responder
        }
    }
    return nil
}

private func oid(for object: UIResponder) -> UInt? {
    TKObjectRegistry.shared.register(object)
}

@MainActor
private func performHitTest(_ request: TKHitTestRequest) -> TKHitTestResponse {
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
private func currentGeometry() -> TKGeometryResponse {
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

private struct ScreenshotCapture {
    let format: String
    let width: Double
    let height: Double
    let scale: Double
    let data: Data
}

@MainActor
private func captureCurrentScreenshotData() -> ScreenshotCapture {
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

private struct AXBuildContext {
    var remaining: Int
    let maxDepth: Int

    init(maxNodes: Int = 200, maxDepth: Int = 12) {
        self.remaining = maxNodes
        self.maxDepth = maxDepth
    }
}

@MainActor
private func buildAXWindowNode(
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
private func collectAXLeafNodes(
    from view: UIView,
    in window: UIWindow,
    context: inout AXBuildContext,
    depth: Int = 0
) -> [TKAXNode] {
    guard context.remaining > 0, depth <= context.maxDepth else { return [] }
    var nodes: [TKAXNode] = []
    if isAXVisible(view), isAXSafeView(view), let node = buildAXLeafNode(for: view, in: window) {
        context.remaining -= 1
        nodes.append(node)
    }
    guard context.remaining > 0, depth < context.maxDepth else { return nodes }
    for subview in view.subviews {
        nodes.append(contentsOf: collectAXLeafNodes(from: subview, in: window, context: &context, depth: depth + 1))
        if context.remaining <= 0 {
            break
        }
    }
    return nodes
}

@MainActor
private func buildAXLeafNode(for view: UIView, in window: UIWindow) -> TKAXNode? {
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
        children: []
    )
}

private func nearestAXSafeSuperview(of view: UIView) -> UIView? {
    var current: UIView? = view
    while let view = current {
        if isAXSafeView(view) {
            return view
        }
        current = view.superview
    }
    return nil
}

private func isAXSafeView(_ view: UIView) -> Bool {
    switch view {
    case is UIControl, is UILabel, is UITextView, is UIScrollView, is UIImageView:
        return true
    default:
        return false
    }
}

private func isAXVisible(_ view: UIView) -> Bool {
    !view.isHidden && view.alpha > 0.01 && view.bounds.width > 0 && view.bounds.height > 0
}

private func tkRect(_ rect: CGRect) -> TKRect {
    TKRect(
        x: Double(rect.origin.x),
        y: Double(rect.origin.y),
        width: Double(rect.size.width),
        height: Double(rect.size.height)
    )
}

private func role(for view: UIView) -> String {
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

private func label(for view: UIView) -> String? {
    if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
        return accessibilityLabel
    }
    if let label = view as? UILabel {
        return label.text
    }
    if let button = view as? UIButton {
        return button.currentTitle
    }
    return nil
}

private func value(for view: UIView) -> String? {
    if let field = view as? UITextField {
        return field.text
    }
    if let textView = view as? UITextView {
        return textView.text
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
    return nil
}

private func identifier(for view: UIView) -> String? {
    switch view {
    case is UIControl, is UILabel, is UITextView, is UIImageView, is UIScrollView:
        return view.accessibilityIdentifier
    default:
        return nil
    }
}

private func title(for view: UIView) -> String? {
    if let button = view as? UIButton {
        return button.currentTitle
    }
    return nil
}

private func enabled(for view: UIView) -> Bool {
    if let control = view as? UIControl {
        return control.isEnabled
    }
    return view.isUserInteractionEnabled
}

@MainActor
private func currentOrientationName() -> String {
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
#endif

// MARK: - Response Payloads

private struct PingResponse: Codable {
    let pong: Bool
    let timestamp: TimeInterval
}

private struct InvokeResult: Codable {
    let result: String
}

private struct ModifyResult: Codable {
    let success: Bool
}
