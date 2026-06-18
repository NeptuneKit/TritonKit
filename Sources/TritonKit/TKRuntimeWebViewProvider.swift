import Foundation
import TritonKitShared

struct RuntimeWebViewSnapshotPayload: Decodable, Equatable {
    let text: [String]
    let dom: [TKWebViewDOMNodeSummary]
    let forms: [TKWebViewFormFieldSummary]
    let links: [TKWebViewLinkSummary]
    let truncation: TKWebViewSnapshotTruncation
    let redaction: TKWebViewRedaction
}

func decodeRuntimeWebViewSnapshotPayload(_ json: String) throws -> RuntimeWebViewSnapshotPayload {
    try JSONDecoder().decode(RuntimeWebViewSnapshotPayload.self, from: Data(json.utf8))
}

func runtimeWebViewSnapshotScript(include: [String], maxDOMNodes: Int?, maxTextBytes: Int?) throws -> String {
    let includeData = try JSONEncoder().encode(include)
    guard let includeLiteral = String(data: includeData, encoding: .utf8) else {
        throw NSError(domain: "TritonKit.WebViewSnapshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode snapshot include"])
    }
    let maxNodesLiteral = maxDOMNodes.map(String.init) ?? "80"
    let maxBytesLiteral = maxTextBytes.map(String.init) ?? "8192"
    return """
    (function() {
      var include = new Set(\(includeLiteral));
      var maxNodes = Math.max(0, \(maxNodesLiteral));
      var maxBytes = Math.max(0, \(maxBytesLiteral));
      var text = [];
      var dom = [];
      var forms = [];
      var links = [];
      var returnedBytes = 0;
      var truncated = false;
      var truncationReason = null;

      function clean(value) {
        return String(value || "").replace(/\\s+/g, " ").trim();
      }
      function appendText(value) {
        var cleaned = clean(value);
        if (!cleaned) { return; }
        var nextBytes = returnedBytes + cleaned.length;
        if (nextBytes > maxBytes) {
          truncated = true;
          truncationReason = truncationReason || "maxTextBytes";
          if (returnedBytes >= maxBytes) { return; }
          cleaned = cleaned.slice(0, Math.max(0, maxBytes - returnedBytes));
          nextBytes = maxBytes;
        }
        if (cleaned) {
          text.push(cleaned);
          returnedBytes = nextBytes;
        }
      }
      function frameFor(element) {
        try {
          var rect = element.getBoundingClientRect();
          return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
        } catch (_) {
          return null;
        }
      }
      function visible(element) {
        var rect = frameFor(element);
        if (!rect || rect.width <= 0 || rect.height <= 0) { return false; }
        var style = window.getComputedStyle ? window.getComputedStyle(element) : null;
        return !style || (style.visibility !== "hidden" && style.display !== "none" && style.opacity !== "0");
      }
      function roleFor(element, tag) {
        var explicit = element.getAttribute("role");
        if (explicit) { return explicit; }
        if (tag === "button") { return "button"; }
        if (tag === "a") { return "link"; }
        if (tag === "input" || tag === "textarea" || tag === "select") { return "form-field"; }
        if (/^h[1-6]$/.test(tag)) { return "heading"; }
        return null;
      }
      function labelFor(element) {
        var aria = element.getAttribute("aria-label");
        if (aria) { return clean(aria); }
        if (element.id) {
          var labels = Array.prototype.slice.call(document.getElementsByTagName("label"));
          for (var index = 0; index < labels.length; index += 1) {
            if (labels[index].getAttribute("for") === element.id) {
              return clean(labels[index].innerText || labels[index].textContent);
            }
          }
        }
        return null;
      }

      if (include.has("text")) {
        var bodyText = document.body ? document.body.innerText || document.body.textContent : "";
        clean(bodyText).split(/\\n+/).forEach(appendText);
      }

      var elements = Array.prototype.slice.call(document.querySelectorAll("body *"));
      for (var index = 0; index < elements.length; index += 1) {
        var element = elements[index];
        if (!visible(element)) { continue; }
        var tag = String(element.tagName || "").toLowerCase();
        var nodeText = clean(element.innerText || element.textContent || element.getAttribute("aria-label") || "");
        var frame = frameFor(element);

        if (include.has("dom") && dom.length < maxNodes) {
          dom.push({
            nodeID: element.id || ("dom-" + (index + 1)),
            role: roleFor(element, tag),
            tagName: tag || null,
            text: nodeText || null,
            frame: frame
          });
        } else if (include.has("dom") && dom.length >= maxNodes) {
          truncated = true;
          truncationReason = truncationReason || "maxDOMNodes";
        }

        if (include.has("forms") && (tag === "input" || tag === "textarea" || tag === "select") && forms.length < maxNodes) {
          var inputType = tag === "input" ? String(element.getAttribute("type") || "text").toLowerCase() : tag;
          var rawLength = element.value ? String(element.value).length : 0;
          forms.push({
            name: element.getAttribute("name") || element.id || null,
            inputType: inputType,
            label: labelFor(element),
            valueRedaction: "length-only",
            valueLength: rawLength,
            frame: frame
          });
        } else if (include.has("forms") && (tag === "input" || tag === "textarea" || tag === "select") && forms.length >= maxNodes) {
          truncated = true;
          truncationReason = truncationReason || "maxNodes";
        }

        if (include.has("links") && tag === "a" && links.length < maxNodes) {
          links.push({
            text: nodeText || null,
            href: element.href || element.getAttribute("href") || null,
            frame: frame
          });
        } else if (include.has("links") && tag === "a" && links.length >= maxNodes) {
          truncated = true;
          truncationReason = truncationReason || "maxNodes";
        }
      }

      return JSON.stringify({
        text: include.has("text") ? text : [],
        dom: include.has("dom") ? dom : [],
        forms: include.has("forms") ? forms : [],
        links: include.has("links") ? links : [],
        truncation: {
          truncated: truncated,
          reason: truncationReason,
          maxNodes: maxNodes,
          returnedNodes: dom.length + forms.length + links.length,
          maxBytes: maxBytes,
          returnedBytes: returnedBytes
        },
        redaction: { secureText: "length-only" }
      });
    })()
    """
}

