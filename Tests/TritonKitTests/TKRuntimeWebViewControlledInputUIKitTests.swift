#if canImport(UIKit) && canImport(WebKit)
import Foundation
import Testing
import UIKit
import WebKit
import TritonKitShared
@testable import TritonKit

/// Real WebKit behavior; this suite must run on an iOS destination.
@Suite(.serialized)
@MainActor
struct TKRuntimeWebViewControlledInputUIKitTests {
    @Test("native setter bypasses a controlled-input tracker in real WebKit")
    func nativeSetter() async throws {
        let webView = try await loadedWebView("<input id='field' value='Before'>")
        _ = try await evaluate("""
        var field = document.getElementById('field');
        var native = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
        var tracked = field.value;
        Object.defineProperty(field, 'value', { get: function() { return native.get.call(this); }, set: function(v) { tracked = v; native.set.call(this, v); } });
        field.addEventListener('input', function() { if (tracked === field.value) { native.set.call(field, 'Before'); } });
        """, in: webView)
        let payload = try await mutate(webView, text: "Updated")
        #expect(payload.ok)
        #expect(payload.valueMatched == true)
        #expect(payload.eventsDispatched == ["input", "change", "blur"])
        #expect(try await evaluate("document.getElementById('field').value", in: webView) as? String == "Updated")
    }

    @Test("valid date number and select writes survive unsupported caret APIs")
    func nonTextFields() async throws {
        for (html, text) in [
            ("<input id='field' type='date'>", "2026-10-14"),
            ("<input id='field' type='number'>", "42"),
            ("<select id='field'><option value='a'>A</option><option value='b'>B</option></select>", "b"),
            ("<textarea id='field'></textarea>", "Updated")
        ] {
            let webView = try await loadedWebView(html)
            let payload = try await mutate(webView, text: text)
            #expect(payload.ok)
            #expect(payload.valueMatched == true)
            #expect(try await evaluate("document.getElementById('field').value", in: webView) as? String == text)
        }
    }

    @Test("queued controlled rollback fails settled readback without leaking the value")
    func asynchronousRollback() async throws {
        let webView = try await loadedWebView("<input id='field' type='password' value='Before'>")
        _ = try await evaluate("document.getElementById('field').addEventListener('input', function() { var field = this; setTimeout(function() { field.value = 'Before'; }, 0); });", in: webView)
        let payload = try await mutate(webView, text: "private-secret")
        #expect(!payload.ok)
        #expect(payload.error?.code == .webViewElementNotInteractable)
        #expect(payload.valueLength == 6)
        #expect(payload.valueRedaction == "length-only")
    }

    @Test("invalid native date sanitization and unavailable select value fail readback")
    func rejectedNativeValue() async throws {
        for html in ["<input id='field' type='date'>", "<select id='field'><option value='a'>A</option></select>"] {
            let webView = try await loadedWebView(html)
            let payload = try await mutate(webView, text: "unavailable")
            #expect(!payload.ok)
            #expect(payload.valueMatched == false)
        }
    }

    @Test("contenteditable retains its existing input contract")
    func contentEditable() async throws {
        let webView = try await loadedWebView("<div id='field' contenteditable='true'>Before</div>")
        let payload = try await mutate(webView, text: "Updated")
        #expect(payload.ok)
        #expect(payload.kind == "contenteditable")
        #expect(try await evaluate("document.getElementById('field').textContent", in: webView) as? String == "Updated")
    }

    private func mutate(_ webView: WKWebView, text: String) async throws -> RuntimeWebViewFormTargetPayload {
        try await evaluateRuntimeWebViewFormInput(selector: "#field", mode: .setText, text: text, in: webView)
    }

    private func loadedWebView(_ body: String) async throws -> WKWebView {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        webView.loadHTMLString("<html data-triton-form-input='1'><body>\(body)</body></html>", baseURL: nil)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let ready = try? await evaluate("document.readyState === 'complete' && !!document.getElementById('field')", in: webView) as? Bool, ready {
                return webView
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw NSError(domain: "WebViewFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture did not load its expected form target"])
    }

    private func evaluate(_ script: String, in webView: WKWebView) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value ?? NSNull()) }
            }
        }
    }
}
#endif
