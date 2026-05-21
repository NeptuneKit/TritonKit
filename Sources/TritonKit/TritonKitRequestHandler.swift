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
            if message.type == .runtimeManifest {
                return TKMessage(
                    id: message.id,
                    type: .runtimeManifest,
                    payload: try? JSONEncoder().encode(TKRuntimeManifestResponse.releaseDisabled(sdkVersion: "0.1.0-dev"))
                )
            }
            return TKMessage(id: message.id, type: .ping,
                payload: try? JSONEncoder().encode(TKErrorPayload(message: "TritonKit runtime is disabled outside DEBUG builds")))
        }
        self.kit = kit
        let startedAt = Date()
        let response = await handle(message)
        if message.type != .runtimeLedger {
            recordRuntimeLedger(message: message, response: response, elapsedMs: elapsedMilliseconds(since: startedAt))
        }
        return response
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

        case .runtimeManifest:
            let manifest = TKRuntimeManifestResponse.debugDefault(sdkVersion: "0.1.0-dev")
            let payload = try? JSONEncoder().encode(manifest)
            return TKMessage(id: msg.id, type: .runtimeManifest, payload: payload)

        case .stateApp:
            #if canImport(UIKit)
            let state = await MainActor.run { currentAppState() }
            #else
            let state = TKRuntimeAppStateResponse(
                capturedAt: currentStateTimestamp(),
                app: TKRuntimeAppState(
                    bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                    displayName: Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "",
                    version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                    localeIdentifier: Locale.current.identifier,
                    preferredLanguages: Locale.preferredLanguages,
                    userInterfaceStyle: "unknown",
                    processUptimeSeconds: ProcessInfo.processInfo.systemUptime,
                    sceneCount: 0,
                    windowCount: 0
                ),
                unsupported: [TKRuntimeUnsupportedState(field: "uikit", reason: "App state scene details require UIKit runtime")]
            )
            #endif
            return TKMessage(id: msg.id, type: .stateApp, payload: try? JSONEncoder().encode(state))

        case .stateScene:
            #if canImport(UIKit)
            let state = await MainActor.run { currentSceneState() }
            #else
            let state = TKRuntimeSceneStateResponse(
                capturedAt: currentStateTimestamp(),
                scenes: [],
                unsupported: [TKRuntimeUnsupportedState(field: "scenes", reason: "Scene state requires UIKit runtime")]
            )
            #endif
            return TKMessage(id: msg.id, type: .stateScene, payload: try? JSONEncoder().encode(state))

        case .stateRoute:
            #if canImport(UIKit)
            let state = await MainActor.run { currentRouteState() }
            #else
            let state = TKRuntimeRouteStateResponse(
                capturedAt: currentStateTimestamp(),
                unsupported: [TKRuntimeUnsupportedState(field: "route", reason: "Route state requires UIKit runtime")]
            )
            #endif
            return TKMessage(id: msg.id, type: .stateRoute, payload: try? JSONEncoder().encode(state))

        case .stateResponder:
            #if canImport(UIKit)
            let state = await MainActor.run { currentResponderState() }
            #else
            let state = TKRuntimeResponderStateResponse(
                capturedAt: currentStateTimestamp(),
                unsupported: [TKRuntimeUnsupportedState(field: "firstResponder", reason: "Responder state requires UIKit runtime")]
            )
            #endif
            return TKMessage(id: msg.id, type: .stateResponder, payload: try? JSONEncoder().encode(state))

        case .runtimeSnapshot:
            let request = msg.payload.flatMap { try? JSONDecoder().decode(TKRuntimeSnapshotRequest.self, from: $0) } ?? TKRuntimeSnapshotRequest()
            #if canImport(UIKit)
            let snapshot = await MainActor.run { currentRuntimeSnapshot(request) }
            #else
            let snapshot = TKRuntimeSnapshotResponse(
                capturedAt: currentStateTimestamp(),
                include: request.include,
                skipped: request.include.map { TKRuntimeSnapshotSkipped(name: $0, reason: "Runtime snapshot requires UIKit runtime") }
            )
            #endif
            return TKMessage(id: msg.id, type: .runtimeSnapshot, payload: try? JSONEncoder().encode(snapshot))

        case .semanticAction:
            guard let data = msg.payload,
                  let request = try? JSONDecoder().decode(TKSemanticActionRequest.self, from: data) else {
                let result = TKSemanticActionResponse(
                    ok: false,
                    action: .focus,
                    strategy: "invalid-payload",
                    elapsedMs: 0,
                    message: "Missing or invalid semantic action payload",
                    error: TKCLIErrorDetail(code: "invalid_payload", message: "Missing or invalid semantic action payload")
                )
                return TKMessage(id: msg.id, type: .semanticAction, payload: try? JSONEncoder().encode(result))
            }
            #if canImport(UIKit)
            let result = await MainActor.run { performSemanticAction(request) }
            #else
            let result = TKSemanticActionResponse(
                ok: false,
                action: request.action,
                strategy: request.strategy ?? "unsupported-runtime",
                elapsedMs: 0,
                message: "Semantic actions require UIKit runtime",
                error: TKCLIErrorDetail(code: "unsupported_runtime_scope", message: "Semantic actions require UIKit runtime")
            )
            #endif
            return TKMessage(id: msg.id, type: .semanticAction, payload: try? JSONEncoder().encode(result))

        case .runtimeLedger:
            let request = msg.payload.flatMap { try? JSONDecoder().decode(TKRuntimeLedgerRequest.self, from: $0) } ?? TKRuntimeLedgerRequest()
            let response = runtimeLedgerStore.response(limit: request.limit)
            return TKMessage(id: msg.id, type: .runtimeLedger, payload: try? JSONEncoder().encode(response))

        case .hierarchy:
            let items = await TKHierarchyBuilder.buildHierarchy()
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