func bridgeCallScript(method: String, arguments: [String: TKJSONValue]) throws -> String {
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
        return JSON.stringify({
          ok: false,
          error: {
            code: "webview_method_not_allowed",
            message: "Method is not allowlisted: " + method,
            hint: "Expose the method through window.__tritonBridge.methods or use triton webview snapshot --include metadata,text,dom,forms --json for linked validation."
          }
        });
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

func webViewFocusedTextInsertionScript(text: String) throws -> String {
    let textData = try JSONEncoder().encode(text)
    guard let textLiteral = String(data: textData, encoding: .utf8) else {
        throw NSError(domain: "TritonKit.WebViewInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode text"])
    }
    return """
    (function() {
      var text = \(textLiteral);
      var element = document.activeElement;
      if (!element) {
        return JSON.stringify({ ok: false, message: "No active DOM element" });
      }
      var tag = String(element.tagName || "").toLowerCase();
      var editable = !!element.isContentEditable;
      var supportsValue = tag === "input" || tag === "textarea";
      if (!editable && !supportsValue) {
        var candidates = Array.prototype.slice.call(document.querySelectorAll("input:not([type=hidden]):not([disabled]), textarea:not([disabled]), [contenteditable=true]"));
        element = null;
        for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex += 1) {
          var candidate = candidates[candidateIndex];
          var rect = candidate.getBoundingClientRect ? candidate.getBoundingClientRect() : null;
          var style = window.getComputedStyle ? window.getComputedStyle(candidate) : null;
          if (rect && rect.width > 0 && rect.height > 0 && (!style || (style.visibility !== "hidden" && style.display !== "none"))) {
            element = candidate;
            break;
          }
        }
        if (!element) {
          return JSON.stringify({
            ok: false,
            message: "No editable DOM element is focused or visible",
            tagName: tag || null
          });
        }
        if (typeof element.focus === "function") { element.focus(); }
        tag = String(element.tagName || "").toLowerCase();
        editable = !!element.isContentEditable;
        supportsValue = tag === "input" || tag === "textarea";
      }
      if (!editable && !supportsValue) {
        return JSON.stringify({
          ok: false,
          message: "Active DOM element is not text editable",
          tagName: tag || null
        });
      }
      try {
        if (supportsValue) {
          var oldValue = String(element.value || "");
          var start = typeof element.selectionStart === "number" ? element.selectionStart : oldValue.length;
          var end = typeof element.selectionEnd === "number" ? element.selectionEnd : start;
          var nextValue = oldValue.slice(0, start) + text + oldValue.slice(end);
          element.value = nextValue;
          var cursor = start + text.length;
          if (typeof element.setSelectionRange === "function") {
            element.setSelectionRange(cursor, cursor);
          }
          if (typeof InputEvent === "function") {
            element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
          } else {
            element.dispatchEvent(new Event("input", { bubbles: true }));
          }
          element.dispatchEvent(new Event("change", { bubbles: true }));
          return JSON.stringify({ ok: true, tagName: tag, insertedLength: text.length });
        }
        if (document.execCommand && document.execCommand("insertText", false, text)) {
          return JSON.stringify({ ok: true, tagName: tag || "contenteditable", insertedLength: text.length });
        }
        element.textContent = String(element.textContent || "") + text;
        element.dispatchEvent(new Event("input", { bubbles: true }));
        return JSON.stringify({ ok: true, tagName: tag || "contenteditable", insertedLength: text.length });
      } catch (error) {
        return JSON.stringify({
          ok: false,
          message: String(error && error.message ? error.message : error),
          tagName: tag || null
        });
      }
    })()
    """
}

