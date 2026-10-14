import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

/// Page opt-in marker required before Triton DOM form control (focus, type,
/// set-text) may touch a page. The page opts in by exposing
/// `document.documentElement[data-triton-form-input="1"]` or
/// `window.__tritonFormInput === true`. Without opt-in, commands return the
/// typed `webview_form_input_not_opted_in` error and document the host-HID
/// fallback instead of silently touching DOM state.
private let runtimeWebViewFormInputOptInExpression = """
    (document.documentElement && document.documentElement.getAttribute("data-triton-form-input") === "1") || window.__tritonFormInput === true
    """

private let runtimeWebViewFormInputNotOptedInError = """
    {
      code: "webview_form_input_not_opted_in",
      message: "The page has not opted into Triton DOM form control.",
      hint: "Expose data-triton-form-input=\\"1\\" on <html> or set window.__tritonFormInput = true to opt in; otherwise use the host-HID fallback (tap the field, then `triton act type <text> --json`)."
    }
    """

private let runtimeWebViewFormFieldHelpers = """
      function clean(value) {
        return String(value || "").replace(/\\s+/g, " ").trim();
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
      function optedIn() {
        return \(runtimeWebViewFormInputOptInExpression);
      }
      function isFormField(element) {
        if (!element) { return false; }
        var tag = String(element.tagName || "").toLowerCase();
        if (tag === "input" || tag === "textarea" || tag === "select") { return true; }
        var attr = element.getAttribute("contenteditable");
        return attr !== null && attr !== "false";
      }
      function formFieldElements() {
        return Array.prototype.slice.call(document.querySelectorAll("input, textarea, select, [contenteditable]")).filter(isFormField);
      }
      function resolveFormSelector(selector) {
        if (!selector || !clean(selector)) { return document.activeElement || null; }
        if (selector.indexOf("#") === 0 && selector.indexOf(" ") < 0 && selector.indexOf("[") < 0) {
          return document.getElementById(selector.slice(1));
        }
        if (selector.indexOf("[name=") === 0 && selector.lastIndexOf("]") === selector.length - 1) {
          var nameValue = selector.slice(7, -1).replace(/^"|"$/g, "");
          var named = Array.prototype.slice.call(document.querySelectorAll("[name]"));
          for (var index = 0; index < named.length; index += 1) {
            if (String(named[index].getAttribute("name") || "") === nameValue) { return named[index]; }
          }
          return null;
        }
        if (selector.indexOf("form-") === 0) {
          var targetIndex = parseInt(selector.slice(5), 10);
          var fields = formFieldElements();
          if (!isNaN(targetIndex) && targetIndex >= 1 && targetIndex <= fields.length) { return fields[targetIndex - 1]; }
          return null;
        }
        try {
          return document.querySelector(selector);
        } catch (_) {
          return null;
        }
      }
      function formKindFor(element) {
        var tag = String(element.tagName || "").toLowerCase();
        return (tag === "input" || tag === "textarea" || tag === "select") ? tag : "contenteditable";
      }
      function formValue(element, kind) {
        return kind === "contenteditable" ? String(element.textContent || "") : String(element.value || "");
      }
      function dispatchInputAndChange(element, inputType, data) {
        if (typeof InputEvent === "function") {
          element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: inputType, data: data }));
        } else {
          element.dispatchEvent(new Event("input", { bubbles: true }));
        }
        element.dispatchEvent(new Event("change", { bubbles: true }));
        return ["input", "change"];
      }
    """