private let runtimeLedgerStore = RuntimeLedgerStore(maxEntries: 100)

private final class RuntimeLedgerStore: @unchecked Sendable {
    private let lock = NSLock()
    private let maxEntries: Int
    private var nextID = 1
    private var entries: [TKRuntimeLedgerEntry] = []

    init(maxEntries: Int) {
        self.maxEntries = maxEntries
    }

    func append(_ entry: TKRuntimeLedgerEntry) {
        lock.withLock {
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
        }
    }

    func nextEntryID() -> Int {
        lock.withLock {
            defer { nextID += 1 }
            return nextID
        }
    }

    func response(limit: Int) -> TKRuntimeLedgerResponse {
        let boundedLimit = max(0, min(limit, maxEntries))
        return lock.withLock {
            TKRuntimeLedgerResponse(
                entries: Array(entries.suffix(boundedLimit)),
                limit: boundedLimit,
                maxEntries: maxEntries
            )
        }
    }
}

private func recordRuntimeLedger(message: TKMessage, response: TKMessage?, elapsedMs: Int) {
    let details = runtimeLedgerDetails(message: message, response: response)
    runtimeLedgerStore.append(TKRuntimeLedgerEntry(
        id: runtimeLedgerStore.nextEntryID(),
        timestamp: currentStateTimestamp(),
        source: details.source,
        requestType: message.type.rawValue,
        action: details.action,
        ok: details.ok,
        elapsedMs: elapsedMs,
        errorCode: details.errorCode,
        message: details.message,
        redaction: details.redaction
    ))
}

private func runtimeLedgerDetails(
    message: TKMessage,
    response: TKMessage?
) -> (source: String, action: String?, ok: Bool, errorCode: String?, message: String?, redaction: TKSemanticActionRedaction?) {
    var source = "cli"
    var action: String?
    var redaction: TKSemanticActionRedaction?

    if message.type == .semanticAction,
       let payload = message.payload,
       let request = try? JSONDecoder().decode(TKSemanticActionRequest.self, from: payload) {
        source = request.sourceCommand ?? "cli"
        action = request.action.rawValue
        if request.secure == true {
            redaction = TKSemanticActionRedaction(secure: true, text: "length-only", insertedLength: request.text?.count)
        }
    } else if message.type == .input,
              let payload = message.payload,
              let request = try? JSONDecoder().decode(TKInputRequest.self, from: payload) {
        action = request.type.rawValue
        if request.secure == true {
            redaction = TKSemanticActionRedaction(secure: true, text: "length-only", insertedLength: request.text?.count)
        }
    }

    guard let payload = response?.payload else {
        return (source, action, false, "missing_response", "Runtime did not produce a response", redaction)
    }
    if let semantic = try? JSONDecoder().decode(TKSemanticActionResponse.self, from: payload) {
        return (
            source,
            semantic.action.rawValue,
            semantic.ok,
            semantic.error?.code,
            semantic.message,
            semantic.redaction ?? redaction
        )
    }
    if let input = try? JSONDecoder().decode(TKInputResult.self, from: payload) {
        return (
            source,
            input.action,
            input.ok,
            input.ok ? nil : "action_failed",
            input.message,
            input.redacted == true ? TKSemanticActionRedaction(secure: input.secure == true, text: "length-only", insertedLength: input.insertedLength) : redaction
        )
    }
    if let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
        let ok = object["ok"] as? Bool ?? true
        let message = object["message"] as? String
        let errorCode = (object["error"] as? [String: Any])?["code"] as? String
        return (source, action, ok, errorCode, message, redaction)
    }
    return (source, action, true, nil, nil, redaction)
}