func webViewFocusedDeleteBackwardScript() -> String {
    """
    (function() {
      var element = document.activeElement;
      if (!element) {
        return JSON.stringify({ ok: false, message: "No active DOM element" });
      }
      var tag = String(element.tagName || "").toLowerCase();
      var editable = !!element.isContentEditable;
      var supportsValue = tag === "input" || tag === "textarea";
      if (!editable && !supportsValue) {
        var candidates = Array.prototype.slice.call(document.querySelectorAll("input:not([type=hidden]):not([disabled]), textarea:not([disabled]), [contenteditable=true]"));
        element = null;
        for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex += 1) {
          var candidate = candidates[candidateIndex];
          var rect = candidate.getBoundingClientRect ? candidate.getBoundingClientRect() : null;
          var style = window.getComputedStyle ? window.getComputedStyle(candidate) : null;
          if (rect && rect.width > 0 && rect.height > 0 && (!style || (style.visibility !== "hidden" && style.display !== "none"))) {
            element = candidate;
            break;
          }
        }
        if (!element) {
          return JSON.stringify({
            ok: false,
            message: "No editable DOM element is focused or visible",
            tagName: tag || null
          });
        }
        if (typeof element.focus === "function") { element.focus(); }
        tag = String(element.tagName || "").toLowerCase();
        editable = !!element.isContentEditable;
        supportsValue = tag === "input" || tag === "textarea";
      }
      if (!editable && !supportsValue) {
        return JSON.stringify({
          ok: false,
          message: "Active DOM element is not text editable",
          tagName: tag || null
        });
      }
      try {
        if (supportsValue) {
          var oldValue = String(element.value || "");
          var start = typeof element.selectionStart === "number" ? element.selectionStart : oldValue.length;
          var end = typeof element.selectionEnd === "number" ? element.selectionEnd : start;
          var deletedLength = 0;
          var nextValue = oldValue;
          var cursor = start;
          if (start !== end) {
            deletedLength = Math.max(0, end - start);
            nextValue = oldValue.slice(0, start) + oldValue.slice(end);
          } else if (start > 0) {
            deletedLength = 1;
            cursor = start - 1;
            nextValue = oldValue.slice(0, cursor) + oldValue.slice(end);
          }
          element.value = nextValue;
          if (typeof element.setSelectionRange === "function") {
            element.setSelectionRange(cursor, cursor);
          }
          if (typeof InputEvent === "function") {
            element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "deleteContentBackward", data: null }));
          } else {
            element.dispatchEvent(new Event("input", { bubbles: true }));
          }
          element.dispatchEvent(new Event("change", { bubbles: true }));
          return JSON.stringify({ ok: true, tagName: tag, deletedLength: deletedLength });
        }
        if (document.execCommand && document.execCommand("delete", false, null)) {
          return JSON.stringify({ ok: true, tagName: tag || "contenteditable", deletedLength: 1 });
        }
        var text = String(element.textContent || "");
        if (!text) {
          return JSON.stringify({ ok: true, tagName: tag || "contenteditable", deletedLength: 0 });
        }
        element.textContent = text.slice(0, -1);
        element.dispatchEvent(new Event("input", { bubbles: true }));
        return JSON.stringify({ ok: true, tagName: tag || "contenteditable", deletedLength: 1 });
      } catch (error) {
        return JSON.stringify({
          ok: false,
          message: String(error && error.message ? error.message : error),
          tagName: tag || null
        });
      }
    })()
    """
}

