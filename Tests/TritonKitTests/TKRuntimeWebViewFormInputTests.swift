import Foundation
import Testing
import TritonKitShared
@testable import TritonKit

/// Provider-backed WebView form-input contract (GitHub #204).
///
/// Covers: contenteditable/textarea discovery in snapshots with stable
/// redacted identities, first-class focus switching among multiple in-page
/// form targets, typed input with redacted output, input/change dispatch
/// evidence plus a value postcondition, and a typed unsupported result when
/// the page has not opted in to DOM control.
@Suite
struct TKRuntimeWebViewFormInputTests {
    @Test("snapshot script discovers contenteditable form targets with stable identities")
    func snapshotScriptDiscoversContentEditableForms() throws {
        let script = try runtimeWebViewSnapshotScript(include: ["metadata", "dom", "text", "forms"], maxDOMNodes: 40, maxTextBytes: 1024)

        #expect(script.contains("getAttribute(\"contenteditable\")"))
        #expect(script.contains("kind"))
        #expect(script.contains("focused"))
        #expect(script.contains("contentEditable"))
        #expect(script.contains("form-") == true)
        #expect(!script.contains("eval("))
    }

    @Test("snapshot payload decodes contenteditable form field identity and focus state")
    func snapshotPayloadDecodesContentEditableFormField() throws {
        let json = """
        {
          "text": ["Triton WebView Form Input Fixture"],
          "dom": [],
          "forms": [
            {
              "name": "title",
              "inputType": "textarea",
              "kind": "textarea",
              "selector": "#title",
              "nodeID": "title",
              "focused": true,
              "contentEditable": false,
              "label": "Title",
              "valueRedaction": "length-only",
              "valueLength": 13,
              "frame": { "x": 0, "y": 0, "width": 300, "height": 80 }
            },
            {
              "name": "body",
              "inputType": "contenteditable",
              "kind": "contenteditable",
              "selector": "#body",
              "nodeID": "body",
              "focused": false,
              "contentEditable": true,
              "label": "Body",
              "valueRedaction": "length-only",
              "valueLength": 26
            }
          ],
          "links": [],
          "truncation": { "truncated": false },
          "redaction": { "secureText": "length-only" }
        }
        """

        let payload = try decodeRuntimeWebViewSnapshotPayload(json)

        #expect(payload.forms.count == 2)
        let title = try #require(payload.forms.first { $0.name == "title" })
        #expect(title.kind == "textarea")
        #expect(title.selector == "#title")
        #expect(title.nodeID == "title")
        #expect(title.focused == true)
        let body = try #require(payload.forms.first { $0.name == "body" })
        #expect(body.kind == "contenteditable")
        #expect(body.selector == "#body")
        #expect(body.nodeID == "body")
        #expect(body.focused == false)
        #expect(body.contentEditable == true)
        #expect(body.valueRedaction == "length-only")
        #expect(body.valueLength == 26)
    }

    @Test("form focus script requires page opt-in and returns typed unsupported")
    func focusScriptRequiresPageOptIn() throws {
        let script = try runtimeWebViewFormFocusScript(selector: "#body")

        #expect(script.contains("data-triton-form-input"))
        #expect(script.contains("__tritonFormInput"))
        #expect(script.contains("webview_form_input_not_opted_in"))
        #expect(script.contains("element.focus"))
        #expect(!script.contains("eval("))
    }

    @Test("form focus script resolves stable form-N selectors and reports focused element")
    func focusScriptResolvesStableSelectors() throws {
        let script = try runtimeWebViewFormFocusScript(selector: "form-2")

        #expect(script.contains("form-"))
        #expect(script.contains("document.querySelector"))
        #expect(script.contains("activeElement"))
        #expect(script.contains("webview_form_target_not_found"))
        #expect(script.contains("valueLength"))
        #expect(script.contains("valueRedaction"))
    }

    @Test("form input script dispatches input and change with redacted postcondition")
    func formInputScriptDispatchesInputAndChange() throws {
        let script = try runtimeWebViewFormInputScript(selector: "#body", mode: .type, text: "Hello body")

        #expect(script.contains("data-triton-form-input"))
        #expect(script.contains("webview_form_input_not_opted_in"))
        #expect(script.contains("dispatchEvent(new InputEvent(\"input\""))
        #expect(script.contains("dispatchEvent(new Event(\"change\""))
        #expect(script.contains("eventsDispatched"))
        #expect(script.contains("insertedLength"))
        #expect(script.contains("valueLength"))
        #expect(script.contains("length-only"))
        #expect(!script.contains("eval("))
    }

    @Test("form input payload decodes dispatch evidence and postcondition")
    func formInputPayloadDecodesPostcondition() throws {
        let json = """
        {
          "ok": true,
          "focused": true,
          "kind": "contenteditable",
          "tagName": "DIV",
          "selector": "#body",
          "nodeID": "body",
          "insertedLength": 10,
          "valueLength": 36,
          "valueRedaction": "length-only",
          "eventsDispatched": ["input", "change"]
        }
        """

        let payload = try decodeRuntimeWebViewFormTargetPayload(json)

        #expect(payload.ok)
        #expect(payload.focused == true)
        #expect(payload.kind == "contenteditable")
        #expect(payload.selector == "#body")
        #expect(payload.nodeID == "body")
        #expect(payload.insertedLength == 10)
        #expect(payload.valueLength == 36)
        #expect(payload.valueRedaction == "length-only")
        #expect(payload.eventsDispatched == ["input", "change"])
    }

    @Test("form input payload decodes not-opted-in typed unsupported")
    func formInputPayloadDecodesNotOptedIn() throws {
        let json = """
        {
          "ok": false,
          "optedIn": false,
          "error": {
            "code": "webview_form_input_not_opted_in",
            "message": "Page has not opted into Triton DOM form control.",
            "hint": "Add data-triton-form-input or use host HID."
          }
        }
        """

        let payload = try decodeRuntimeWebViewFormTargetPayload(json)

        #expect(payload.ok == false)
        #expect(payload.optedIn == false)
        #expect(payload.error?.code == .webViewFormInputNotOptedIn)
    }

    @Test("form input fixture exposes title textarea and body contenteditable")
    func fixtureExposesTitleAndBodyFormTargets() throws {
        let html = try Self.fixtureHTML()

        #expect(html.contains("<textarea id=\"title\""))
        #expect(html.contains("id=\"body\""))
        #expect(html.contains("contenteditable=\"true\""))
        #expect(html.contains("window.__tritonFormInput = true"))
        #expect(html.contains("data-triton-form-input=\"1\""))
    }

    private static func fixtureHTML() throws -> String {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
            let parent = directory.deletingLastPathComponent()
            try #require(parent.path != directory.path)
            directory = parent
        }
        return try String(
            contentsOf: directory.appendingPathComponent("Tests/TritonKitTests/Fixtures/webview-form-input.html"),
            encoding: .utf8
        )
    }
}