private func elapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1000))
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
        return performExactTextInsertion(request)
    case .paste:
        return performExactTextInsertion(request)
    case .clear:
        return performClear(request)
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

    if let responder = nearestTextInputResponder(from: view) {
        responder.becomeFirstResponder()
        return TKInputResult.success(
            action: action,
            message: "Focused text input responder",
            targetOID: oid(for: responder),
            targetClassName: NSStringFromClass(type(of: responder))
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
private func performExactTextInsertion(_ request: TKInputRequest) -> TKInputResult {
    let action = request.type.rawValue
    guard let text = request.text else {
        return TKInputResult.failure(action: action, message: "Missing text")
    }

    let resolved = resolveTextInputResponder(request)
    guard let responder = resolved.responder else {
        return TKInputResult.failure(action: action, message: resolved.message)
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
private func performClear(_ request: TKInputRequest) -> TKInputResult {
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
private func resolveTextInputResponder(_ request: TKInputRequest) -> (responder: UIResponder?, message: String) {
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

private func nearestTextInputResponder(from view: UIView) -> UIResponder? {
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
private func performSemanticAction(_ request: TKSemanticActionRequest) -> TKSemanticActionResponse {
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
        let inserted = performExactTextInsertion(input)
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
private func resolveControl<T: UIControl>(_ request: TKSemanticActionRequest, as type: T.Type) -> T? {
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

private func semanticRedaction(secure: Bool, length: Int?) -> TKSemanticActionRedaction {
    TKSemanticActionRedaction(
        secure: secure,
        text: secure ? "length-only" : "not-collected",
        insertedLength: length
    )
}

private func notifyTextDidChange(for responder: UIResponder) {
    if let textField = responder as? UITextField {
        textField.sendActions(for: .editingChanged)
    } else if let textView = responder as? UITextView {
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: textView)
    }
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

@MainActor
private func currentAppState() -> TKRuntimeAppStateResponse {
    let windows = allRuntimeWindows()
    let info = Bundle.main.infoDictionary ?? [:]
    let displayName = info["CFBundleDisplayName"] as? String
        ?? info["CFBundleName"] as? String
        ?? ""
    let style = windows.first.map { userInterfaceStyleName($0.traitCollection.userInterfaceStyle) } ?? "unknown"
    return TKRuntimeAppStateResponse(
        capturedAt: currentStateTimestamp(),
        app: TKRuntimeAppState(
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
            displayName: displayName,
            version: info["CFBundleShortVersionString"] as? String,
            build: info["CFBundleVersion"] as? String,
            localeIdentifier: Locale.current.identifier,
            preferredLanguages: Locale.preferredLanguages,
            preferredContentSizeCategory: UIApplication.shared.preferredContentSizeCategory.rawValue,
            userInterfaceStyle: style,
            processUptimeSeconds: ProcessInfo.processInfo.systemUptime,
            sceneCount: UIApplication.shared.connectedScenes.count,
            windowCount: windows.count
        )
    )
}

@MainActor
private func currentSceneState() -> TKRuntimeSceneStateResponse {
    let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .enumerated()
        .map { sceneIndex, scene in
            let windows = scene.windows.enumerated().map { windowIndex, window in
                runtimeWindowState(window, id: "scene-\(sceneIndex)-window-\(windowIndex)")
            }
            return TKRuntimeSceneState(
                id: "scene-\(sceneIndex)",
                activationState: activationStateName(scene.activationState),
                interfaceOrientation: interfaceOrientationName(scene.interfaceOrientation),
                screenBounds: tkRect(scene.screen.bounds),
                screenScale: Double(scene.screen.scale),
                windowCount: scene.windows.count,
                windows: windows
            )
        }
    return TKRuntimeSceneStateResponse(
        capturedAt: currentStateTimestamp(),
        scenes: scenes,
        keyWindow: allRuntimeWindows().enumerated().first(where: { $0.element.isKeyWindow }).map {
            runtimeWindowState($0.element, id: "window-\($0.offset)")
        },
        warnings: scenes.isEmpty ? ["No UIWindowScene is connected"] : []
    )
}

@MainActor
private func currentRouteState() -> TKRuntimeRouteStateResponse {
    guard let root = keyWindows().first?.rootViewController else {
        return TKRuntimeRouteStateResponse(
            capturedAt: currentStateTimestamp(),
            warnings: ["No key window root view controller"]
        )
    }
    let visible = visibleController(from: root)
    let navigationController = (visible as? UINavigationController) ?? visible?.navigationController ?? (root as? UINavigationController)
    let tabController = (visible as? UITabBarController) ?? visible?.tabBarController ?? (root as? UITabBarController)
    let navigationStack = navigationController?.viewControllers.map(controllerState) ?? []
    let presentedStack = presentedControllerStack(from: root)
    let tabState = tabController.map(runtimeTabState)
    let controllers = [root, visible].compactMap { $0 } + navigationStack.compactMap { controller in
        TKObjectRegistry.shared.object(for: controller.oid ?? 0) as? UIViewController
    } + presentedStack.compactMap { controller in
        TKObjectRegistry.shared.object(for: controller.oid ?? 0) as? UIViewController
    }
    let hasSwiftUIBoundary = controllers.contains { NSStringFromClass(type(of: $0)).contains("UIHostingController") }

    return TKRuntimeRouteStateResponse(
        capturedAt: currentStateTimestamp(),
        rootController: controllerState(root),
        visibleController: visible.map(controllerState),
        presentedStack: presentedStack,
        navigationStack: navigationStack,
        tab: tabState,
        swiftUIBoundary: hasSwiftUIBoundary,
        warnings: hasSwiftUIBoundary ? ["SwiftUI private view tree is not reflected; only UIHostingController boundary is reported"] : []
    )
}

@MainActor
private func currentResponderState() -> TKRuntimeResponderStateResponse {
    let windows = keyWindows()
    for (windowIndex, window) in windows.enumerated() {
        guard let responder = findFirstResponder(in: window) else { continue }
        let view = responder as? UIView
        let frame = view.map { tkRect(window.convert($0.bounds, from: $0)) }
        let traits = responder as? UITextInputTraits
        return TKRuntimeResponderStateResponse(
            capturedAt: currentStateTimestamp(),
            firstResponder: TKRuntimeResponderState(
                oid: oid(for: responder),
                className: NSStringFromClass(type(of: responder)),
                frame: frame,
                windowIndex: windowIndex,
                isTextInput: responder is UIKeyInput,
                isEditable: textInputEditable(responder),
                isSecureTextEntry: traits?.isSecureTextEntry,
                keyboardType: traits.flatMap { $0.keyboardType.map(keyboardTypeName) },
                returnKeyType: traits.flatMap { $0.returnKeyType.map(returnKeyTypeName) }
            ),
            redaction: TKRuntimeStateRedaction()
        )
    }
    return TKRuntimeResponderStateResponse(
        capturedAt: currentStateTimestamp(),
        warnings: ["No first responder found in key windows"]
    )
}

@MainActor
private func allRuntimeWindows() -> [UIWindow] {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
}

private func runtimeWindowState(_ window: UIWindow, id: String) -> TKRuntimeWindowState {
    TKRuntimeWindowState(
        id: id,
        isKeyWindow: window.isKeyWindow,
        isHidden: window.isHidden,
        alpha: Double(window.alpha),
        windowLevel: Double(window.windowLevel.rawValue),
        bounds: tkRect(window.bounds),
        safeArea: TKInsets(
            top: Double(window.safeAreaInsets.top),
            left: Double(window.safeAreaInsets.left),
            bottom: Double(window.safeAreaInsets.bottom),
            right: Double(window.safeAreaInsets.right)
        ),
        rootViewControllerClass: window.rootViewController.map { NSStringFromClass(type(of: $0)) }
    )
}

@MainActor
private func currentRuntimeSnapshot(_ request: TKRuntimeSnapshotRequest) -> TKRuntimeSnapshotResponse {
    let capturedAt = currentStateTimestamp()
    let include = request.include.isEmpty ? ["app", "scene", "route", "ax", "geometry"] : request.include
    let requested = Set(include.map { $0.lowercased() })
    var artifacts: [TKRuntimeSnapshotArtifact] = []
    var skipped: [TKRuntimeSnapshotSkipped] = []
    var truncation = TKRuntimeSnapshotTruncation()

    func includes(_ name: String) -> Bool {
        requested.contains(name) || requested.contains("ui") && ["ax", "hierarchy"].contains(name)
    }
    func artifact(_ name: String) {
        artifacts.append(TKRuntimeSnapshotArtifact(name: name, capturedAt: capturedAt, freshness: "fresh"))
    }

    let app: TKRuntimeAppState?
    if includes("app") {
        app = currentAppState().app
        artifact("app")
    } else {
        app = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "app", reason: "not requested"))
    }

    let scene: TKRuntimeSceneStateResponse?
    if includes("scene") {
        scene = currentSceneState()
        artifact("scene")
    } else {
        scene = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "scene", reason: "not requested"))
    }

    let route: TKRuntimeRouteStateResponse?
    if includes("route") {
        route = currentRouteState()
        artifact("route")
    } else {
        route = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "route", reason: "not requested"))
    }

    let responder: TKRuntimeResponderStateResponse?
    if includes("responder") {
        responder = currentResponderState()
        artifact("responder")
    } else {
        responder = nil
    }

    let geometry: TKGeometryResponse?
    if includes("geometry") {
        geometry = currentGeometry()
        artifact("geometry")
    } else {
        geometry = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "geometry", reason: "not requested"))
    }

    let ax: [TKAXNode]?
    if includes("ax") || includes("accessibility") {
        let maxNodes = max(1, request.maxAXNodes ?? 800)
        var context = AXBuildContext(maxNodes: maxNodes)
        let nodes = keyWindows().map { window in
            buildAXWindowNode(for: window, context: &context)
        }
        ax = nodes
        if context.remaining == 0 {
            truncation = TKRuntimeSnapshotTruncation(
                truncated: true,
                reason: "maxAXNodes reached",
                originalCount: nil,
                returnedCount: maxNodes
            )
        }
        artifact("ax")
    } else {
        ax = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "ax", reason: "not requested"))
    }

    let screenshot: TKRuntimeScreenshotMetadata?
    if includes("screenshot-metadata") || includes("screenshot") {
        if let window = keyWindows().first {
            screenshot = TKRuntimeScreenshotMetadata(
                format: "png",
                width: Double(window.bounds.width),
                height: Double(window.bounds.height),
                scale: Double(window.screen.scale)
            )
            artifact("screenshot-metadata")
        } else {
            screenshot = nil
            skipped.append(TKRuntimeSnapshotSkipped(name: "screenshot-metadata", reason: "no key window"))
        }
    } else {
        screenshot = nil
    }

    return TKRuntimeSnapshotResponse(
        capturedAt: capturedAt,
        include: include,
        app: app,
        scene: scene,
        route: route,
        responder: responder,
        geometry: geometry,
        ax: ax,
        screenshot: screenshot,
        artifacts: artifacts,
        skipped: skipped,
        truncation: truncation
    )
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