struct WebViewFocusedTextInsertionPayload: Decodable, Equatable {
    let ok: Bool
    let message: String?
    let tagName: String?
    let insertedLength: Int?
    let deletedLength: Int?
}

func decodeWebViewFocusedTextInsertionPayload(_ json: String) throws -> WebViewFocusedTextInsertionPayload {
    try JSONDecoder().decode(WebViewFocusedTextInsertionPayload.self, from: Data(json.utf8))
}

#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit

private let runtimeWebViewEventStore = RuntimeWebViewEventStore(maxEntries: 100)
private let runtimeWebViewScriptBridge = RuntimeWebViewScriptBridge()
private let runtimeWebViewScriptBridgeInstall = RuntimeWebViewScriptBridgeInstall()

@MainActor
func performFocusedWebViewTextInsertionIfAvailable(
    responder: UIResponder,
    text: String,
    action: String,
    secure: Bool
) async -> TKInputResult? {
    let className = NSStringFromClass(type(of: responder))
    guard className.contains("WKContentView") else {
        return nil
    }
    let pairs = currentWKWebViewsWithDescriptors()
    let selected: TKWebViewDescriptor
    do {
        selected = try TKSelectCurrentWebView(from: pairs.map(\.descriptor))
    } catch {
        return TKInputResult.failure(
            action: action,
            message: "No current WKWebView available for focused WebView input",
            targetOID: oid(for: responder),
            targetClassName: className
        )
    }
    guard let pair = pairs.first(where: { $0.descriptor.webViewID == selected.webViewID }) else {
        return TKInputResult.failure(
            action: action,
            message: "No current WKWebView available for focused WebView input",
            targetOID: oid(for: responder),
            targetClassName: className
        )
    }
    do {
        let script = try webViewFocusedTextInsertionScript(text: text)
        let value = try await evaluateJavaScript(script, in: pair.webView)
        let json = value as? String ?? "\(value)"
        let payload = try decodeWebViewFocusedTextInsertionPayload(json)
        guard payload.ok else {
            return TKInputResult.failure(
                action: action,
                message: payload.message ?? "Focused WebView DOM input failed",
                targetOID: oid(for: responder),
                targetClassName: className
            )
        }
        return TKInputResult.success(
            action: action,
            message: secure ? "Inserted redacted WebView text" : "Inserted WebView text",
            targetOID: oid(for: responder),
            targetClassName: className,
            strategy: "webview-dom-active-element",
            secure: secure,
            redacted: secure,
            insertedLength: payload.insertedLength ?? text.count
        )
    } catch {
        return TKInputResult.failure(
            action: action,
            message: "Focused WebView DOM input failed: \(error)",
            targetOID: oid(for: responder),
            targetClassName: className
        )
    }
}

