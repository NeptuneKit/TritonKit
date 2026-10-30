#if canImport(WebKit) && os(macOS)
import AppKit
import WebKit
import Testing
import TritonKitShared
@testable import TritonKit

@Suite(.serialized)
@MainActor
struct TKRuntimeWebViewSnapshotWebKitTests {
    @Test("snapshot selectors round-trip through actual WebKit DOM and form focus", .timeLimit(.minutes(1)))
    func actualWebKitRoundTrip() async throws {
        _ = NSApplication.shared
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
        webView.loadHTMLString("<html data-triton-form-input='1'><head><title>SnapshotFixture237</title></head><body><p>Fixture</p></body></html>", baseURL: nil)
        var ready = false
        for _ in 0..<50 {
            if (try? await evaluate("document.readyState === 'complete' && document.title === 'SnapshotFixture237'", in: webView) as? Bool) == true {
                ready = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try #require(ready, "Synthetic WKWebView did not load within 5 seconds")
        let names = ["plain", "quo\"te", "back\\slash", "line\nbreak", "tab\tname", "x\"], input, [name=\"decoy", "中文"]
        let namesLiteral = String(decoding: try JSONEncoder().encode(names), as: UTF8.self)
        _ = try await evaluate("""
        window.fixtureFields = [];
        \(namesLiteral).forEach(function(value) {
          ['name', 'id'].forEach(function(attribute) {
            var input = document.createElement('input');
            input.setAttribute(attribute, value);
            input.value = 'synthetic-secret';
            document.body.appendChild(input);
            window.fixtureFields.push(input);
          });
        });
        """, in: webView)
        for includes in [TKWebViewSnapshotRequest().include, ["forms"]] {
            let script = try runtimeWebViewSnapshotScript(include: includes, maxDOMNodes: 40, maxTextBytes: 1024)
            let json = try #require(try await evaluate(script, in: webView) as? String)
            let payload = try decodeRuntimeWebViewSnapshotPayload(json)
            #expect(payload.forms.count == names.count * 2)
            #expect(!json.contains("synthetic-secret"))
            for (index, field) in payload.forms.enumerated() {
                let selector = try #require(field.selector)
                let literal = String(decoding: try JSONEncoder().encode(selector), as: UTF8.self)
                #expect(try await evaluate("document.querySelector(\(literal)) === window.fixtureFields[\(index)]", in: webView) as? Bool == true)
                let focus = try runtimeWebViewFormFocusScript(selector: selector)
                let focusJSON = try #require(try await evaluate(focus, in: webView) as? String)
                #expect(try decodeRuntimeWebViewFormTargetPayload(focusJSON).ok)
                #expect(try await evaluate("document.activeElement === window.fixtureFields[\(index)]", in: webView) as? Bool == true)
            }
        }
    }

    private func evaluate(_ script: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            let completion = EvaluationCompletion(continuation)
            webView.evaluateJavaScript(script) { result, error in
                completion.finish(error.map { .failure($0) } ?? .success(result))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                completion.finish(.failure(NSError(domain: "SnapshotFixtureTimeout", code: 1)))
            }
        }
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
#endif