private func controllerState(_ controller: UIViewController) -> TKRuntimeControllerState {
    TKRuntimeControllerState(
        className: NSStringFromClass(type(of: controller)),
        title: nonEmptyText(controller.title)
            ?? nonEmptyText(controller.navigationItem.title)
            ?? nonEmptyText(controller.tabBarItem.title),
        oid: oid(for: controller)
    )
}

private func visibleController(from controller: UIViewController?) -> UIViewController? {
    guard let controller else { return nil }
    if let presented = controller.presentedViewController {
        return visibleController(from: presented)
    }
    if let tab = controller as? UITabBarController {
        return visibleController(from: tab.selectedViewController) ?? tab
    }
    if let navigation = controller as? UINavigationController {
        return visibleController(from: navigation.topViewController) ?? navigation
    }
    if let split = controller as? UISplitViewController, let last = split.viewControllers.last {
        return visibleController(from: last) ?? split
    }
    if let page = controller as? UIPageViewController, let first = page.viewControllers?.first {
        return visibleController(from: first) ?? page
    }
    return controller
}

private func presentedControllerStack(from controller: UIViewController) -> [TKRuntimeControllerState] {
    var stack: [TKRuntimeControllerState] = []
    var current = controller.presentedViewController
    while let controller = current {
        stack.append(controllerState(controller))
        current = controller.presentedViewController
    }
    return stack
}

