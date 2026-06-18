import Foundation
import Testing
import TritonKitShared
@testable import TritonKit

@Suite
struct TKRuntimeWebViewSnapshotTests {
    @Test("WebView snapshot payload decodes DOM forms links and truncation")
    func snapshotPayloadDecoding() throws {
        let json = """
        {
          "text": ["Triton WebView Smoke", "route=/smoke ready=true"],
          "dom": [
            {
              "nodeID": "dom-1",
              "role": "button",
              "tagName": "button",
              "text": "Submit",
              "frame": { "x": 10, "y": 20, "width": 120, "height": 44 }
            }
          ],
          "forms": [
            {
              "name": "password",
              "inputType": "password",
              "label": "Password",
              "valueRedaction": "length-only",
              "valueLength": 8
            }
          ],
          "links": [
            { "text": "Help", "href": "https://example.invalid/help" }
          ],
          "truncation": {
            "truncated": true,
            "reason": "maxDOMNodes",
            "maxNodes": 1,
            "returnedNodes": 1,
            "maxBytes": 128,
            "returnedBytes": 74
          },
          "redaction": { "secureText": "length-only" }
        }
        """

        let payload = try decodeRuntimeWebViewSnapshotPayload(json)

        #expect(payload.text.count == 2)
        #expect(payload.dom.first?.role == "button")
        #expect(payload.forms.first?.valueRedaction == "length-only")
        #expect(payload.forms.first?.valueLength == 8)
        #expect(payload.links.first?.href == "https://example.invalid/help")
        #expect(payload.truncation.truncated)
        #expect(payload.redaction.secureText == "length-only")
    }

    @Test("WebView snapshot script never exposes raw password values")
    func snapshotScriptRedactsSecureFields() throws {
        let script = try runtimeWebViewSnapshotScript(include: ["metadata", "dom", "text", "forms"], maxDOMNodes: 20, maxTextBytes: 1024)

        #expect(script.contains("length-only"))
        #expect(script.contains("valueLength"))
        #expect(!script.contains(".value,"))
    }

    @Test("WebView snapshot script resolves labels without selector interpolation")
    func snapshotScriptAvoidsLabelSelectorInterpolation() throws {
        let script = try runtimeWebViewSnapshotScript(include: ["forms"], maxDOMNodes: nil, maxTextBytes: nil)

        #expect(script.contains("document.getElementsByTagName(\"label\")"))
        #expect(script.contains("getAttribute(\"for\") === element.id"))
        #expect(!script.contains("querySelector('label[for=\"'"))
    }

    @Test("WebView snapshot script bounds forms and links")
    func snapshotScriptBoundsFormsAndLinks() throws {
        let script = try runtimeWebViewSnapshotScript(include: ["forms", "links"], maxDOMNodes: 3, maxTextBytes: nil)

        #expect(script.contains("forms.length < maxNodes"))
        #expect(script.contains("links.length < maxNodes"))
        #expect(script.contains("dom.length + forms.length + links.length"))
    }

    @Test("iOS WebView provider capability defaults expose unsupported recovery")
    func iOSProviderCapabilityDefaultsExposeRecovery() throws {
        let capabilities = TKWebViewProviderCapabilities.iosRuntimeDefaults()

        #expect(capabilities.supportsCurrentURL.supported)
        #expect(capabilities.supportsSnapshot.supported)
        #expect(capabilities.supportsBridgeCall.supported == false)
        #expect(capabilities.supportsBridgeCall.reason == "page must expose an allowlisted window.__tritonBridge.methods entry")
        #expect(capabilities.supportsBridgeCall.nextAction?.args == ["call", "<method>", "--json"])
        #expect(capabilities.supportsEvents.supported)
        #expect(capabilities.supportsDOMInput.supported)
        #expect(capabilities.supportsDOMInput.nextAction?.command == "input")
        #expect(capabilities.supportsContentEditableTyping.supported)
        #expect(capabilities.supportsContentEditableTyping.reason == "focused contenteditable insertion is supported after runtime focus")
    }

    @Test("bridge method not allowed script includes recovery hint")
    func bridgeMethodNotAllowedIncludesRecoveryHint() throws {
        let script = try bridgeCallScript(method: "missingMethod", arguments: [:])

        #expect(script.contains("webview_method_not_allowed"))
        #expect(script.contains("window.__tritonBridge.methods"))
        #expect(script.contains("triton webview snapshot --include metadata,text,dom,forms --json"))
    }
}