@MainActor
func performFocusedWebViewDeleteBackwardIfAvailable(
    responder: UIResponder,
    action: String
) async -> TKInputResult? {
    let className = NSStringFromClass(type(of: responder))
    guard className.contains("WKContentView") else {
        return nil
    }
    let pairs = currentWKWebViewsWithDescriptors()
    let selected: TKWebViewDescriptor
    do {
        selected = try TKSelectCurrentWebView(from: pairs.map(\.descriptor))
    } catch {
        return TKInputResult.failure(
            action: action,
            message: "No current WKWebView available for focused WebView input",
            targetOID: oid(for: responder),
            targetClassName: className
        )
    }
    guard let pair = pairs.first(where: { $0.descriptor.webViewID == selected.webViewID }) else {
        return TKInputResult.failure(
            action: action,
            message: "No current WKWebView available for focused WebView input",
            targetOID: oid(for: responder),
            targetClassName: className
        )
    }
    do {
        let value = try await evaluateJavaScript(webViewFocusedDeleteBackwardScript(), in: pair.webView)
        let json = value as? String ?? "\(value)"
        let payload = try decodeWebViewFocusedTextInsertionPayload(json)
        guard payload.ok else {
            return TKInputResult.failure(
                action: action,
                message: payload.message ?? "Focused WebView DOM delete failed",
                targetOID: oid(for: responder),
                targetClassName: className
            )
        }
        return TKInputResult.success(
            action: action,
            message: (payload.deletedLength ?? 0) > 0 ? "Deleted WebView text backward" : "No WebView text to delete",
            targetOID: oid(for: responder),
            targetClassName: className,
            strategy: "webview-dom-active-element",
            deletedLength: payload.deletedLength ?? 0
        )
    } catch {
        return TKInputResult.failure(
            action: action,
            message: "Focused WebView DOM delete failed: \(error)",
            targetOID: oid(for: responder),
            targetClassName: className
        )
    }
}

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
        note: "iOS WKWebView provider exposes metadata, bounded DOM/text/form/link snapshots, and focused activeElement text input. Bridge calls and page events require an opt-in page bridge."
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
func currentWebViewSnapshotResponse(_ request: TKWebViewSnapshotRequest) async throws -> TKWebViewSnapshotResponse {
    let pairs = currentWKWebViewsWithDescriptors()
    let selected = try TKSelectCurrentWebView(from: pairs.map(\.descriptor), webViewID: request.webViewID)
    guard let pair = pairs.first(where: { $0.descriptor.webViewID == selected.webViewID }) else {
        throw TKWebViewSelectionError(detail: TKWebViewError(
            code: .webviewNotFound,
            message: "Selected WebView is no longer available.",
            hint: "Run `triton webview current --json` again and retry."
        ))
    }
    if let requestedSession = request.pageSessionID,
       let actualSession = selected.pageSessionID,
       requestedSession != actualSession {
        throw TKWebViewSelectionError(detail: TKWebViewError(
            code: .webViewNavigationChanged,
            message: "WebView page session changed.",
            hint: "Run `triton webview current --json` and retry against the new pageSessionID.",
            webViewID: selected.webViewID
        ))
    }

    let script = try runtimeWebViewSnapshotScript(
        include: request.include,
        maxDOMNodes: request.maxDOMNodes,
        maxTextBytes: request.maxTextBytes
    )
    let value = try await evaluateJavaScript(script, in: pair.webView)
    let json = value as? String ?? "\(value)"
    let payload = try decodeRuntimeWebViewSnapshotPayload(json)
    let supported = Set(["metadata", "dom", "text", "forms", "links"])
    let skipped = request.include
        .filter { !supported.contains($0) }
        .map { TKRuntimeSnapshotSkipped(name: $0, reason: "Unsupported WebView snapshot include") }

    return TKWebViewSnapshotResponse(
        capturedAt: currentStateTimestamp(),
        platform: "ios",
        target: "embedded-runtime",
        webView: selected,
        include: request.include,
        text: payload.text,
        dom: payload.dom,
        forms: payload.forms,
        links: payload.links,
        skipped: skipped,
        truncation: payload.truncation,
        redaction: payload.redaction
    )
}

