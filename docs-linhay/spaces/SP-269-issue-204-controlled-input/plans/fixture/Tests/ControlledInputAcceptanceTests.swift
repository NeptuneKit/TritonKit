import XCTest
import UIKit
import WebKit
import TritonKitShared
@testable import TritonKit
@testable import ControlledInputAcceptanceHost

@MainActor
final class ControlledInputAcceptanceTests: XCTestCase {
    func testReactControlledTextareaThroughLegacyProvider() async throws {
        try await acceptedInput(kind: "textarea", selector: "#controlled-textarea", value: "accepted textarea\n第二行")
    }

    func testReactControlledInputThroughLegacyProvider() async throws {
        try await acceptedInput(kind: "input", selector: "#controlled-input", value: "accepted input & spaces")
    }

    func testReactControlledContenteditableThroughLegacyProvider() async throws {
        try await acceptedInput(kind: "contenteditable", selector: "#controlled-contenteditable", value: "accepted editable")
    }

    func testFrameworkRejectingValueDoesNotReportSuccessfulInput() async throws {
        let webView = try await loadedWebView()
        _ = try await evaluate("window.fixture204.setRejectChanges(true)", in: webView)
        let before = try await read(webView)
        let responder = try await focus("#controlled-input", in: webView)
        let optionalResult = await performFocusedWebViewTextInsertionIfAvailable(
            responder: responder, text: "rejected input", action: "type", secure: false)
        let result = try XCTUnwrap(optionalResult)
        attach(try String(decoding: JSONEncoder().encode(result), as: UTF8.self), name: "reject-provider-result")
        XCTAssertFalse(result.ok, "Framework rejection must not produce success from an attempted DOM write")
        let after = try await read(webView)
        XCTAssertEqual((after["values"] as? [String: String])?["input"], (before["values"] as? [String: String])?["input"])
        XCTAssertEqual(after["stateMatchesDOM"] as? Bool, true)
        let rendered = try await rerender(webView)
        XCTAssertEqual((rendered["values"] as? [String: String])?["input"], "initial input")
        XCTAssertEqual((rendered["domValues"] as? [String: String])?["input"], "initial input")
        XCTAssertEqual(((rendered["validation"] as? [String: [String: Any]])?["input"])?["valid"] as? Bool, false)
    }

    func testQueuedDOMRollbackFailsBoundedProviderReadback() async throws {
        let webView = try await loadedWebView()
        let responder = try await focus("#controlled-input", in: webView)
        _ = try await evaluate("window.fixture204.armQueuedDOMRollback()", in: webView)
        let attempted = "synthetic queued rollback value 204"
        let optionalResult = await performFocusedWebViewTextInsertionIfAvailable(
            responder: responder, text: attempted, action: "type", secure: false)
        let result = try XCTUnwrap(optionalResult)
        let resultJSON = try String(decoding: JSONEncoder().encode(result), as: UTF8.self)
        attach(resultJSON, name: "queued-rollback-provider-result")
        XCTAssertFalse(result.ok, "An immediate matching write cannot hide a subsequent queued DOM rollback")
        XCTAssertEqual(result.error?.code, "webview_element_not_interactable")
        XCTAssertEqual(result.outcome, "unknown", "Input was attempted; do not authorize automatic replay")
        XCTAssertNil(result.insertedLength)
        XCTAssertFalse(resultJSON.contains(attempted), "Failure metadata must not echo inserted text")
        let state = try await read(webView)
        let probe = try XCTUnwrap(state["rollbackProbe"] as? [String: Any])
        XCTAssertEqual(probe["inputObserved"] as? Bool, true)
        XCTAssertEqual(probe["immediateDOMValue"] as? String, attempted)
        XCTAssertEqual(probe["stateBeforeRollback"] as? String, attempted,
                       "React must have accepted state before this isolated DOM-only negative control")
        XCTAssertEqual(probe["applied"] as? Bool, true)
        XCTAssertEqual(probe["restoredDOMValue"] as? String, "initial input")
        XCTAssertEqual((state["values"] as? [String: String])?["input"], attempted)
        XCTAssertEqual((state["domValues"] as? [String: String])?["input"], "initial input")
        XCTAssertEqual(state["stateMatchesDOM"] as? Bool, false)
    }

