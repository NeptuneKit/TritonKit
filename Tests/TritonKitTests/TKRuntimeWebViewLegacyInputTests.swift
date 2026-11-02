import Foundation
import Testing
@testable import TritonKit
#if canImport(JavaScriptCore)
import JavaScriptCore

@Suite
struct TKRuntimeWebViewLegacyInputTests {
    @Test("legacy input updates controlled state before a later rerender")
    func controlledState() throws {
        for tag in ["INPUT", "TEXTAREA"] {
            let context = try makeContext(tag: tag)
            context.evaluateScript("""
            var native = Object.getOwnPropertyDescriptor(element.constructor.prototype, 'value');
            var tracked = element.value; var state = element.value; var changes = 0;
            Object.defineProperty(element, 'value', { get: function() { return native.get.call(this); }, set: function(v) { tracked = String(v); native.set.call(this, v); } });
            element.dispatchEvent = function(e) {
              if (e.type === 'input' && tracked !== element.value) { tracked = element.value; state = element.value; changes++; }
              return true;
            };
            """)
            let result = try insert(context, text: " Updated")
            #expect(result.payload.ok)
            #expect(context.evaluateScript("state")?.toString() == "Before Updated")
            #expect(context.evaluateScript("changes")?.toInt32() == 1)
            context.evaluateScript("element.value = state;")
            #expect(context.evaluateScript("element.value")?.toString() == "Before Updated")
        }
    }

    @Test("synchronous rollback does not claim inserted text")
    func rollback() throws {
        let context = try makeContext()
        context.evaluateScript("element.dispatchEvent = function() { element._value = 'Before'; return true; };")
        let result = try insert(context)
        #expect(!result.payload.ok)
        #expect(result.payload.insertedLength == nil || result.payload.insertedLength == 0)
        #expect(!result.json.contains("private-secret"))
    }

    @Test("detached field cannot claim a successful write")
    func detached() throws {
        let context = try makeContext()
        context.evaluateScript("element.dispatchEvent = function() { element.isConnected = false; return true; };")
        #expect(try insert(context).payload.ok == false)
    }

    @Test("readonly and disabled fields refuse before delivery")
    func readOnly() throws {
        for property in ["readOnly", "disabled"] {
            let context = try makeContext()
            context.evaluateScript("element.\(property) = true;")
            #expect(try insert(context).payload.ok == false)
            #expect(context.evaluateScript("element.value")?.toString() == "Before")
            #expect(context.evaluateScript("events.length")?.toInt32() == 0)
        }
    }

    @Test("selection replacement preserves the caret without requiring page opt-in")
    func selection() throws {
        let context = try makeContext(tag: "TEXTAREA")
        context.evaluateScript("element.selectionStart = 1; element.selectionEnd = 4;")
        #expect(try insert(context, text: "X").payload.ok)
        #expect(context.evaluateScript("element.value")?.toString() == "BXre")
        #expect(context.evaluateScript("element.selectionStart")?.toInt32() == 2)
    }

    @Test("password results do not contain supplied or existing text")
    func password() throws {
        let context = try makeContext()
        context.evaluateScript("element.type = 'password';")
        let result = try insert(context)
        #expect(result.payload.ok)
        #expect(result.payload.insertedLength == 14)
        #expect(!result.json.contains("private-secret"))
        #expect(!result.json.contains("Before"))
    }

    @Test("page exceptions do not leak private field values")
    func exceptionRedaction() throws {
        let context = try makeContext()
        context.evaluateScript("Object.defineProperty(element, 'value', { get: function() { throw new Error('private-secret'); } });")
        let result = try insert(context)
        #expect(!result.payload.ok)
        #expect(!result.json.contains("private-secret"))
    }

    @Test("contenteditable retains its execCommand path")
    func contentEditable() throws {
        let context = try makeContext()
        context.evaluateScript("element.tagName = 'DIV'; element.isContentEditable = true; element.textContent = 'Before'; document.execCommand = function(name, ui, text) { element.textContent += text; return true; };")
        let result = try insert(context, text: " Updated")
        #expect(result.payload.ok)
        #expect(context.evaluateScript("element.textContent")?.toString() == "Before Updated")
    }

    @Test("settled readback rejects rollback and consumes its one-shot capability")
    func settledRollback() throws {
        let context = try makeContext()
        context.evaluateScript("window.setTimeout = function() {};")
        let token = "__tritonLegacyReadback_test"
        let initial = try #require(context.evaluateScript(try webViewFocusedTextInsertionScript(text: "private-secret", verificationToken: token))?.toString())
        #expect(try decodeWebViewFocusedTextInsertionPayload(initial).ok)
        context.evaluateScript("element._value = 'Before';")
        let checked = try #require(context.evaluateScript(try runtimeWebViewFormReadbackScript(verificationToken: token))?.toString())
        let result = try decodeWebViewFocusedTextInsertionPayload(checked)
        #expect(!result.ok)
        #expect(result.valueMatched == false)
        #expect(result.insertedLength == 0)
        #expect(result.error?.code.rawValue == "webview_element_not_interactable")
        #expect(context.evaluateScript("typeof window['\(token)']")?.toString() == "undefined")
        #expect(!checked.contains("private-secret"))
        #expect(!checked.contains("Before"))
        let replay = try #require(context.evaluateScript(try runtimeWebViewFormReadbackScript(verificationToken: token))?.toString())
        #expect(try decodeWebViewFocusedTextInsertionPayload(replay).error?.code.rawValue == "webview_navigation_changed")
    }

    private func insert(_ context: JSContext, text: String = "private-secret") throws -> (payload: WebViewFocusedTextInsertionPayload, json: String) {
        let json = try #require(context.evaluateScript(try webViewFocusedTextInsertionScript(text: text))?.toString())
        try #require(context.exception == nil)
        return (try decodeWebViewFocusedTextInsertionPayload(json), json)
    }

    private func makeContext(tag: String = "INPUT") throws -> JSContext {
        let context = try #require(JSContext())
        context.evaluateScript("""
        var window = this;
        function HTMLInputElement() {} function HTMLTextAreaElement() {}
        [HTMLInputElement, HTMLTextAreaElement].forEach(function(c) {
          Object.defineProperty(c.prototype, 'value', { get: function() { return this._value; }, set: function(v) { this._value = String(v); } });
        });
        var element = new \(tag == "TEXTAREA" ? "HTMLTextAreaElement" : "HTMLInputElement")();
        element.tagName = '\(tag)'; element.type = 'text'; element._value = 'Before'; element.isConnected = true;
        element.ownerDocument = { defaultView: window }; element.selectionStart = 6; element.selectionEnd = 6;
        element.setSelectionRange = function(a, b) { this.selectionStart = a; this.selectionEnd = b; };
        var events = []; element.dispatchEvent = function(e) { events.push(e.type); return true; };
        var document = { activeElement: element };
        function Event(type) { this.type = type; } function InputEvent(type) { this.type = type; }
        """)
        try #require(context.exception == nil)
        return context
    }
}
#endif
