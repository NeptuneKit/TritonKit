import Foundation
import TritonKitShared

extension TritonKitRequestHandler {
    func handleWebView(_ message: TKMessage) async -> TKMessage? {
        switch message.type {
        case .webViewList:
            #if canImport(UIKit) && canImport(WebKit)
            let response = await MainActor.run { currentWebViewListResponse() }
            return TKMessage(id: message.id, type: .webViewList, payload: try? JSONEncoder().encode(response))
            #else
            return webViewErrorMessage(id: message.id, type: .webViewList, action: "webview.list", code: .webViewProviderUnavailable, message: "WebView provider is not available in this runtime.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView provider.")
            #endif

        case .webViewCurrent:
            let request = message.payload.flatMap { try? JSONDecoder().decode(TKWebViewSnapshotRequest.self, from: $0) }
            #if canImport(UIKit) && canImport(WebKit)
            do {
                let response = try await MainActor.run { try currentWebViewCurrentResponse(webViewID: request?.webViewID) }
                return TKMessage(id: message.id, type: .webViewCurrent, payload: try? JSONEncoder().encode(response))
            } catch let error as TKWebViewSelectionError {
                return webViewErrorMessage(id: message.id, type: .webViewCurrent, action: "webview.current", code: error.detail.code, message: error.detail.message, hint: error.detail.hint, candidates: error.detail.candidates)
            } catch {
                return webViewErrorMessage(id: message.id, type: .webViewCurrent, action: "webview.current", code: .webViewProviderUnavailable, message: "\(error)", hint: "Run `triton webview list --json` to inspect available WebView candidates.")
            }
            #else
            return webViewErrorMessage(id: message.id, type: .webViewCurrent, action: "webview.current", code: .webViewProviderUnavailable, message: "WebView provider is not available in this runtime.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView provider.")
            #endif

        case .webViewSnapshot:
            let request = message.payload.flatMap { try? JSONDecoder().decode(TKWebViewSnapshotRequest.self, from: $0) } ?? TKWebViewSnapshotRequest()
            #if canImport(UIKit) && canImport(WebKit)
            do {
                let response = try await currentWebViewSnapshotResponse(request)
                return TKMessage(id: message.id, type: .webViewSnapshot, payload: try? JSONEncoder().encode(response))
            } catch let error as TKWebViewSelectionError {
                return webViewErrorMessage(id: message.id, type: .webViewSnapshot, action: "webview.snapshot", code: error.detail.code, message: error.detail.message, hint: error.detail.hint, candidates: error.detail.candidates)
            } catch {
                return webViewErrorMessage(id: message.id, type: .webViewSnapshot, action: "webview.snapshot", code: .javascriptError, message: "\(error)", hint: "Reduce --include or --max-dom-nodes and retry with `triton webview current --json` metadata.")
            }
            #else
            return webViewErrorMessage(id: message.id, type: .webViewSnapshot, action: "webview.snapshot", code: .webViewProviderUnavailable, message: "WebView snapshot provider is not registered.", hint: "Register an opt-in WebView provider before requesting DOM, text, forms, or links.")
            #endif

        case .webViewBridgeCall:
            guard let data = message.payload,
                  let request = try? JSONDecoder().decode(TKWebViewBridgeCallRequest.self, from: data) else {
                return webViewErrorMessage(id: message.id, type: .webViewBridgeCall, action: "webview.call", code: .javascriptError, message: "Missing or invalid WebView bridge call payload.", hint: "Pass a method and JSON-serializable arguments.")
            }
            #if canImport(UIKit) && canImport(WebKit)
            let result = await performWebViewBridgeCall(request)
            return TKMessage(id: message.id, type: .webViewBridgeCall, payload: try? JSONEncoder().encode(result))
            #else
            return webViewErrorMessage(id: message.id, type: .webViewBridgeCall, action: "webview.call", code: .webViewBridgeUnavailable, message: "WebView bridge is not available.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView bridge provider.")
            #endif

        case .webViewEvents:
            let limit = message.payload
                .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) }?["limit"] ?? 50
            #if canImport(UIKit) && canImport(WebKit)
            let response = currentWebViewEventsResponse(limit: limit)
            return TKMessage(id: message.id, type: .webViewEvents, payload: try? JSONEncoder().encode(response))
            #else
            return webViewErrorMessage(id: message.id, type: .webViewEvents, action: "webview.events", code: .webViewBridgeUnavailable, message: "WebView events are not available.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView event provider.")
            #endif

        case .webViewWait:
            guard let data = message.payload,
                  let request = try? JSONDecoder().decode(TKWebViewWaitRequest.self, from: data) else {
                return webViewErrorMessage(id: message.id, type: .webViewWait, action: "webview.wait", code: .webViewWaitUnsupported, message: "Missing or invalid WebView wait payload.", hint: "Pass one wait condition and query.")
            }
            #if canImport(UIKit) && canImport(WebKit)
            let result = await currentWebViewWaitResponse(request)
            return TKMessage(id: message.id, type: .webViewWait, payload: try? JSONEncoder().encode(result))
            #else
            return webViewErrorMessage(id: message.id, type: .webViewWait, action: "webview.wait", code: .webViewWaitUnsupported, message: "WebView wait is not available in this runtime.", hint: "Use an iOS DEBUG runtime with WebKit support or register a Harmony WebView wait provider.")
            #endif

        case .webViewBridgePost, .webViewLedger:
            return webViewErrorMessage(id: message.id, type: message.type, action: message.type.rawValue, code: .webViewBridgeUnavailable, message: "WebView bridge is not available.", hint: "Expose an opt-in page bridge allowlist before calling methods, posting events, waiting on events, or reading event buffers.")

        default:
            return unsupportedMessage(message)
        }
    }

    func webViewErrorMessage(
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
}
