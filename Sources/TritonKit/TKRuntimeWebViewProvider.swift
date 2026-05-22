import Foundation
import TritonKitShared

#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit

private let runtimeWebViewEventStore = RuntimeWebViewEventStore(maxEntries: 100)
private let runtimeWebViewScriptBridge = RuntimeWebViewScriptBridge()
private let runtimeWebViewScriptBridgeInstall = RuntimeWebViewScriptBridgeInstall()

@MainActor
func currentWebViewListResponse(action: String = "webview.list") -> TKWebViewListResponse {
    let candidates = currentWKWebViewsWithDescriptors().map(\.descriptor)
    return TKWebViewListResponse(
        ok: true,
        action: action,
        platform: "ios",
        capturedAt: currentStateTimestamp(),
        target: "embedded-runtime",
        current: try? TKSelectCurrentWebView(from: candidates),
        candidates: candidates,
        sources: [
            TKWebViewSource(name: "runtime-tree", available: true, sourceCommands: ["triton runtimeSnapshot request"]),
            TKWebViewSource(name: "webview-provider", available: true, sourceCommands: ["triton webViewList request"]),
        ],
        sourceCommands: ["triton webViewList request"],
        note: "iOS WKWebView provider exposes metadata only. DOM, bridge calls, DOM input, and page events require an opt-in page bridge."
    )
}

@MainActor
func currentWebViewCurrentResponse(webViewID: String? = nil) throws -> TKWebViewCurrentResponse {
    let list = currentWebViewListResponse(action: "webview.current")
    let selected = try TKSelectCurrentWebView(from: list.candidates, webViewID: webViewID)
    return TKWebViewCurrentResponse(
        ok: true,
        action: "webview.current",
        platform: list.platform,
        capturedAt: list.capturedAt,
        target: list.target,
        webView: selected,
        sources: list.sources,
        sourceCommands: list.sourceCommands,
        note: list.note
    )
}

@MainActor
func performWebViewBridgeCall(_ request: TKWebViewBridgeCallRequest) async -> TKWebViewBridgeCallResponse {
    let startedAt = Date()
    let pairs = currentWKWebViewsWithDescriptors()
    do {
        let selected = try TKSelectCurrentWebView(from: pairs.map(\.descriptor), webViewID: request.webViewID)
        guard let pair = pairs.first(where: { $0.descriptor.webViewID == selected.webViewID }) else {
            throw TKWebViewSelectionError(detail: TKWebViewError(
                code: .webviewNotFound,
                message: "Selected WebView is no longer available.",
                hint: "Run `triton webview current --json` again and retry."
            ))
        }
        installWebViewScriptBridgeIfNeeded(in: pair.webView, descriptor: selected)
        if let requestedSession = request.pageSessionID,
           let actualSession = selected.pageSessionID,
           requestedSession != actualSession {
            return TKWebViewBridgeCallResponse(
                ok: false,
                capturedAt: currentStateTimestamp(),
                platform: "ios",
                target: "embedded-runtime",
                webViewID: selected.webViewID,
                pageSessionID: actualSession,
                method: request.method,
                error: TKWebViewError(
                    code: .webViewNavigationChanged,
                    message: "WebView page session changed.",
                    hint: "Run `triton webview current --json` and retry against the new pageSessionID."
                ),
                elapsedMs: elapsedMilliseconds(since: startedAt)
            )
        }
        return await evaluateBridgeCall(request, in: pair.webView, descriptor: selected, startedAt: startedAt)
    } catch let error as TKWebViewSelectionError {
        return TKWebViewBridgeCallResponse(
            ok: false,
            capturedAt: currentStateTimestamp(),
            platform: "ios",
            target: "embedded-runtime",
            webViewID: request.webViewID ?? "",
            pageSessionID: request.pageSessionID,
            method: request.method,
            error: error.detail,
            elapsedMs: elapsedMilliseconds(since: startedAt)
        )
    } catch {
        return TKWebViewBridgeCallResponse(
            ok: false,
            capturedAt: currentStateTimestamp(),
            platform: "ios",
            target: "embedded-runtime",
            webViewID: request.webViewID ?? "",
            pageSessionID: request.pageSessionID,
            method: request.method,
            error: TKWebViewError(code: .javascriptError, message: "\(error)"),
            elapsedMs: elapsedMilliseconds(since: startedAt)
        )
    }
}

func currentWebViewEventsResponse(limit: Int = 50) -> TKWebViewEventsResponse {
    TKWebViewEventsResponse(
        capturedAt: currentStateTimestamp(),
        platform: "ios",
        target: "embedded-runtime",
        events: runtimeWebViewEventStore.events(limit: limit),
        limit: limit
    )
}

