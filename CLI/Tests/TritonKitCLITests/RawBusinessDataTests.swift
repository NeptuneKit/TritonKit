import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("SP-286 raw business data boundary")
struct RawBusinessDataTests {
    private func recordedCase(_ root: URL, text: String) throws -> URL {
        let output = root.appendingPathComponent("fixture.tritontestcase")
        let sessions = root.appendingPathComponent("sessions")
        let started = try startTritonTestRecorderSession(caseName: "raw-values", sourcePlatform: "ios", outputPath: output.path, sessionStoreRoot: sessions)
        _ = try appendTritonTestRecorderEvent(sessionID: started.sessionId, eventKind: "action",
            payloadJSON: String(decoding: JSONSerialization.data(withJSONObject: ["id": "input", "kind": "type", "text": text, "target": ["label": "editor"]]), as: UTF8.self), sessionStoreRoot: sessions)
        _ = try appendTritonTestRecorderEvent(sessionID: started.sessionId, eventKind: "page-route",
            payloadJSON: #"{"id":"page","route":"editor"}"#, sessionStoreRoot: sessions)
        _ = try stopTritonTestRecorderSession(sessionID: started.sessionId, sessionStoreRoot: sessions)
        return output
    }

    @Test("compile preserves business-looking text instead of guessing privacy", arguments: ["", "  ", "alice@example.test", "123456789012345", "password token secret", "普通订单 1234567890123"])
    func compileKeepsText(_ text: String) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("raw-case-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try recordedCase(root, text: text)
        let response = try compileTritonTestCase(path: folder.path, writeContract: true)
        let contract = try #require(response.compiledContract)
        #expect(contract.actions.first?.inputText == text)
        #expect(!contract.qualityFindings.contains { $0.code == "privacy_candidate" || $0.proposalKind == "contract.redaction" })
        let replay = try replayTritonTestCaseDryRun(path: folder.path, platform: "ios", device: nil)
        #expect(!replay.blockers.contains { $0.code == "redaction_review_required" })
    }

    @Test("network fixture stores exact business response body")
    func rawNetworkFixture() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("raw-network-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let body = #"{"email":"alice@example.test","token":"business-value","text":"  hello\n世界  "}"#
        let request = TKTestRecorderCompiledNetworkRequest(index: 1, sourcePath: "network/capture.ndjson:1", id: "r1", method: "GET", url: "https://example.test/orders?page=2", statusCode: 200, responseBody: body)
        let paths = try writeTestRecorderNetworkFixturesIfNeeded(for: [request], caseURL: root)
        let path = try #require(paths[1])
        let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(path))) as? [String: String])
        #expect(fixture["body"] == body)
        let decoded = try JSONDecoder().decode(TKTestRecorderCompiledNetworkRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded.responseBody == body)
    }

    @Test("URL capture preserves all business parameters and encoded representation")
    func captureKeepsURL() {
        let raw = "https://example.test/search?q=secret%20garden&order=1234567890123&page=2#details"
        #expect(redactedNetworkCaptureURL(raw) == raw)
        let authenticated = redactedNetworkCaptureURL("https://user:pass@example.test/search?q=ordinary#row")
        #expect(authenticated == "https://example.test/search?q=ordinary#row")
    }

    @Test("iOS sanitizer retains nested payload keys even when they resemble credentials")
    func iosKeepsPayload() throws {
        let envelope: [String: Any] = ["token": "transport-secret", "result": ["text": "original", "token": "business-code", "nested": ["authorization": "business-state", "text": "unchanged"]]]
        let output = try #require(iosRunnerSanitize(envelope) as? [String: Any])
        #expect(output["token"] == nil)
        let result = try #require(output["result"] as? [String: Any])
        #expect(result["text"] as? String == "original")
        #expect(result["token"] as? String == "business-code")
        #expect((result["nested"] as? [String: Any])?["authorization"] as? String == "business-state")
    }
    @Test("raw WebView values survive actual CLI decode and JSON encoding")
    func webViewCLIValueRoundtrip() throws {
        let field = TKWebViewFormFieldSummary(name: "password", inputType: "password", valueRedaction: "none", valueLength: 21, value: " alice@example.test ")
        let response = TKWebViewFormInputResponse(capturedAt: "fixture", platform: "ios", target: "fixture",
            mode: "set", focused: true, element: field, elapsedMs: 1, value: field.value)
        let data = try JSONEncoder().encode(response)
        guard case .formInput(let decoded) = try decodeWebViewFormInputRuntimeResult(data) else {
            Issue.record("Raw form response was not decoded as a form response"); return
        }
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
        #expect(json?["value"] as? String == field.value)
        #expect((json?["element"] as? [String: Any])?["value"] as? String == field.value)
        let old = TKWebViewFormFieldSummary(name: "legacy", inputType: "text", valueRedaction: "length-only", valueLength: 3)
        #expect(try JSONDecoder().decode(TKWebViewFormFieldSummary.self, from: JSONEncoder().encode(old)).value == nil)
    }

    @Test("network provider error text is retained alongside its classification")
    func originalNetworkError() throws {
        let request = Data("GET http://example.test/search?q=1234567890123 HTTP/1.1\r\nHost: example.test\r\n\r\n".utf8)
        let event = try parseNetworkProxyHTTPHeader(request, listen: "127.0.0.1:19431", capturePath: "fixture", connectionIndex: 1)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        json["error"] = "upstream rejected secret garden order=1234567890123"
        let failed = try JSONDecoder().decode(NetworkProxyServeEvent.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(try redactedNetworkCaptureEvent(failed).error == json["error"] as? String)
    }

    @Test("empty and colliding network fixtures retain their individual source bodies")
    func emptyAndCollidingFixtures() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("raw-collision-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bodies = ["", "second@example.test", "token business"]
        let ids = ["a/b", "a?b", "a/b"]
        let requests = bodies.enumerated().map { index, body in
            TKTestRecorderCompiledNetworkRequest(index: index + 1, sourcePath: "source:\(index)", id: ids[index], method: "GET",
                url: "https://example.test/\(index)", statusCode: 200, responseBody: body)
        }
        let refs = try writeTestRecorderNetworkFixturesIfNeeded(for: requests, caseURL: root)
        #expect(Set(refs.values).count == bodies.count)
        for (index, body) in bodies.enumerated() {
            let path = try #require(refs[index + 1])
            let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(path))) as? [String: String])
            #expect(fixture["body"] == body)
            #expect(fixture["id"] == ids[index])
        }
    }

    @Test("empty response body survives the real recorder compiler")
    func emptyBodyThroughCompiler() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("raw-empty-body-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try recordedCase(root, text: "")
        let network = folder.appendingPathComponent("network")
        try FileManager.default.createDirectory(at: network, withIntermediateDirectories: true)
        try Data(#"{"id":"empty","url":"/api/orders","method":"GET","responseBody":"","statusCode":200}"#.utf8).write(to: network.appendingPathComponent("capture.ndjson"))
        let result = try compileTritonTestCase(path: folder.path, writeContract: true)
        #expect(result.compiledContract?.network.requests.first?.responseBody == "")
        let replay = try replayTritonTestCaseDryRun(path: folder.path, platform: "ios", device: nil)
        #expect(replay.plannedSteps.first?.argv.contains("") == true)
    }

    @Test("legacy capture remains readable without inventing removed query data")
    func legacyCaptureDoesNotInventData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-capture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("capture.ndjson")
        let event = try parseNetworkProxyHTTPHeader(Data("GET http://example.test/orders HTTP/1.1\r\nHost: example.test\r\n\r\n".utf8), listen: "127.0.0.1:19431", capturePath: "fixture", connectionIndex: 1)
        var payload = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        payload["redaction"] = legacyNetworkCaptureURLRedaction
        try (JSONSerialization.data(withJSONObject: payload) + Data("\n".utf8)).write(to: source)
        let captured = try readValidatedNetworkCapture(sourceURL: source)
        #expect(captured.events.first?.redaction == legacyNetworkCaptureURLRedaction)
        #expect(captured.summary.redaction == legacyNetworkCaptureURLRedaction)
        #expect(captured.events.first?.url == event.url)
        #expect(!String(decoding: captured.data, as: UTF8.self).contains("business-query-preserved"))
    }

    @Test("a business object named found and receipt is not a receipt protocol route")
    func businessReceiptShapeIsNotProtocol() throws {
        let object: [String: Any] = ["ok": true, "result": ["found": true,
            "receipt": ["text": "business text", "token": "business token", "authorization": "business state"]]]
        let output = try #require(iosRunnerSanitize(object) as? [String: Any])
        let result = try #require(output["result"] as? [String: Any])
        let business = try #require(result["receipt"] as? [String: Any])
        #expect(business["token"] as? String == "business token")
        #expect(business["authorization"] as? String == "business state")
    }

}