private func runtimeTabState(_ tabController: UITabBarController) -> TKRuntimeTabState {
    let tabs = (tabController.viewControllers ?? []).map { controller in
        nonEmptyText(controller.tabBarItem.title)
            ?? nonEmptyText(controller.title)
            ?? NSStringFromClass(type(of: controller))
    }
    let selectedTitle = tabController.selectedViewController.flatMap {
        nonEmptyText($0.tabBarItem.title) ?? nonEmptyText($0.title)
    }
    return TKRuntimeTabState(
        selectedIndex: tabController.selectedIndex,
        selectedTitle: selectedTitle,
        tabs: tabs
    )
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

private func textInputEditable(_ responder: UIResponder) -> Bool? {
    if let textField = responder as? UITextField {
        return textField.isEnabled
    }
    if let textView = responder as? UITextView {
        return textView.isEditable
    }
    if responder is UIKeyInput {
        return true
    }
    return nil
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
private func buildAXNode(for view: UIView, in window: UIWindow, children: [TKAXNode]) -> TKAXNode? {
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

private func shouldCollectAXChildren(from view: UIView) -> Bool {
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

private func shouldNestAXChildren(for view: UIView) -> Bool {
    view is UIScrollView && !(view is UITextView)
}

private func shouldEmitAXNode(_ node: TKAXNode, for view: UIView) -> Bool {
    if view is UIControl {
        return true
    }
    if view is UIScrollView, !(view is UITextView) {
        return hasAXSemantics(node) || !node.children.isEmpty
    }
    return hasAXSemantics(node)
}

private func hasAXSemantics(_ node: TKAXNode) -> Bool {
    nonEmptyText(node.label) != nil
        || nonEmptyText(node.value) != nil
        || nonEmptyText(node.identifier) != nil
        || nonEmptyText(node.title) != nil
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

private func value(for view: UIView) -> String? {
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

private func identifier(for view: UIView) -> String? {
    switch view {
    case is UIControl, is UILabel, is UITextView, is UIImageView, is UIScrollView:
        return nonEmptyText(view.accessibilityIdentifier)
    default:
        return nil
    }
}

private func title(for view: UIView) -> String? {
    if let button = view as? UIButton {
        return nonEmptyText(button.currentTitle) ?? nonEmptyText(button.currentAttributedTitle?.string)
    }
    return nil
}

private func nonEmptyText(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
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

private func interfaceOrientationName(_ orientation: UIInterfaceOrientation) -> String {
    switch orientation {
    case .portrait: return "portrait"
    case .portraitUpsideDown: return "portraitUpsideDown"
    case .landscapeLeft: return "landscapeLeft"
    case .landscapeRight: return "landscapeRight"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
}

private func activationStateName(_ state: UIScene.ActivationState) -> String {
    switch state {
    case .foregroundActive: return "foregroundActive"
    case .foregroundInactive: return "foregroundInactive"
    case .background: return "background"
    case .unattached: return "unattached"
    @unknown default: return "unknown"
    }
}

private func userInterfaceStyleName(_ style: UIUserInterfaceStyle) -> String {
    switch style {
    case .unspecified: return "unspecified"
    case .light: return "light"
    case .dark: return "dark"
    @unknown default: return "unknown"
    }
}

private func keyboardTypeName(_ type: UIKeyboardType) -> String {
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

private func returnKeyTypeName(_ type: UIReturnKeyType) -> String {
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

private func currentStateTimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

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
