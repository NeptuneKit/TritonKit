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
            let manifest = currentRuntimeManifestWithWebViewProvider(sdkVersion: "0.1.0-dev")
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

        case .webViewList:
            #if canImport(UIKit) && canImport(WebKit)
            let response = await MainActor.run { currentWebViewListResponse() }
            return TKMessage(id: msg.id, type: .webViewList, payload: try? JSONEncoder().encode(response))
            #else
            return webViewErrorMessage(id: msg.id, type: .webViewList, action: "webview.list", code: .webViewProviderUnavailable, message: "WebView provider is not available in this runtime.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView provider.")
            #endif

        case .webViewCurrent:
            let request = msg.payload.flatMap { try? JSONDecoder().decode(TKWebViewSnapshotRequest.self, from: $0) }
            #if canImport(UIKit) && canImport(WebKit)
            do {
                let response = try await MainActor.run { try currentWebViewCurrentResponse(webViewID: request?.webViewID) }
                return TKMessage(id: msg.id, type: .webViewCurrent, payload: try? JSONEncoder().encode(response))
            } catch let error as TKWebViewSelectionError {
                return webViewErrorMessage(id: msg.id, type: .webViewCurrent, action: "webview.current", code: error.detail.code, message: error.detail.message, hint: error.detail.hint, candidates: error.detail.candidates)
            } catch {
                return webViewErrorMessage(id: msg.id, type: .webViewCurrent, action: "webview.current", code: .webViewProviderUnavailable, message: "\(error)", hint: "Run `triton webview list --json` to inspect available WebView candidates.")
            }
            #else
            return webViewErrorMessage(id: msg.id, type: .webViewCurrent, action: "webview.current", code: .webViewProviderUnavailable, message: "WebView provider is not available in this runtime.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView provider.")
            #endif

        case .webViewSnapshot:
            let request = msg.payload.flatMap { try? JSONDecoder().decode(TKWebViewSnapshotRequest.self, from: $0) } ?? TKWebViewSnapshotRequest()
            #if canImport(UIKit) && canImport(WebKit)
            do {
                let response = try await currentWebViewSnapshotResponse(request)
                return TKMessage(id: msg.id, type: .webViewSnapshot, payload: try? JSONEncoder().encode(response))
            } catch let error as TKWebViewSelectionError {
                return webViewErrorMessage(id: msg.id, type: .webViewSnapshot, action: "webview.snapshot", code: error.detail.code, message: error.detail.message, hint: error.detail.hint, candidates: error.detail.candidates)
            } catch {
                return webViewErrorMessage(id: msg.id, type: .webViewSnapshot, action: "webview.snapshot", code: .javascriptError, message: "\(error)", hint: "Reduce --include or --max-dom-nodes and retry with `triton webview current --json` metadata.")
            }
            #else
            return webViewErrorMessage(id: msg.id, type: .webViewSnapshot, action: "webview.snapshot", code: .webViewProviderUnavailable, message: "WebView snapshot provider is not registered.", hint: "Register an opt-in WebView provider before requesting DOM, text, forms, or links.")
            #endif

        case .webViewBridgeCall:
            guard let data = msg.payload,
                  let request = try? JSONDecoder().decode(TKWebViewBridgeCallRequest.self, from: data) else {
                return webViewErrorMessage(id: msg.id, type: .webViewBridgeCall, action: "webview.call", code: .javascriptError, message: "Missing or invalid WebView bridge call payload.", hint: "Pass a method and JSON-serializable arguments.")
            }
            #if canImport(UIKit) && canImport(WebKit)
            let result = await performWebViewBridgeCall(request)
            return TKMessage(id: msg.id, type: .webViewBridgeCall, payload: try? JSONEncoder().encode(result))
            #else
            return webViewErrorMessage(id: msg.id, type: .webViewBridgeCall, action: "webview.call", code: .webViewBridgeUnavailable, message: "WebView bridge is not available.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView bridge provider.")
            #endif

        case .webViewEvents:
            let limit = msg.payload
                .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) }?["limit"] ?? 50
            #if canImport(UIKit) && canImport(WebKit)
            let response = currentWebViewEventsResponse(limit: limit)
            return TKMessage(id: msg.id, type: .webViewEvents, payload: try? JSONEncoder().encode(response))
            #else
            return webViewErrorMessage(id: msg.id, type: .webViewEvents, action: "webview.events", code: .webViewBridgeUnavailable, message: "WebView events are not available.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView event provider.")
            #endif

        case .webViewBridgePost, .webViewWait, .webViewLedger:
            return webViewErrorMessage(id: msg.id, type: msg.type, action: msg.type.rawValue, code: .webViewBridgeUnavailable, message: "WebView bridge is not available.", hint: "Expose an opt-in page bridge allowlist before calling methods, posting events, waiting on events, or reading event buffers.")

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

    private func webViewErrorMessage(
        id: Int,
        type: TKRequestType,
        action: String,
        code: TKWebViewErrorCode,
        message: String,
        hint: String?,
        candidates: [TKWebViewDescriptor]? = nil
    ) -> TKMessage {
        let response = TKWebViewErrorResponse(
            action: action,
            platform: "ios",
            target: "embedded-runtime",
            error: TKCLIErrorDetail(code: code.rawValue, message: message, hint: hint),
            candidates: candidates
        )
        return TKMessage(id: id, type: type, payload: try? JSONEncoder().encode(response))
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
}
