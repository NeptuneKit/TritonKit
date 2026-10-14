import Foundation

public enum TKActTapStatus: String, Codable, Equatable {
    case passed
    case failed
    case uncertain
}

public struct TKActTapAttempt: Codable, Equatable {
    public let method: String
    public let dispatched: Bool?
    public let trusted: Bool?
    public let performed: Bool?
    public let source: String?

    public init(method: String, dispatched: Bool? = nil, trusted: Bool? = nil, performed: Bool? = nil, source: String? = nil) {
        self.method = method
        self.dispatched = dispatched
        self.trusted = trusted
        self.performed = performed
        self.source = source
    }
}

public struct TKActTapVerification: Codable, Equatable {
    public let expectProvided: Bool
    public let expectText: String?
    public let textMatched: Bool?
    public let urlChanged: Bool?
    public let eventObserved: Bool?
    public let domChanged: Bool?

    public init(
        expectProvided: Bool,
        expectText: String? = nil,
        textMatched: Bool? = nil,
        urlChanged: Bool? = nil,
        eventObserved: Bool? = nil,
        domChanged: Bool? = nil
    ) {
        self.expectProvided = expectProvided
        self.expectText = expectText
        self.textMatched = textMatched
        self.urlChanged = urlChanged
        self.eventObserved = eventObserved
        self.domChanged = domChanged
    }
}

public struct TKActTapWebViewAwareResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let status: TKActTapStatus
    public let context: String
    public let query: String?
    public let selector: String?
    public let target: TKWebViewTapTarget?
    public let attempts: [TKActTapAttempt]
    public let verification: TKActTapVerification
    public let recoveryCommand: String?
    public let sourceCommands: [String]
    public let note: String
    public let error: TKWebViewError?
    public let outcome: String?
    public let uiHealth: TKRuntimeUIHealthSnapshot?

    public init(
        ok: Bool,
        action: String = "act.tap",
        status: TKActTapStatus,
        context: String = "webview",
        query: String? = nil,
        selector: String? = nil,
        target: TKWebViewTapTarget? = nil,
        attempts: [TKActTapAttempt],
        verification: TKActTapVerification,
        recoveryCommand: String? = nil,
        sourceCommands: [String] = [],
        note: String,
        error: TKWebViewError? = nil,
        outcome: String? = nil,
        uiHealth: TKRuntimeUIHealthSnapshot? = nil
    ) {
        self.ok = ok
        self.action = action
        self.status = status
        self.context = context
        self.query = query
        self.selector = selector
        self.target = target
        self.attempts = attempts
        self.verification = verification
        self.recoveryCommand = recoveryCommand
        self.sourceCommands = sourceCommands
        self.note = note
        self.error = error
        self.outcome = outcome
        self.uiHealth = uiHealth
    }
}

public func TKMakeWebViewAwareTapResponse(
    selector: String,
    tap: TKWebViewTapResponse,
    expectText: String? = nil,
    wait: TKWebViewWaitResponse? = nil,
    recoveryCommand: String? = nil
) -> TKActTapWebViewAwareResponse {
    let expectProvided = expectText != nil
    let textMatched = wait?.matched
    let status: TKActTapStatus
    let ok: Bool
    let note: String
    if tap.outcome == "unknown" {
        status = .uncertain
        ok = false
        note = tap.note ?? "WebView tap execution outcome is unknown; dispatch is not confirmed. Do not automatically replay the action."
    } else if !tap.ok {
        status = .failed
        ok = false
        note = tap.error?.message ?? "WebView tap failed before dispatch."
    } else if expectProvided, textMatched == true {
        status = .passed
        ok = true
        note = "DOM click was dispatched and the expected WebView text was observed."
    } else {
        status = .uncertain
        ok = true
        note = expectProvided
            ? "DOM click was dispatched, but the expected WebView text was not observed; business completion is uncertain."
            : "DOM click was dispatched, but no expectation was provided; dispatch does not prove business completion."
    }
    return TKActTapWebViewAwareResponse(
        ok: ok,
        status: status,
        selector: selector,
        target: tap.element,
        attempts: [
            TKActTapAttempt(method: "dom_dispatch", dispatched: tap.outcome == "unknown" ? nil : tap.dispatched, trusted: tap.outcome == "unknown" ? nil : tap.trusted, performed: tap.outcome == "unknown" ? nil : tap.ok, source: "webview.tap"),
        ],
        verification: TKActTapVerification(
            expectProvided: expectProvided,
            expectText: expectText,
            textMatched: textMatched
        ),
        recoveryCommand: status == .passed ? nil : recoveryCommand,
        sourceCommands: tap.sourceCommands + (wait?.webView.map { _ in ["triton webview wait --text <expect> --json"] } ?? []),
        note: note,
        error: tap.error,
        outcome: tap.outcome,
        uiHealth: tap.uiHealth
    )
}
