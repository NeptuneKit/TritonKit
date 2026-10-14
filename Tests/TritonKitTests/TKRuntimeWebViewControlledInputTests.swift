import Foundation
import Testing
import TritonKitShared
@testable import TritonKit
#if canImport(JavaScriptCore)
import JavaScriptCore

@Suite
struct TKRuntimeWebViewControlledInputTests {
    @Test("controlled own setter is bypassed for input and textarea")
    func nativeSetter() throws {
        for tag in ["INPUT", "TEXTAREA"] {
            let result = try evaluate(tag: tag, setup: "Object.defineProperty(element, 'value', { get: function() { return this._value; }, set: function(v) { this.tracker = v; this._value = v; }}); element.tracker = 'Before'; element.dispatchEvent = function(e) { if (e.type === 'input' && this.tracker === this._value) { this._value = 'Before'; } return true; };")
            #expect(result.payload.ok)
            #expect(result.payload.valueLength == 7)
            #expect(result.value == "Updated")
        }
    }

    @Test("controlled input rollback cannot claim a successful mutation")
    func rollback() throws {
        let result = try evaluate(setup: "element.dispatchEvent = function(e) { if (e.type === 'input') { this._value = 'Before'; } return true; };")
        #expect(!result.payload.ok)
        #expect(result.payload.error?.code == .webViewElementNotInteractable)
        #expect(!result.json.contains("Before"))
        #expect(!result.json.contains("Updated"))
    }

    @Test("date and number selection failures do not abort valid writes")
    func unsupportedSelection() throws {
        for inputType in ["date", "number"] {
            let result = try evaluate(setup: "element.type = '\(inputType)'; Object.defineProperty(element, 'selectionStart', { get: function() { throw new Error('selection unsupported'); } }); element.setSelectionRange = function() { throw new Error('selection unsupported'); };")
            #expect(result.payload.ok)
            #expect(result.value == "Updated")
        }
    }

    @Test("select uses native setter without text selection")
    func select() throws {
        let result = try evaluate(tag: "SELECT", setup: "element.setSelectionRange = function() { throw new Error('not supported'); };")
        #expect(result.payload.ok)
        #expect(result.value == "Updated")
    }

    @Test("blur rollback is included in readback and event evidence")
    func blurRollback() throws {
        let result = try evaluate(setup: "element.blur = function() { this._value = 'Before'; document.activeElement = null; };")
        #expect(!result.payload.ok)
        #expect(result.payload.eventsDispatched == ["input", "change", "blur"])
    }

    @Test("typing replaces the selected text and preserves the text caret")
    func typeSelection() throws {
        let result = try evaluate(setup: "element.selectionStart = 1; element.selectionEnd = 4;", mode: .type, text: "X")
        #expect(result.payload.ok)
        #expect(result.value == "BXre")
    }

    @Test("readonly fields fail without delivery")
    func readOnly() throws {
        let result = try evaluate(setup: "element.readOnly = true;")
        #expect(!result.payload.ok)
        #expect(result.value == "Before")
    }

    @Test("page exceptions cannot leak field contents into the result")
    func exceptionRedaction() throws {
        let result = try evaluate(setup: "Object.defineProperty(element, 'value', { get: function() { throw new Error('private-secret'); } });")
        #expect(!result.payload.ok)
        #expect(!result.json.contains("private-secret"))
    }

    @Test("one-shot settled verification catches rollback and releases the capability")
    func settledRollback() throws {
        let context = try #require(JSContext())
        context.evaluateScript(Self.fixture(tag: "INPUT") + "window.setTimeout = function() {};" )
        let token = "__tritonFormReadback_test"
        let initial = try #require(context.evaluateScript(try runtimeWebViewFormInputScript(selector: "#field", mode: .setText, text: "Updated", verificationToken: token))?.toString())
        #expect(try decodeRuntimeWebViewFormTargetPayload(initial).ok)
        context.evaluateScript("element._value = 'Before';")
        let checked = try #require(context.evaluateScript(try runtimeWebViewFormReadbackScript(verificationToken: token))?.toString())
        #expect(try decodeRuntimeWebViewFormTargetPayload(checked).ok == false)
        #expect(context.evaluateScript("typeof window['\(token)']")?.toString() == "undefined")
        #expect(!checked.contains("Updated"))
        #expect(!checked.contains("Before"))
    }

    private func evaluate(tag: String = "INPUT", setup: String = "", mode: TKWebViewFormInputMode = .setText, text: String = "Updated") throws -> (payload: RuntimeWebViewFormTargetPayload, value: String, json: String) {
        let context = try #require(JSContext())
        context.evaluateScript(Self.fixture(tag: tag) + setup)
        try #require(context.exception == nil)
        let script = try runtimeWebViewFormInputScript(selector: "#field", mode: mode, text: text)
        let json = try #require(context.evaluateScript(script)?.toString())
        try #require(context.exception == nil)
        context.exception = nil
        let value = try #require(context.evaluateScript("element._value")?.toString())
        return (try decodeRuntimeWebViewFormTargetPayload(json), value, json)
    }

    private static func fixture(tag: String) -> String {
        """
        var window = this;
        function HTMLInputElement() {}
        function HTMLTextAreaElement() {}
        function HTMLSelectElement() {}
        [HTMLInputElement, HTMLTextAreaElement, HTMLSelectElement].forEach(function(c) {
          Object.defineProperty(c.prototype, 'value', { get: function() { return this._value; }, set: function(v) { this._value = String(v); }});
        });
        var ctor = \(tag == "TEXTAREA" ? "HTMLTextAreaElement" : tag == "SELECT" ? "HTMLSelectElement" : "HTMLInputElement");
        var element = new ctor(); element.tagName = '\(tag)'; element.type = 'text'; element.id = 'field'; element._value = 'Before'; element.isConnected = true;
        var document = { activeElement: element, documentElement: { getAttribute: function() { return '1'; } }, getElementById: function() { return element; } };
        element.ownerDocument = { defaultView: window };
        element.getAttribute = function() { return null; };
        element.dispatchEvent = function(e) { return true; };
        element.focus = function() { document.activeElement = this; };
        element.blur = function() { document.activeElement = null; };
        element.setSelectionRange = function() {};
        function Event(type, options) { this.type = type; }
        function InputEvent(type, options) { this.type = type; }
        """
    }
}
#endif