@MainActor
func currentWebViewWaitResponse(_ request: TKWebViewWaitRequest) async -> TKWebViewWaitResponse {
    let startedAt = Date()
    guard request.timeoutSeconds > 0, request.intervalSeconds > 0 else {
        return webViewWaitResponse(
            request: request,
            startedAt: startedAt,
            pollCount: 0,
            matched: false,
            timedOut: false,
            pageSessionID: request.pageSessionID,
            error: TKWebViewError(
                code: .webViewWaitUnsupported,
                message: "WebView wait timeout and interval must be greater than 0 seconds.",
                hint: "Pass positive --timeout and --interval values."
            )
        )
    }

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

        if request.condition == .event {
            installWebViewScriptBridgeIfNeeded(in: pair.webView, descriptor: selected)
        }

        let stablePageSessionID = request.pageSessionID ?? selected.pageSessionID
        let effectiveRequest = TKWebViewWaitRequest(
            webViewID: selected.webViewID,
            pageSessionID: stablePageSessionID,
            condition: request.condition,
            query: request.query,
            timeoutSeconds: request.timeoutSeconds,
            intervalSeconds: request.intervalSeconds,
            sourceCommand: request.sourceCommand
        )
        let deadline = startedAt.addingTimeInterval(request.timeoutSeconds)
        var pollCount = 0
        var lastEvaluation = TKWebViewWaitEvaluation(hit: false)

        while true {
            pollCount += 1
            do {
                let snapshot = try await currentWebViewSnapshotResponse(TKWebViewSnapshotRequest(
                    webViewID: selected.webViewID,
                    pageSessionID: stablePageSessionID,
                    include: ["metadata", "dom", "text"]
                ))
                let events = request.condition == .event ? currentWebViewEventsResponse(limit: 100) : nil
                let evaluation = TKEvaluateWebViewWait(
                    request: effectiveRequest,
                    snapshot: snapshot,
                    events: events
                )
                lastEvaluation = evaluation

                if let error = evaluation.error {
                    return webViewWaitResponse(
                        request: request,
                        startedAt: startedAt,
                        webView: snapshot.webView,
                        pollCount: pollCount,
                        matched: false,
                        timedOut: false,
                        pageSessionID: stablePageSessionID,
                        evaluation: evaluation,
                        error: error
                    )
                }
                if evaluation.hit {
                    return webViewWaitResponse(
                        request: request,
                        startedAt: startedAt,
                        webView: snapshot.webView,
                        pollCount: pollCount,
                        matched: true,
                        timedOut: false,
                        pageSessionID: stablePageSessionID,
                        evaluation: evaluation
                    )
                }
            } catch let error as TKWebViewSelectionError {
                return webViewWaitResponse(
                    request: request,
                    startedAt: startedAt,
                    webView: selected,
                    candidates: error.detail.candidates,
                    pollCount: pollCount,
                    matched: false,
                    timedOut: false,
                    pageSessionID: stablePageSessionID,
                    evaluation: lastEvaluation,
                    error: error.detail
                )
            } catch {
                return webViewWaitResponse(
                    request: request,
                    startedAt: startedAt,
                    webView: selected,
                    pollCount: pollCount,
                    matched: false,
                    timedOut: false,
                    pageSessionID: stablePageSessionID,
                    evaluation: lastEvaluation,
                    error: TKWebViewError(code: .javascriptError, message: "\(error)")
                )
            }

            let now = Date()
            if now >= deadline {
                return webViewWaitResponse(
                    request: request,
                    startedAt: startedAt,
                    webView: selected,
                    pollCount: pollCount,
                    matched: false,
                    timedOut: true,
                    pageSessionID: stablePageSessionID,
                    evaluation: lastEvaluation,
                    error: TKWebViewError(
                        code: .webViewWaitTimeout,
                        message: "Timed out waiting for WebView \(request.condition.rawValue) match.",
                        hint: "Inspect `lastObservedTextSample`, `lastObservedNodeIDs`, or `lastObservedEventNames` in the JSON response."
                    )
                )
            }

            let remaining = max(0, deadline.timeIntervalSince(now))
            let sleepSeconds = min(request.intervalSeconds, remaining)
            if sleepSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
            }
        }
    } catch let error as TKWebViewSelectionError {
        return webViewWaitResponse(
            request: request,
            startedAt: startedAt,
            candidates: error.detail.candidates,
            pollCount: 0,
            matched: false,
            timedOut: false,
            pageSessionID: request.pageSessionID,
            error: error.detail
        )
    } catch {
        return webViewWaitResponse(
            request: request,
            startedAt: startedAt,
            pollCount: 0,
            matched: false,
            timedOut: false,
            pageSessionID: request.pageSessionID,
            error: TKWebViewError(code: .webViewProviderUnavailable, message: "\(error)")
        )
    }
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

