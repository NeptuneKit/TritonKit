import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

func runtimeUIHealthErrorResponse(_ message: TKMessage, code: String, health: TKRuntimeUIHealthSnapshot) -> TKMessage {
    let timedOut = code == "runtime_ui_timeout"
    let description: String
    switch code {
    case "runtime_ui_timeout": description = "The UI request exceeded its deadline; its execution outcome is unknown and work may still be running."
    case "runtime_ui_circuit_open": description = "The UI circuit is open after repeated timeouts; this request was not dispatched."
    default: description = "Another UI request still owns admission; this request was not dispatched."
    }
    let error = TKCLIErrorDetail(code: code, message: description, hint: "Probe runtime ping for UI health. Do not automatically replay a timed-out action; explicitly recover the runtime and observe the app state first.")
    let outcome = timedOut ? "unknown" : "not_started"
    let payload: Data?
    switch message.type {
    case .input:
        let request = message.payload.flatMap { try? JSONDecoder().decode(TKInputRequest.self, from: $0) }
        payload = try? JSONEncoder().encode(TKInputResult.failure(action: request?.type.rawValue ?? "input", message: description, error: error, outcome: outcome, uiHealth: health))
    case .semanticAction:
        let request = message.payload.flatMap { try? JSONDecoder().decode(TKSemanticActionRequest.self, from: $0) }
        payload = try? JSONEncoder().encode(TKSemanticActionResponse(ok: false, action: request?.action ?? .focus, strategy: "runtime-ui-health", elapsedMs: timedOut ? health.timeoutMilliseconds : 0, message: description, error: error, outcome: outcome, uiHealth: health))
    case .webViewList, .webViewCurrent, .webViewSnapshot, .webViewBridgeCall, .webViewBridgePost, .webViewTap, .webViewWait, .webViewFocus, .webViewFormInput, .webViewEvents, .webViewLedger:
        payload = try? JSONEncoder().encode(TKWebViewErrorResponse(action: TKRuntimeCapabilityGate.actionName(for: message), platform: "ios", target: "embedded-runtime", error: error, outcome: outcome, uiHealth: health))
    default:
        payload = try? JSONEncoder().encode(TKRuntimeUIHealthErrorResponse(error: error, outcome: outcome, uiHealth: health))
    }
    // No request payload, UI text, or screenshot is copied into these diagnostics.
    return TKMessage(id: message.id, type: message.type, payload: payload)
}