func currentRuntimeManifestWithWebViewProvider(sdkVersion: String) -> TKRuntimeManifestResponse {
    let capabilities = TKRuntimeManifestResponse.defaultDebugCapabilities.map { capability in
        switch capability.name {
        case TKRuntimeCapabilityName.webViewList.rawValue,
             TKRuntimeCapabilityName.webViewCurrent.rawValue:
            return TKRuntimeCapabilityDetail(
                name: capability.name,
                supported: true,
                scope: TKRuntimeCapabilityScope.embedded.rawValue,
                boundary: TKRuntimeCapabilityBoundary.appProcess.rawValue
            )
        default:
            return capability
        }
    }
    return TKRuntimeManifestResponse.debugDefault(sdkVersion: sdkVersion, capabilities: capabilities)
}

@MainActor
private func currentWKWebViewsWithDescriptors() -> [(webView: WKWebView, descriptor: TKWebViewDescriptor)] {
    allRuntimeWindows()
        .filter { !$0.isHidden && $0.alpha > 0.01 }
        .flatMap { window in
            flattenViews(in: window).compactMap { view -> (WKWebView, TKWebViewDescriptor)? in
                guard let webView = view as? WKWebView else { return nil }
                guard isAXVisible(webView), webView.window != nil else { return nil }
                return (webView, webViewDescriptor(for: webView))
            }
        }
        .sorted { TKWebViewDescriptorSort($0.descriptor, $1.descriptor) }
}

@MainActor
private func webViewDescriptor(for webView: WKWebView) -> TKWebViewDescriptor {
    let oid = TKObjectRegistry.shared.register(webView)
    let webViewID = "ios-webkit:\(oid)"
    return TKWebViewDescriptor(
        webViewID: webViewID,
        platform: "ios",
        source: "webview-provider",
        nodeID: webViewID,
        role: "webview",
        text: webView.title,
        identifier: webView.accessibilityIdentifier,
        frame: tkRect(webView.convert(webView.bounds, to: nil)),
        visibleRatio: 1,
        candidateOnly: false,
        confidence: 1,
        url: webView.url?.absoluteString,
        title: webView.title,
        pageSessionID: webViewPageSessionID(webView, oid: oid),
        isLoading: webView.isLoading,
        estimatedProgress: webView.estimatedProgress,
        canGoBack: webView.canGoBack,
        canGoForward: webView.canGoForward,
        providerStatus: "available",
        bridgeStatus: "unavailable",
        capabilities: ["visible", "webview.current", "webview.list", "webview.metadata"],
        missingCapabilities: ["webview.dom", "webview.bridge-call", "webview.events", "webview.tap", "webview.type"]
    )
}

@MainActor
private func installWebViewScriptBridgeIfNeeded(in webView: WKWebView, descriptor: TKWebViewDescriptor) {
    runtimeWebViewScriptBridge.bind(webViewID: descriptor.webViewID, pageSessionID: descriptor.pageSessionID)
    if runtimeWebViewScriptBridgeInstall.markInstalled(webView.configuration.userContentController) {
        webView.configuration.userContentController.add(runtimeWebViewScriptBridge, name: "triton")
    }
}

private func flattenViews(in root: UIView) -> [UIView] {
    [root] + root.subviews.flatMap(flattenViews)
}

private func webViewPageSessionID(_ webView: WKWebView, oid: UInt) -> String {
    let pageKey = webView.url?.absoluteString ?? webView.title ?? "empty"
    return "ios-webkit:\(oid):page:\(abs(pageKey.hashValue))"
}

@MainActor
private func evaluateBridgeCall(
    _ request: TKWebViewBridgeCallRequest,
    in webView: WKWebView,
    descriptor: TKWebViewDescriptor,
    startedAt: Date
) async -> TKWebViewBridgeCallResponse {
    do {
        let script = try bridgeCallScript(method: request.method, arguments: request.arguments)
        let value = try await evaluateJavaScript(script, in: webView)
        let json = value as? String ?? "\(value)"
        let envelope = try decodeBridgeEnvelope(json)
        if envelope.ok {
            return TKWebViewBridgeCallResponse(
                capturedAt: currentStateTimestamp(),
                platform: "ios",
                target: "embedded-runtime",
                webViewID: descriptor.webViewID,
                pageSessionID: descriptor.pageSessionID,
                method: request.method,
                result: envelope.result,
                elapsedMs: elapsedMilliseconds(since: startedAt),
                redaction: TKWebViewRedaction()
            )
        }
        return TKWebViewBridgeCallResponse(
            ok: false,
            capturedAt: currentStateTimestamp(),
            platform: "ios",
            target: "embedded-runtime",
            webViewID: descriptor.webViewID,
            pageSessionID: descriptor.pageSessionID,
            method: request.method,
            error: envelope.error ?? TKWebViewError(code: .javascriptError, message: "Bridge call failed."),
            elapsedMs: elapsedMilliseconds(since: startedAt),
            redaction: TKWebViewRedaction()
        )
    } catch {
        return TKWebViewBridgeCallResponse(
            ok: false,
            capturedAt: currentStateTimestamp(),
            platform: "ios",
            target: "embedded-runtime",
            webViewID: descriptor.webViewID,
            pageSessionID: descriptor.pageSessionID,
            method: request.method,
            error: TKWebViewError(code: .javascriptError, message: "\(error)"),
            elapsedMs: elapsedMilliseconds(since: startedAt),
            redaction: TKWebViewRedaction()
        )
    }
}

