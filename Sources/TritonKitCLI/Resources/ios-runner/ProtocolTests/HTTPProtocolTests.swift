import XCTest
#if canImport(RunnerProtocol)
@testable import RunnerProtocol
#endif

final class HTTPProtocolTests: XCTestCase {
    func testCrossAppWhitelistAndBundleBinding() throws {
        let value = try CrossAppRequest(body: ["app": "settings", "operation": "probe", "expectedBundle": "com.apple.Preferences"])
        XCTAssertEqual(value.bundleID, "com.apple.Preferences")
        for body: [String: Any] in [
            ["app": "other", "operation": "probe", "expectedBundle": "other"],
            ["app": "settings", "operation": "probe"],
            ["app": "settings", "operation": "probe", "expectedBundle": "com.apple.calculator"],
            ["app": "settings", "operation": "delete", "expectedBundle": "com.apple.Preferences"],
        ] { XCTAssertThrowsError(try CrossAppRequest(body: body)) }
    }
    func testCrossAppSelectorsAndBoundedInspect() throws {
        let base: [String: Any] = ["app": "fixture", "expectedBundle": "dev.tritonkit.runnerfixture"]
        var inspect = base; inspect["operation"] = "inspect"; inspect["limit"] = 40
        XCTAssertEqual(try CrossAppRequest(body: inspect).limit, 40)
        for limit in [0, 41] { inspect["limit"] = limit; XCTAssertThrowsError(try CrossAppRequest(body: inspect)) }
        var tap = base; tap["operation"] = "tap"
        XCTAssertThrowsError(try CrossAppRequest(body: tap))
        tap["selector"] = ["kind": "identifier", "value": "incrementButton"]
        XCTAssertEqual(try CrossAppRequest(body: tap).selector?.value, "incrementButton")
        tap["selector"] = ["kind": "predicate", "value": "TRUEPREDICATE"]
        XCTAssertThrowsError(try CrossAppRequest(body: tap))
    }
    func testCrossAppTextAndNavigationAreBounded() throws {
        var body: [String: Any] = ["app": "safari", "expectedBundle": "com.apple.mobilesafari", "operation": "typeText", "selector": ["kind": "label", "value": "Address"]]
        body["text"] = CrossAppRequest.testPhrase
        XCTAssertNoThrow(try CrossAppRequest(body: body))
        body["text"] = "输入产品文本"
        XCTAssertNoThrow(try CrossAppRequest(body: body))
        for text: Any in ["", 123, String(repeating: "汉", count: 1366)] {
            body["text"] = text
            XCTAssertThrowsError(try CrossAppRequest(body: body))
        }
        body.removeValue(forKey: "text"); body["operation"] = "navigateExample"
        XCTAssertNoThrow(try CrossAppRequest(body: body))
        body["url"] = "https://unapproved.invalid"
        XCTAssertThrowsError(try CrossAppRequest(body: body))
        body.removeValue(forKey: "url"); body["app"] = "settings"; body["expectedBundle"] = "com.apple.Preferences"
        XCTAssertThrowsError(try CrossAppRequest(body: body))
    }
    func testLedgerEnvelopeOverflowKeepsOriginalID() throws {
        let ledger = RequestLedger()
        let request = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/tap", body: "{}")))
        XCTAssertNil(try ledger.claim(request))
        ledger.complete(requestID: request.requestID, envelope: ["ok": true, "result": String(repeating: "x", count: 600_000)])
        let receipt = try XCTUnwrap(ledger.receipt(request.requestID))
        XCTAssertEqual(receipt["ok"] as? Bool, false)
        XCTAssertEqual((receipt["error"] as? [String: String])?["code"], "receipt_size_budget")
        XCTAssertNotNil(try ledger.claim(request))
        XCTAssertEqual(ledger.count, 1)
    }
    func testExplicitTargetsAndAliasesRequireSessionWhitelist() throws {
        let allowed: Set<String> = ["com.example.product"]
        let body: [String: Any] = ["app": "target", "operation": "typeText", "expectedBundle": "com.example.product", "text": "hello", "selector": ["kind": "identifier", "value": "input"]]
        XCTAssertEqual(try CrossAppRequest(body: body, allowedBundles: allowed).text, "hello")
        XCTAssertThrowsError(try CrossAppRequest(body: body, allowedBundles: []))
        XCTAssertThrowsError(try CrossAppRequest(body: ["app": "settings", "operation": "probe", "expectedBundle": "com.apple.Preferences"], allowedBundles: allowed))
        XCTAssertThrowsError(try CrossAppRequest(body: ["app": "target", "operation": "probe", "expectedBundle": "bad bundle"], allowedBundles: ["bad bundle"]))
    }
    func testConfigurationBindsWhitelistAndRejectsMalformedValues() throws {
        let base = ["TRITON_RUNNER_TOKEN": String(repeating: "t", count: 32), "TRITON_RUNNER_SESSION": "s"]
        var env = base
        env["TRITON_RUNNER_ALLOWED_BUNDLES"] = "com.example.app,com.apple.calculator"
        let config = try RunnerConfiguration(environment: env)
        XCTAssertEqual(config.allowedBundles, ["dev.tritonkit.runnerfixture", "com.example.app", "com.apple.calculator"])
        XCTAssertEqual(try RunnerConfiguration(environment: base).allowedBundles, ["dev.tritonkit.runnerfixture"])
        for value in ["com.app,", "com app", ".com.app", "com..app", String(repeating: "x", count: 256) + ".app"] {
            env["TRITON_RUNNER_ALLOWED_BUNDLES"] = value
            XCTAssertThrowsError(try RunnerConfiguration(environment: env))
        }
        XCTAssertThrowsError(try RunnerConfiguration(environment: [:]))
        for (key, value) in [("TRITON_RUNNER_PORT", "0"), ("TRITON_RUNNER_TTL", "nan"), ("TRITON_RUNNER_TTL", "3601")] {
            var invalid = base; invalid[key] = value
            XCTAssertThrowsError(try RunnerConfiguration(environment: invalid))
        }
    }
    func testScreenshotReservationsBoundTotalBytesWithoutEvictingIDs() throws {
        let ledger = RequestLedger()
        let one = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/crossApp", body: "{\"operation\":\"screenshot\"}", requestID: "s1")))
        let two = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/screenshot", requestID: "s2")))
        let three = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/screenshot", requestID: "s3")))
        XCTAssertNil(try ledger.claim(one)); XCTAssertNil(try ledger.claim(two))
        XCTAssertThrowsError(try ledger.claim(three)) { XCTAssertEqual(($0 as? ProtocolFailure)?.code, "receipt_byte_budget") }
        XCTAssertNotNil(try ledger.claim(one))
        XCTAssertLessThanOrEqual(ledger.cachedByteBudgetUsed, RequestLedger.maxCachedBytes)
        ledger.complete(requestID: "s1", envelope: ["ok": true, "result": "original"])
        ledger.complete(requestID: "s1", envelope: ["ok": false, "result": "replaced"])
        XCTAssertEqual(ledger.receipt("s1")?["result"] as? String, "original")
        XCTAssertNil(try ledger.claim(three))
    }
    func testReceiptCountNeverEvictsOlderAction() throws {
        let ledger = RequestLedger()
        for i in 0..<256 {
            let request = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/tap", requestID: "r\(i)")))
            XCTAssertNil(try ledger.claim(request))
            ledger.complete(requestID: request.requestID, envelope: ["ok": true])
        }
        let extra = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/tap", requestID: "extra")))
        XCTAssertThrowsError(try ledger.claim(extra))
        let first = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/tap", requestID: "r0")))
        XCTAssertNotNil(try ledger.claim(first))
    }
    private let token = "unit-secret"
    private let session = "unit-session"
    private func raw(_ method: String = "GET", _ path: String = "/health", body: String = "", token: String? = "unit-secret", session: String = "unit-session", requestID: String = "r1") -> Data {
        var text = "\(method) \(path) HTTP/1.1\r\nHost: localhost\r\nX-Session-ID: \(session)\r\nX-Request-ID: \(requestID)\r\nContent-Length: \(body.utf8.count)\r\n"
        if let token { text += "Authorization: Bearer \(token)\r\n" }
        return Data((text + "\r\n" + body).utf8)
    }
    func testFragmentedRequestWaitsForCompleteBody() throws {
        let data = raw("POST", "/tap", body: "{\"expectedCounter\":0}")
        let parser = BoundedHTTPParser()
        XCTAssertNil(try parser.append(data.prefix(data.count - 2)))
        let request = try XCTUnwrap(parser.append(data.suffix(2)))
        XCTAssertEqual(request.path, "/tap")
        XCTAssertEqual(try request.jsonBody()["expectedCounter"] as? Int, 0)
    }
    func testNoAuthenticationIsRejected() throws {
        let request = try XCTUnwrap(BoundedHTTPParser().append(raw(token: nil)))
        XCTAssertThrowsError(try request.validate(token: token, session: session)) { error in
            XCTAssertEqual((error as? ProtocolFailure)?.code, "unauthorized")
        }
    }
    func testWrongSessionAndMissingRequestIDAreRejected() throws {
        for data in [raw(session: "another"), raw(requestID: "")] {
            let request = try XCTUnwrap(BoundedHTTPParser().append(data))
            XCTAssertThrowsError(try request.validate(token: token, session: session))
        }
    }
    func testPayloadAndHeaderBudgetsAreEnforcedBeforeParsing() {
        XCTAssertThrowsError(try BoundedHTTPParser().append(Data("POST /tap HTTP/1.1\r\nContent-Length: 65537\r\n\r\n".utf8)))
        XCTAssertThrowsError(try BoundedHTTPParser().append(Data(repeating: 65, count: 16385)))
    }
    func testUnknownMethodPathAndTransferEncodingAreRejected() throws {
        for data in [raw("DELETE"), raw("GET", "/tap"), raw("POST", "/unknown")] {
            let request = try XCTUnwrap(BoundedHTTPParser().append(data))
            XCTAssertThrowsError(try request.validate(token: token, session: session))
        }
        XCTAssertThrowsError(try BoundedHTTPParser().append(Data("GET /health HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8))) { error in
            XCTAssertEqual((error as? ProtocolFailure)?.code, "unsupported_encoding")
        }
    }
    func testDuplicateTapReturnsSameReceiptAndConflictsAreRejected() throws {
        let ledger = RequestLedger()
        let request = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/tap", body: "{\"expectedCounter\":0}")))
        XCTAssertNil(try ledger.claim(request))
        let pending = try XCTUnwrap(ledger.claim(request))
        XCTAssertEqual(pending["status"] as? String, "pending")
        ledger.complete(requestID: request.requestID, envelope: ["ok": true, "result": ["counter": 1]])
        XCTAssertEqual(try ledger.claim(request)?["ok"] as? Bool, true)
        let conflicting = try XCTUnwrap(BoundedHTTPParser().append(raw("POST", "/tap", body: "{\"expectedCounter\":1}")))
        XCTAssertThrowsError(try ledger.claim(conflicting))
        XCTAssertEqual(ledger.count, 1)
    }
}