private func webViewWaitResponse(
    request: TKWebViewWaitRequest,
    startedAt: Date,
    webView: TKWebViewDescriptor? = nil,
    candidates: [TKWebViewDescriptor]? = nil,
    pollCount: Int,
    matched: Bool,
    timedOut: Bool,
    pageSessionID: String?,
    evaluation: TKWebViewWaitEvaluation = TKWebViewWaitEvaluation(hit: false),
    error: TKWebViewError? = nil
) -> TKWebViewWaitResponse {
    TKWebViewWaitResponse(
        ok: matched && error == nil,
        capturedAt: currentStateTimestamp(),
        platform: "ios",
        target: "embedded-runtime",
        webView: webView,
        candidates: candidates,
        condition: request.condition.rawValue,
        query: request.query,
        matched: matched,
        timedOut: timedOut,
        elapsedMs: elapsedMilliseconds(since: startedAt),
        pollCount: pollCount,
        timeoutSeconds: request.timeoutSeconds,
        intervalSeconds: request.intervalSeconds,
        pageSessionID: pageSessionID,
        lastObservedTextSample: evaluation.lastObservedTextSample,
        lastObservedNodeIDs: evaluation.lastObservedNodeIDs,
        lastObservedEventNames: evaluation.lastObservedEventNames,
        match: evaluation.match,
        error: error,
        redaction: TKWebViewRedaction(secureText: "length-only")
    )
}

func currentRuntimeManifestWithWebViewProvider(sdkVersion: String) -> TKRuntimeManifestResponse {
    return TKRuntimeManifestResponse.debugDefault(
        sdkVersion: sdkVersion,
        capabilities: currentRuntimeCapabilities(webViewProviderAvailable: true),
        semanticDomains: TritonKit.shared.semanticDomainManifests
    )
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
        bridgeStatus: "page-bridge-required",
        capabilities: ["visible", "webview.current", "webview.list", "webview.current-url", "webview.metadata", "webview.snapshot", "webview.dom", "webview.text", "webview.forms", "webview.links", "webview.wait", "webview.events", "webview.dom-input", "webview.contenteditable-typing", "webview.type"],
        missingCapabilities: ["webview.bridge-call", "webview.tap"],
        providerCapabilities: TKWebViewProviderCapabilities.iosRuntimeDefaults()
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
    return TKRuntimeManifestResponse.debugDefault(
        sdkVersion: sdkVersion,
        capabilities: currentRuntimeCapabilities(webViewProviderAvailable: false),
        semanticDomains: TritonKit.shared.semanticDomainManifests
    )
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
