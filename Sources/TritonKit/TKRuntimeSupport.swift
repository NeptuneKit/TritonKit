import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif
#if canImport(UIKit)
import UIKit
#endif

func classChain(for object: AnyObject) -> [String] {
        var chain: [String] = []
        var cls: AnyClass = type(of: object)
        while true {
            chain.append(NSStringFromClass(cls))
            guard let superCls = cls.superclass() else { break }
            cls = superCls
        }
        return chain
    }

let runtimeLedgerStore = RuntimeLedgerStore(maxEntries: 100)

final class RuntimeLedgerStore: @unchecked Sendable {
    let lock = NSLock()
    let maxEntries: Int
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

func recordRuntimeLedger(message: TKMessage, response: TKMessage?, elapsedMs: Int) {
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

func runtimeLedgerDetails(
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
    } else if message.type == .webViewBridgeCall,
              let payload = message.payload,
              let request = try? JSONDecoder().decode(TKWebViewBridgeCallRequest.self, from: payload) {
        source = request.sourceCommand ?? "cli"
        action = "webview.call"
    } else if message.type == .webViewTap,
              let payload = message.payload,
              let request = try? JSONDecoder().decode(TKWebViewTapRequest.self, from: payload) {
        source = request.sourceCommand ?? "cli"
        action = "webview.tap"
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
    if let webView = try? JSONDecoder().decode(TKWebViewBridgeCallResponse.self, from: payload) {
        return (
            source,
            webView.action,
            webView.ok,
            webView.error?.code.rawValue,
            webView.error?.message,
            redaction
        )
    }
    if let webViewTap = try? JSONDecoder().decode(TKWebViewTapResponse.self, from: payload) {
        return (
            source,
            webViewTap.action,
            webViewTap.ok,
            webViewTap.error?.code.rawValue,
            webViewTap.error?.message ?? webViewTap.note,
            redaction
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

func elapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1000))
}

func currentStateTimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

let runtimeCapabilityDisabledReason = "Capability disabled by app runtime configuration"

func runtimeCapabilityDisabledError(
    capability: TKRuntimeCapabilityName,
    action: String
) -> TKCLIErrorDetail {
    TKCLIErrorDetail(
        code: "capability_disabled",
        message: "\(action) is disabled by TritonKit runtime configuration.",
        hint: "Enable \(capability.rawValue) in TritonKit.shared.start { config in ... } before retrying.",
        nextAction: TKCLINextAction(command: "runtime", args: ["manifest", "--json"])
    )
}

func currentRuntimeCapabilities(
    webViewProviderAvailable: Bool
) -> [TKRuntimeCapabilityDetail] {
    TKRuntimeManifestResponse.defaultDebugCapabilities.map { capability in
        let resolved = resolveRuntimeCapabilitySupport(
            capability,
            hasSemanticProviders: TritonKit.shared.hasSemanticStateProviders,
            webViewProviderAvailable: webViewProviderAvailable
        )
        guard let name = TKRuntimeCapabilityName(rawValue: resolved.name) else {
            return resolved
        }
        let enabled = resolved.supported && TritonKit.shared.configuration.isRuntimeCapabilityEnabled(name)
        return TKRuntimeCapabilityDetail(
            name: resolved.name,
            supported: resolved.supported,
            enabled: enabled,
            scope: resolved.scope,
            boundary: resolved.boundary,
            reason: enabled ? resolved.reason : (resolved.supported ? runtimeCapabilityDisabledReason : resolved.reason),
            nextAction: resolved.nextAction
        )
    }
}

private func resolveRuntimeCapabilitySupport(
    _ capability: TKRuntimeCapabilityDetail,
    hasSemanticProviders: Bool,
    webViewProviderAvailable: Bool
) -> TKRuntimeCapabilityDetail {
    switch capability.name {
    case TKRuntimeCapabilityName.semanticState.rawValue,
         TKRuntimeCapabilityName.semanticActionProvider.rawValue:
        return TKRuntimeCapabilityDetail(
            name: capability.name,
            supported: hasSemanticProviders,
            scope: TKRuntimeCapabilityScope.optInProvider.rawValue,
            boundary: TKRuntimeCapabilityBoundary.businessOptIn.rawValue,
            reason: hasSemanticProviders ? nil : capability.reason,
            nextAction: capability.nextAction
        )
    case TKRuntimeCapabilityName.webViewList.rawValue,
         TKRuntimeCapabilityName.webViewCurrent.rawValue,
         TKRuntimeCapabilityName.webViewSnapshot.rawValue,
         TKRuntimeCapabilityName.webViewTap.rawValue,
         TKRuntimeCapabilityName.webViewWait.rawValue,
         TKRuntimeCapabilityName.webViewEvents.rawValue where webViewProviderAvailable:
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

// MARK: - Response Payloads

struct PingResponse: Codable {
    let pong: Bool
    let timestamp: TimeInterval
}

struct InvokeResult: Codable {
    let result: String
}

struct ModifyResult: Codable {
    let success: Bool
}
