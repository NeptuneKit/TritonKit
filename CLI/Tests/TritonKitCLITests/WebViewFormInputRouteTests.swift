import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

/// CLI glue for the provider-backed WebView form-input contract (GitHub #204):
/// `webview focus/type/set-text`, `act focus/set-text/type --webview`, schema
/// exposure, and error-envelope preservation.
@Suite
struct WebViewFormInputRouteTests {
    @Test("focus request builder keeps stable selector and source command")
    func focusRequestBuilder() {
        let request = makeWebViewFocusRequest(
            selector: "#body",
            webViewID: "ios-webkit:1",
            pageSessionID: "page-1"
        )

        #expect(request.selector == "#body")
        #expect(request.webViewID == "ios-webkit:1")
        #expect(request.pageSessionID == "page-1")
        #expect(request.sourceCommand?.contains("focus") == true)
    }

    @Test("form input request builder supports type and set modes with redaction")
    func formInputRequestBuilder() {
        let typed = makeWebViewFormInputRequest(
            mode: .type,
            text: "hello",
            selector: nil,
            secure: false,
            webViewID: nil,
            pageSessionID: nil
        )
        let set = makeWebViewFormInputRequest(
            mode: .setText,
            text: "secret",
            selector: "#body",
            secure: true,
            webViewID: "ios-webkit:1",
            pageSessionID: "page-1"
        )

        #expect(typed.mode == .type)
        #expect(typed.selector == nil)
        #expect(typed.secure == false)
        #expect(set.mode == .setText)
        #expect(set.selector == "#body")
        #expect(set.secure)
        #expect(set.sourceCommand?.contains("set-text") == true)
    }

    @Test("focus decoder preserves success and error envelopes")
    func focusDecoderPreservesEnvelopes() throws {
        let successData = try JSONEncoder().encode(TKWebViewFocusResponse(
            capturedAt: "2026-08-11T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            webViewID: "ios-webkit:1",
            selector: "#body",
            focused: true,
            elapsedMs: 5,
            sourceCommands: ["triton webview focus #body --json"]
        ))

        switch try decodeWebViewFocusRuntimeResult(successData) {
        case .focus(let response):
            #expect(response.ok)
            #expect(response.selector == "#body")
            #expect(response.focused)
        case .error:
            Issue.record("Expected focus response")
        }

        let errorData = try JSONEncoder().encode(TKWebViewErrorResponse(
            action: "webview.focus",
            platform: "ios",
            target: "embedded-runtime",
            error: TKCLIErrorDetail(
                code: "webview_form_input_not_opted_in",
                message: "Page has not opted into Triton DOM form control.",
                hint: "Add data-triton-form-input to the page or use host HID."
            )
        ))

        switch try decodeWebViewFocusRuntimeResult(errorData) {
        case .focus:
            Issue.record("Expected WebView error envelope")
        case .error(let response):
            #expect(response.error.code == "webview_form_input_not_opted_in")
        }
    }

    @Test("form input decoder preserves success and error envelopes")
    func formInputDecoderPreservesEnvelopes() throws {
        let successData = try JSONEncoder().encode(TKWebViewFormInputResponse(
            capturedAt: "2026-08-11T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            webViewID: "ios-webkit:1",
            selector: "#body",
            mode: "type",
            focused: true,
            insertedLength: 5,
            valueLength: 31,
            valueRedaction: "length-only",
            eventsDispatched: ["input", "change"],
            elapsedMs: 9,
            sourceCommands: ["triton webview type hello --selector #body --json"]
        ))

        switch try decodeWebViewFormInputRuntimeResult(successData) {
        case .formInput(let response):
            #expect(response.ok)
            #expect(response.mode == "type")
            #expect(response.eventsDispatched == ["input", "change"])
            #expect(response.valueRedaction == "length-only")
        case .error:
            Issue.record("Expected form input response")
        }

        let errorData = try JSONEncoder().encode(TKWebViewErrorResponse(
            action: "webview.form-input",
            platform: "ios",
            target: "embedded-runtime",
            error: TKCLIErrorDetail(
                code: "webview_form_target_not_found",
                message: "No DOM form target matched selector #missing."
            )
        ))

        switch try decodeWebViewFormInputRuntimeResult(errorData) {
        case .formInput:
            Issue.record("Expected WebView error envelope")
        case .error(let response):
            #expect(response.error.code == "webview_form_target_not_found")
        }
    }

    @Test("webview schema exposes focus type and set-text subcommands")
    func webviewSchemaExposesFormInputCommands() throws {
        let schema = try #require(commandSchemas().first { $0.name == "webview" })
        let optionNames = Set(schema.options.map(\.name))
        let usageForms = Set(schema.usageForms.map(\.form))
        let examples = schema.examples

        #expect(usageForms.contains("focus <selector>"))
        #expect(usageForms.contains("type <text>"))
        #expect(usageForms.contains("set-text <text>"))
        #expect(optionNames.contains("--secure"))
        #expect(schema.providedCapabilities.contains("webview-focus"))
        #expect(schema.providedCapabilities.contains("webview-form-input"))
        #expect(schema.outputContracts.contains { $0.selector == "webview.focus" })
        #expect(schema.outputContracts.contains { $0.selector == "webview.form-input" })
        #expect(schema.failureCodes.contains("webview_form_input_not_opted_in"))
        #expect(examples.contains("triton webview focus #body --json"))
        #expect(examples.contains("triton webview type hello --selector #body --json"))
    }

    @Test("act schema exposes webview form-input glue on focus set-text and type")
    func actSchemaExposesWebViewFormInputGlue() throws {
        let schema = try #require(actionCommandSchemas().first { $0.name == "act" })
        let focus = try #require(schema.subcommands.first { $0.name == "focus" })
        let setText = try #require(schema.subcommands.first { $0.name == "set-text" })
        let type = try #require(schema.subcommands.first { $0.name == "type" })

        #expect(focus.optionalOptions.contains("--webview"))
        #expect(focus.outputSelectors.contains("webview.focus"))
        #expect(setText.optionalOptions.contains("--webview"))
        #expect(setText.outputSelectors.contains("webview.form-input"))
        #expect(type.optionalOptions.contains("--webview"))
        #expect(type.outputSelectors.contains("webview.form-input"))
    }
}