@MainActor
private func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> Any {
    try await withCheckedThrowingContinuation { continuation in
        webView.evaluateJavaScript(script) { result, error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: result ?? "")
            }
        }
    }
}

private func bridgeCallScript(method: String, arguments: [String: TKJSONValue]) throws -> String {
    let methodData = try JSONEncoder().encode(method)
    let argumentsData = try JSONEncoder().encode(arguments)
    guard let methodLiteral = String(data: methodData, encoding: .utf8),
          let argumentsLiteral = String(data: argumentsData, encoding: .utf8) else {
        throw NSError(domain: "TritonKit.WebViewBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode bridge call"])
    }
    return """
    (function() {
      var method = \(methodLiteral);
      var args = \(argumentsLiteral);
      var bridge = window.__tritonBridge;
      if (!bridge || !bridge.methods || typeof bridge.methods[method] !== "function") {
        return JSON.stringify({ ok: false, error: { code: "webview_method_not_allowed", message: "Method is not allowlisted: " + method } });
      }
      try {
        var result = bridge.methods[method](args);
        if (result === undefined) { result = null; }
        return JSON.stringify({ ok: true, result: result });
      } catch (error) {
        return JSON.stringify({ ok: false, error: { code: "javascript_error", message: String(error && error.message ? error.message : error) } });
      }
    })()
    """
}

private struct BridgeEnvelope: Decodable {
    let ok: Bool
    let result: TKJSONValue?
    let error: TKWebViewError?
}

private func decodeBridgeEnvelope(_ json: String) throws -> BridgeEnvelope {
    let data = Data(json.utf8)
    return try JSONDecoder().decode(BridgeEnvelope.self, from: data)
}

private final class RuntimeWebViewEventStore: @unchecked Sendable {
    private let lock = NSLock()
    private let maxEntries: Int
    private var nextID = 1
    private var entries: [TKWebViewEvent] = []

    init(maxEntries: Int) {
        self.maxEntries = maxEntries
    }

    func append(name: String, payload: TKJSONValue?, webViewID: String, pageSessionID: String?) {
        lock.withLock {
            let event = TKWebViewEvent(
                id: "webview-event-\(nextID)",
                timestamp: currentStateTimestamp(),
                webViewID: webViewID,
                pageSessionID: pageSessionID,
                name: name,
                payload: payload,
                redaction: TKWebViewRedaction(),
                source: "page-bridge"
            )
            nextID += 1
            entries.append(event)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
        }
    }

    func events(limit: Int) -> [TKWebViewEvent] {
        let bounded = max(0, min(limit, maxEntries))
        return lock.withLock { Array(entries.suffix(bounded)) }
    }
}

private final class RuntimeWebViewScriptBridge: NSObject, WKScriptMessageHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var webViewID = "unknown"
    private var pageSessionID: String?

    func bind(webViewID: String, pageSessionID: String?) {
        lock.withLock {
            self.webViewID = webViewID
            self.pageSessionID = pageSessionID
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let identity = lock.withLock { (webViewID, pageSessionID) }
        guard let body = message.body as? [String: Any] else {
            runtimeWebViewEventStore.append(
                name: "message",
                payload: try? TKJSONValue.fromJSONObject(message.body),
                webViewID: identity.0,
                pageSessionID: identity.1
            )
            return
        }
        let name = body["name"] as? String ?? body["type"] as? String ?? "message"
        let payload = body["payload"].flatMap { try? TKJSONValue.fromJSONObject($0) }
        runtimeWebViewEventStore.append(name: name, payload: payload, webViewID: identity.0, pageSessionID: identity.1)
    }
}

private final class RuntimeWebViewScriptBridgeInstall: @unchecked Sendable {
    private let lock = NSLock()
    private var installed: Set<ObjectIdentifier> = []

    func markInstalled(_ controller: WKUserContentController) -> Bool {
        lock.withLock {
            let id = ObjectIdentifier(controller)
            guard !installed.contains(id) else { return false }
            installed.insert(id)
            return true
        }
    }
}

#else

func currentRuntimeManifestWithWebViewProvider(sdkVersion: String) -> TKRuntimeManifestResponse {
    TKRuntimeManifestResponse.debugDefault(sdkVersion: sdkVersion)
}

func currentWebViewEventsResponse(limit: Int = 50) -> TKWebViewEventsResponse {
    TKWebViewEventsResponse(
        ok: false,
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        platform: "ios",
        target: "embedded-runtime",
        events: [],
        limit: limit
    )
}

#endif