func runtimeWebViewFormFocusScript(selector: String) throws -> String {
    let selectorData = try JSONEncoder().encode(selector)
    guard let selectorLiteral = String(data: selectorData, encoding: .utf8) else {
        throw NSError(domain: "TritonKit.WebViewFocus", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode WebView focus selector"])
    }
    return """
    (function() {
      var selector = \(selectorLiteral);
      \(runtimeWebViewFormFieldHelpers)
      if (!optedIn()) {
        return JSON.stringify({
          ok: false,
          optedIn: false,
          selector: selector || null,
          error: \(runtimeWebViewFormInputNotOptedInError)
        });
      }
      var element = resolveFormSelector(selector);
      if (!element) {
        return JSON.stringify({
          ok: false,
          selector: selector || null,
          error: {
            code: "webview_form_target_not_found",
            message: "No DOM form target matched selector: " + (selector || "<active>"),
            hint: "Run `triton webview snapshot --include metadata,text,dom,forms --json` and retry with a returned selector from the forms list."
          }
        });
      }
      if (!isFormField(element)) {
        return JSON.stringify({
          ok: false,
          selector: selector || null,
          tagName: String(element.tagName || "").toUpperCase(),
          error: {
            code: "webview_element_not_interactable",
            message: "Matched DOM element is not a text-editable form field.",
            hint: "Choose an input, textarea, select, or [contenteditable=true] target from the WebView snapshot forms list."
          }
        });
      }
      if (typeof element.scrollIntoView === "function") {
        element.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
      }
      if (typeof element.focus === "function") { element.focus(); }
      var kind = formKindFor(element);
      var rawValue = formValue(element, kind);
      return JSON.stringify({
        ok: true,
        focused: element === document.activeElement,
        kind: kind,
        tagName: String(element.tagName || "").toUpperCase(),
        selector: selector || null,
        nodeID: element.id || null,
        valueLength: rawValue.length,
        valueRedaction: "length-only"
      });
    })()
    """
}

func runtimeWebViewFormInputScript(selector: String?, mode: TKWebViewFormInputMode, text: String, verificationToken: String? = nil) throws -> String {
    let textData = try JSONEncoder().encode(text)
    guard let textLiteral = String(data: textData, encoding: .utf8) else {
        throw NSError(domain: "TritonKit.WebViewInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode text"])
    }
    let selectorLiteral: String
    if let selector {
        let selectorData = try JSONEncoder().encode(selector)
        guard let encoded = String(data: selectorData, encoding: .utf8) else {
            throw NSError(domain: "TritonKit.WebViewInput", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode selector"])
        }
        selectorLiteral = encoded
    } else {
        selectorLiteral = "null"
    }
    let verificationLiteral = String(data: try JSONEncoder().encode(verificationToken), encoding: .utf8)!
    let modeLiteral = mode == .setText ? "\"set\"" : "\"type\""
    let inputTypeLiteral = mode == .setText ? "\"insertText\"" : "\"insertText\""
    return """
    (function() {
      var selector = \(selectorLiteral);
      var text = \(textLiteral);
      var mode = \(modeLiteral);
      var verificationToken = \(verificationLiteral);
      \(runtimeWebViewFormFieldHelpers)
      if (!optedIn()) {
        return JSON.stringify({
          ok: false,
          optedIn: false,
          selector: selector || null,
          error: \(runtimeWebViewFormInputNotOptedInError)
        });
      }
      var element = resolveFormSelector(selector);
      if (!element) {
        return JSON.stringify({
          ok: false,
          selector: selector || null,
          error: {
            code: "webview_form_target_not_found",
            message: "No DOM form target matched selector: " + (selector || "<active>"),
            hint: "Run `triton webview snapshot --include metadata,text,dom,forms --json` and retry with a returned selector from the forms list."
          }
        });
      }
      if (!isFormField(element)) {
        return JSON.stringify({
          ok: false,
          selector: selector || null,
          tagName: String(element.tagName || "").toUpperCase(),
          error: {
            code: "webview_element_not_interactable",
            message: "Matched DOM element is not a text-editable form field.",
            hint: "Choose an input, textarea, select, or [contenteditable=true] target from the WebView snapshot forms list."
          }
        });
      }
      try {
        var kind = formKindFor(element);
        var events = [];
        if (kind !== "contenteditable") {
          if (element.disabled || element.readOnly) {
            return JSON.stringify({ ok: false, error: { code: "webview_element_not_interactable", message: "The field is disabled or read-only." } });
          }
          var realm = element.ownerDocument && element.ownerDocument.defaultView || window;
          var constructor = kind === "textarea" ? realm.HTMLTextAreaElement : kind === "select" ? realm.HTMLSelectElement : realm.HTMLInputElement;
          var descriptor = constructor && Object.getOwnPropertyDescriptor(constructor.prototype, "value");
          if (!descriptor || typeof descriptor.set !== "function") {
            return JSON.stringify({ ok: false, error: { code: "webview_element_not_interactable", message: "A native value setter is unavailable for this field." } });
          }
          if (kind === "input" && ["checkbox", "radio", "file", "button", "submit", "reset", "image", "hidden"].indexOf(String(element.type || "text").toLowerCase()) >= 0) {
            return JSON.stringify({ ok: false, error: { code: "webview_element_not_interactable", message: "This input type does not support text entry." } });
          }
          if (typeof element.focus === "function") { element.focus(); }
          var oldValue = String(element.value || "");
          var expectedValue = text;
          var start = oldValue.length;
          var end = start;
          // Date/number/select do not implement the caret APIs. A failure to
          // place a caret must not turn an accepted value into a JS failure.
          if (mode === "type" && kind !== "select") {
            try {
              if (typeof element.selectionStart === "number") { start = element.selectionStart; }
              if (typeof element.selectionEnd === "number") { end = element.selectionEnd; } else { end = start; }
            } catch (_) { start = oldValue.length; end = start; }
            expectedValue = oldValue.slice(0, start) + text + oldValue.slice(end);
          }
          descriptor.set.call(element, expectedValue);
          var cursor = mode === "type" ? start + text.length : expectedValue.length;
          try {
            if (typeof element.setSelectionRange === "function") { element.setSelectionRange(cursor, cursor); }
          } catch (_) { /* Non-text fields intentionally have no caret. */ }
          events = dispatchInputAndChange(element, \(inputTypeLiteral), text);
          if (typeof element.blur === "function") {
            var wasFocused = element === document.activeElement;
            element.blur();
            if (wasFocused) { events.push("blur"); }
          }
          function readback() {
            var currentValue = String(element.value || "");
            var valueMatched = currentValue === expectedValue && element.isConnected !== false;
            var result = {
              ok: valueMatched,
              focused: element === document.activeElement,
              kind: kind,
              tagName: String(element.tagName || "").toUpperCase(),
              selector: selector || null,
              nodeID: element.id || null,
              insertedLength: valueMatched ? text.length : 0,
              valueLength: currentValue.length,
              valueMatched: valueMatched,
              valueRedaction: "length-only",
              eventsDispatched: events
            };
            if (!valueMatched) {
              result.error = {
                code: "webview_element_not_interactable",
                message: "The field rejected or reverted the requested value.",
                hint: "Inspect the form state and validation rules before retrying; event dispatch alone is not evidence of a successful write."
              };
            }
            return JSON.stringify(result);
          }
          var result = readback();
          if (verificationToken && JSON.parse(result).ok) {
            // Retain only a one-shot closure in the page, never return field
            // contents to the host. The provider consumes it after one settle
            // window. Expiry also releases it on cancellation or navigation.
            Object.defineProperty(window, verificationToken, { configurable: true, value: readback });
            window.setTimeout(function() { delete window[verificationToken]; }, 2000);
          }
          return result;
        }
        if (typeof element.focus === "function") { element.focus(); }
        if (mode === "set") {
          var range = document.createRange ? document.createRange() : null;
          if (range && document.getSelection) {
            var selection = document.getSelection();
            range.selectNodeContents(element);
            selection.removeAllRanges();
            selection.addRange(range);
          }
          var replaced = false;
          if (document.execCommand && document.execCommand("insertText", false, text)) {
            replaced = true;
          }
          if (!replaced) { element.textContent = text; }
        } else {
          var inserted = false;
          if (document.execCommand && document.execCommand("insertText", false, text)) {
            inserted = true;
          }
          if (!inserted) { element.textContent = String(element.textContent || "") + text; }
        }
        events = dispatchInputAndChange(element, "insertText", text);
        return JSON.stringify({
          ok: true,
          focused: element === document.activeElement,
          kind: kind,
          tagName: String(element.tagName || "").toUpperCase(),
          selector: selector || null,
          nodeID: element.id || null,
          insertedLength: text.length,
          valueLength: String(element.textContent || "").length,
          valueRedaction: "length-only",
          eventsDispatched: events
        });
      } catch (error) {
        return JSON.stringify({
          ok: false,
          selector: selector || null,
          error: {
            code: "javascript_error",
            message: "The form mutation could not be completed.",
            hint: "Retry with a stable form selector and verify the page has opted into Triton DOM form control."
          }
        });
      }
    })()
    """
}

struct RuntimeWebViewFormTargetPayload: Decodable, Equatable {
    let ok: Bool
    let focused: Bool?
    let kind: String?
    let tagName: String?
    let selector: String?
    let nodeID: String?
    let insertedLength: Int?
    let valueLength: Int?
    let valueMatched: Bool?
    let valueRedaction: String?
    let eventsDispatched: [String]?
    let optedIn: Bool?
    let error: TKWebViewError?
}

func decodeRuntimeWebViewFormTargetPayload(_ json: String) throws -> RuntimeWebViewFormTargetPayload {
    try JSONDecoder().decode(RuntimeWebViewFormTargetPayload.self, from: Data(json.utf8))
}


/// Consume an operation-specific readback capability without exposing values.
/// It is removed before invoking the closure, so it cannot be reused.
func runtimeWebViewFormReadbackScript(verificationToken: String) throws -> String {
    let literal = String(data: try JSONEncoder().encode(verificationToken), encoding: .utf8)!
    return """
    (function() {
      var token = \(literal);
      var readback = window[token];
      delete window[token];
      if (typeof readback !== "function") {
        return JSON.stringify({ ok: false, error: { code: "webview_navigation_changed", message: "The form readback is no longer available; refresh the page session before retrying." } });
      }
      try { return readback(); }
      catch (_) { return JSON.stringify({ ok: false, error: { code: "javascript_error", message: "The form value could not be verified." } }); }
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
