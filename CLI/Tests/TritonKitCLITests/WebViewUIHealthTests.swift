import Foundation
import Testing
import ArgumentParser
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct WebViewUIHealthTests {
    @Test("WebView tap keeps unknown outcome and stable health error codes")
    func tapErrorPreservesHealth() throws {
        for code in ["runtime_ui_timeout", "runtime_ui_busy", "runtime_ui_circuit_open"] {
            let original = envelope(action: "webview.tap", code: code)
            let tap = try decodeWebViewTapRuntimeResult(JSONEncoder().encode(original))
            #expect(tap.error?.code.rawValue == code)
            #expect(tap.outcome == original.outcome)
            #expect(tap.uiHealth == original.uiHealth)
            #expect(tap.dispatched == false)
            if original.outcome == "unknown" {
                #expect(tap.note?.contains("not confirmed") == true)
            }
            let copied = try JSONDecoder().decode(TKWebViewTapResponse.self, from: JSONEncoder().encode(tap))
            #expect(copied.outcome == original.outcome)
            #expect(copied.uiHealth == original.uiHealth)
        }
    }

    @Test("WebView-aware tap uncertainty is not a successful action")
    func awareTapPreservesUnknown() throws {
        let tap = try decodeWebViewTapRuntimeResult(JSONEncoder().encode(envelope(action: "webview.tap", code: "runtime_ui_timeout")))
        let response = TKMakeWebViewAwareTapResponse(selector: "#continue", tap: tap)
        #expect(response.ok == false)
        #expect(response.status == .uncertain)
        #expect(response.outcome == "unknown")
        #expect(response.uiHealth == tap.uiHealth)
        #expect(response.attempts.first?.dispatched == nil)
        #expect(response.attempts.first?.performed == nil)
        #expect(response.error?.code == .runtimeUITimeout)
        let copied = try JSONDecoder().decode(TKActTapWebViewAwareResponse.self, from: JSONEncoder().encode(response))
        #expect(copied.outcome == "unknown")
        #expect(copied.error?.code.rawValue == "runtime_ui_timeout")
        #expect(copied.uiHealth == tap.uiHealth)
    }

    @Test("call, bridge-call and events emit one unchanged error envelope and fail")
    func commandErrorOutputPreservesEnvelope() throws {
        for action in ["webview.call", "webview.bridge-call", "webview.events"] {
            let original = envelope(action: action, code: "runtime_ui_timeout")
            let data = try JSONEncoder().encode(original)
            let captured = captureOutput { try failIfWebViewRuntimeError(data, outputFormat: .json) }
            #expect(captured.error is ExitCode)
            let output = try #require(captured.output.data(using: .utf8))
            let decoded = try JSONDecoder().decode(TKWebViewErrorResponse.self, from: output)
            #expect(decoded == original)
            _ = try JSONSerialization.jsonObject(with: output)
        }
    }

    @Test("successful and domain-specific responses are not misidentified as generic errors")
    func domainSpecificResponsesRemainIntact() throws {
        let data = Data("{\"ok\":false,\"action\":\"webview.call\",\"platform\":\"ios\",\"target\":\"runtime\",\"capturedAt\":\"now\",\"error\":{\"code\":\"javascript_error\",\"message\":\"provider failure\"}}".utf8)
        let captured = captureOutput { try failIfWebViewRuntimeError(data, outputFormat: .json) }
        #expect(captured.error == nil)
        #expect(captured.output.isEmpty)
    }

    @Test("older tap and WebView-aware JSON decode without new evidence")
    func legacyTapJSONRemainsCompatible() throws {
        let tap = TKWebViewTapResponse(capturedAt: "now", platform: "ios", target: "runtime", selector: "#button", dispatched: true, elapsedMs: 1)
        let oldJSON = try JSONEncoder().encode(tap)
        let decoded = try JSONDecoder().decode(TKWebViewTapResponse.self, from: oldJSON)
        #expect(decoded.outcome == nil && decoded.uiHealth == nil)
        let response = TKMakeWebViewAwareTapResponse(selector: "#button", tap: decoded)
        #expect(response.ok)
        #expect(response.status == .uncertain)
        #expect(response.outcome == nil)
    }

    private func envelope(action: String, code: String) -> TKWebViewErrorResponse {
        let timedOut = code == "runtime_ui_timeout"
        let health = TKRuntimeUIHealthSnapshot(state: timedOut ? .timedOut : .busy, allowsUIRequests: false, inflight: TKRuntimeUIInflightRequest(token: "test", requestID: 41, requestType: "webViewTap", elapsedMilliseconds: 50, timedOut: timedOut), consecutiveTimeouts: timedOut ? 1 : 0, failureThreshold: 3, timeoutMilliseconds: 50, lastCompletion: nil)
        return TKWebViewErrorResponse(action: action, platform: "ios", target: "embedded-runtime", error: TKCLIErrorDetail(code: code, message: "UI request incomplete"), outcome: timedOut ? "unknown" : "not_started", uiHealth: health)
    }

    private func captureOutput(_ body: () throws -> Void) -> (output: String, error: Error?) {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        var caught: Error?
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        do { try body() } catch { caught = error }
        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        pipe.fileHandleForWriting.closeFile()
        return (String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), caught)
    }
}