    func testStrictFormControlWithoutOptInRemainsRejected() async throws {
        let webView = try await loadedWebView()
        let before = try await read(webView)
        // This calls the actual strict product generator; legacy provider behavior
        // above is tested independently and is not replaced by this opt-in path.
        let script = try runtimeWebViewFormInputScript(selector: "#controlled-textarea", mode: .setText, text: "must not write")
        let value = try await evaluate(script, in: webView)
        let raw = try XCTUnwrap(value as? String)
        let result = try decodeRuntimeWebViewFormTargetPayload(raw)
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error?.code.rawValue, "webview_form_input_not_opted_in")
        let after = try await read(webView)
        XCTAssertEqual(after["values"] as? [String: String], before["values"] as? [String: String])
        XCTAssertEqual(after["changes"] as? [String: Int], before["changes"] as? [String: Int])
        XCTAssertEqual(after["domValues"] as? [String: String], before["domValues"] as? [String: String])
        attach(raw, name: "strict-not-opted-in")
    }

    func testAmbiguousWebViewsDoNotReceiveInput() async throws {
        let webView = try await loadedWebView()
        let responder = try await focus("#controlled-input", in: webView)
        let window = try XCTUnwrap(webView.window)
        let second = WKWebView(frame: webView.convert(webView.bounds, to: window))
        second.accessibilityIdentifier = "WebView204SecondCandidate"
        window.addSubview(second)
        defer { second.removeFromSuperview() }
        second.loadHTMLString("<html><body><input id='other' value='unchanged'><script>window.inputCount=0;document.addEventListener('input',()=>window.inputCount++);window.fixtureReady=true;</script></body></html>", baseURL: URL(string: "https://tritonkit.local/second204"))
        var ready = false
        for _ in 0..<100 {
            if (try? await evaluate("window.fixtureReady === true", in: second)) as? Bool == true { ready = true; break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(ready)
        let candidates = currentWebViewListResponse().candidates
        XCTAssertGreaterThanOrEqual(candidates.count, 2)
        XCTAssertThrowsError(try TKSelectCurrentWebView(from: candidates))
        let before = try await read(webView)
        let optionalResult = await performFocusedWebViewTextInsertionIfAvailable(
            responder: responder, text: "must not select", action: "type", secure: false)
        let result = try XCTUnwrap(optionalResult)
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error?.code, "ambiguous_webview")
        XCTAssertEqual(result.outcome, "not_started")
        let after = try await read(webView)
        XCTAssertEqual(after["changes"] as? [String: Int], before["changes"] as? [String: Int])
        XCTAssertEqual(after["domValues"] as? [String: String], before["domValues"] as? [String: String])
        let secondEvents = try await evaluate("window.inputCount", in: second) as? Int
        XCTAssertEqual(secondEvents, 0)
        attach(try String(decoding: JSONEncoder().encode(result), as: UTF8.self), name: "ambiguous-provider-result")
    }

    private func acceptedInput(kind: String, selector: String, value: String) async throws {
        let webView = try await loadedWebView()
        let before = try await read(webView)
        XCTAssertEqual(before["reactVersion"] as? String, "19.2.7")
        let responder = try await focus(selector, in: webView)
        let optionalResult = await performFocusedWebViewTextInsertionIfAvailable(
            responder: responder, text: value, action: "type", secure: false)
        let result = try XCTUnwrap(optionalResult, "Must traverse the real WKContentView legacy provider")
        attach(try String(decoding: JSONEncoder().encode(result), as: UTF8.self), name: "\(kind)-provider-result")
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.strategy, "webview-dom-active-element")
        let immediate = try await read(webView)
        assertState(immediate, kind: kind, expected: value)
        let rendered = try await rerender(webView)
        XCTAssertGreaterThan(rendered["renderGeneration"] as? Int ?? 0, immediate["renderGeneration"] as? Int ?? 0)
        XCTAssertGreaterThan(rendered["revision"] as? Int ?? 0, immediate["revision"] as? Int ?? 0)
        XCTAssertEqual(rendered["generation"] as? String, before["generation"] as? String)
        assertState(rendered, kind: kind, expected: value)
    }

    private func assertState(_ state: [String: Any], kind: String, expected: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual((state["values"] as? [String: String])?[kind], expected, file: file, line: line)
        XCTAssertEqual((state["domValues"] as? [String: String])?[kind], expected, file: file, line: line)
        XCTAssertGreaterThan((state["changes"] as? [String: Int])?[kind] ?? 0, 0, file: file, line: line)
        XCTAssertEqual(state["stateMatchesDOM"] as? Bool, true, file: file, line: line)
        XCTAssertEqual(((state["validation"] as? [String: [String: Any]])?[kind])?["valid"] as? Bool, true, file: file, line: line)
    }

    private func focus(_ selector: String, in webView: WKWebView) async throws -> UIResponder {
        let literal = String(decoding: try JSONEncoder().encode(selector), as: UTF8.self)
        // Fixture preparation only: focus and select existing text; no replacement,
        // native setter or synthetic input event is implemented in this test.
        let prepared = try await evaluate("""
        (() => { const element = document.querySelector(\(literal)); element.focus();
          if (element.isContentEditable) { const range = document.createRange(); range.selectNodeContents(element);
            const selection = getSelection(); selection.removeAllRanges(); selection.addRange(range); }
          else { element.setSelectionRange(0, element.value.length); }
          return document.activeElement === element; })()
        """, in: webView) as? Bool
        XCTAssertEqual(prepared, true)
        func all(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(all) }
        let content = try XCTUnwrap(all(webView).first { NSStringFromClass(type(of: $0)).contains("WKContentView") })
        _ = content.becomeFirstResponder()
        XCTAssertTrue(content.isFirstResponder, "The actual visible WKContentView must own responder focus")
        return content
    }

    private func loadedWebView() async throws -> WKWebView {
        var controller: AcceptanceViewController?
        for _ in 0..<100 {
            controller = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }.flatMap(\.windows)
                .compactMap { $0.rootViewController as? AcceptanceViewController }.first
            if controller != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let host = try XCTUnwrap(controller)
        let generation = host.reloadFixture()
        XCTAssertNil(host.fixtureLoadError)
        var ready = false
        for _ in 0..<100 {
            let check = "window.fixtureReady === true && document.documentElement.dataset.loadId === '\(generation)' && !!window.fixture204"
            if (try? await evaluate(check, in: host.webView)) as? Bool == true { ready = true; break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(ready, "Offline React fixture must commit the requested generation before any input")
        guard ready else { throw NSError(domain: "ControlledAcceptanceFixture", code: 1) }
        let attributeAbsent = try await evaluate("!document.documentElement.hasAttribute('data-triton-form-input')", in: host.webView) as? Bool
        let globalNotOptedIn = try await evaluate("window.__tritonFormInput !== true", in: host.webView) as? Bool
        XCTAssertEqual(attributeAbsent, true, "Every legacy case must start without the strict form opt-in attribute")
        XCTAssertEqual(globalNotOptedIn, true, "The page must not enable strict form input through the global flag")
        guard attributeAbsent == true, globalNotOptedIn == true else {
            throw NSError(domain: "ControlledAcceptanceUnexpectedOptIn", code: 1)
        }
        return host.webView
    }

    private func read(_ webView: WKWebView) async throws -> [String: Any] {
        let rawValue = try await evaluate("JSON.stringify(window.fixture204.read())", in: webView)
        let raw = try XCTUnwrap(rawValue as? String)
        attach(raw, name: "fixture-state")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }

    private func rerender(_ webView: WKWebView) async throws -> [String: Any] {
        _ = try await evaluate("window.fixture204.forceRerender(); true", in: webView)
        return try await read(webView)
    }

    private func evaluate(_ script: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            let result = EvaluationCompletion(continuation)
            webView.evaluateJavaScript(script) { value, error in
                result.finish(error.map { .failure($0) } ?? .success(value))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                result.finish(.failure(NSError(domain: "ControlledAcceptanceJavaScriptTimeout", code: 1)))
            }
        }
    }

    private func attach(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class EvaluationCompletion {
    private var continuation: CheckedContinuation<Any?, Error>?
    init(_ continuation: CheckedContinuation<Any?, Error>) { self.continuation = continuation }
    func finish(_ result: Result<Any?, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
