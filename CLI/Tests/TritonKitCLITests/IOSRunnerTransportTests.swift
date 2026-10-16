import Foundation
import XCTest
@testable import TritonKitCLI

final class IOSRunnerTransportTests: XCTestCase {
    private let connection = IOSRunnerConnection(scope: "simulator", targetAddress: "127.0.0.1", port: 19439,
                                                  token: "private-token-for-tests", sessionID: "session-1")
    private func response(_ object: [String: Any], status: Int = 200, extra: String = "") throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return Data("HTTP/1.1 \(status) OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\(extra)\r\n".utf8) + body
    }
    private var success: [String: Any] { ["ok": true, "sessionID": "session-1", "requestID": "r1", "result": ["alive": true], "error": NSNull()] }

    func testRequestHeadersAndHealthMethod() throws {
        let request = try IOSRunnerWire.request(connection: connection, route: "health", body: nil, requestID: "r1")
        let text = try XCTUnwrap(String(data: request, encoding: .utf8))
        XCTAssertTrue(text.hasPrefix("GET /health HTTP/1.1\r\n"))
        XCTAssertFalse(text.contains("Authorization:"))
        XCTAssertFalse(text.contains(connection.token))
        XCTAssertTrue(text.contains("X-Session-ID: session-1\r\n"))
        XCTAssertTrue(text.contains("X-Request-ID: r1\r\n"))
    }

    func testHeaderInjectionAndUnboundedBodyRejected() {
        let unsafe = IOSRunnerConnection(scope: "real", targetAddress: "serial", port: 19439,
                                         token: "secret\r\nX-Evil: yes", sessionID: "session-1")
        XCTAssertThrowsError(try IOSRunnerWire.request(connection: unsafe, route: "health", body: nil, requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.request(connection: connection, route: "../health", body: nil, requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.request(connection: connection, route: "tap", body: Data(repeating: 0, count: 65537), requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.request(connection: connection, route: "tap", body: Data("{} {}".utf8), requestID: "r1"))
    }

    func testResponsePreservesBusinessFailureAndBindsRequest() throws {
        let wire = try IOSRunnerWire.parseHTTPResponse(response(success), sessionID: "session-1", requestID: "r1")
        XCTAssertTrue(wire.ok)
        XCTAssertEqual(wire.result?["alive"] as? Bool, true)
        let failure: [String: Any] = ["ok": false, "sessionID": "session-1", "requestID": "r1", "error": ["code": "cross_app_not_hittable", "retryable": true]]
        let rejected = try IOSRunnerWire.parseHTTPResponse(response(failure, status: 409), sessionID: "session-1", requestID: "r1")
        XCTAssertEqual(rejected.error?["code"] as? String, "cross_app_not_hittable")
        XCTAssertEqual(rejected.error?["retryable"] as? Bool, false)
        XCTAssertNoThrow(try rejected.serializedEnvelope())
    }

    func testResponseRejectsMismatchedSessionRequestStatusAndBoolean() throws {
        let raw = try response(success)
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(raw, sessionID: "other", requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(raw, sessionID: "session-1", requestID: "other"))
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(response(success, status: 500), sessionID: "session-1", requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(response(success, status: 302), sessionID: "session-1", requestID: "r1"))
        var numeric = success; numeric["ok"] = 1
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(response(numeric), sessionID: "session-1", requestID: "r1"))
    }

    func testHTTPFramingRejectsDuplicateLengthTransferEncodingAndTrailingData() throws {
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(response(success, extra: "Content-Length: 2\r\n"), sessionID: "session-1", requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(response(success, extra: "Transfer-Encoding: chunked\r\n"), sessionID: "session-1", requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(response(success) + Data("{}".utf8), sessionID: "session-1", requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(Data("HTTP/1.1 200 OK\r\nContent-Length: 12582913\r\n\r\n".utf8), sessionID: "session-1", requestID: "r1"))
        XCTAssertThrowsError(try IOSRunnerWire.parseHTTPResponse(Data("HTTP/1.1 200 OK\r\nX: \(String(repeating: "a", count: 17000))\r\n\r\n".utf8), sessionID: "session-1", requestID: "r1"))
    }

    func testMuxFramingAndPortNetworkByteOrder() throws {
        let frame = try IOSRunnerMux.frame(["MessageType": "Connect", "DeviceID": 7, "PortNumber": IOSRunnerMux.networkPort(19439)], tag: 2)
        let parsed = try IOSRunnerMux.parseFrame(frame, expectedTag: 2)
        XCTAssertEqual(parsed["MessageType"] as? String, "Connect")
        XCTAssertEqual(parsed["PortNumber"] as? Int, 61259)
        XCTAssertThrowsError(try IOSRunnerMux.parseFrame(frame, expectedTag: 3))
        var corrupt = frame; corrupt[4] = 2
        XCTAssertThrowsError(try IOSRunnerMux.parseFrame(corrupt, expectedTag: 2))
        XCTAssertThrowsError(try IOSRunnerMux.parseFrame(frame + Data([0]), expectedTag: 2))
    }

    func testMuxExactUSBIdentityAndAmbiguity() throws {
        let usb: [String: Any] = ["DeviceID": 7, "Properties": ["SerialNumber": "exact", "ConnectionType": "USB"]]
        let wifi: [String: Any] = ["DeviceID": 8, "Properties": ["SerialNumber": "exact", "ConnectionType": "Network"]]
        XCTAssertEqual(try IOSRunnerMux.selectUSBDevice([usb, wifi], serial: "exact"), 7)
        XCTAssertThrowsError(try IOSRunnerMux.selectUSBDevice([usb], serial: "exac"))
        XCTAssertThrowsError(try IOSRunnerMux.selectUSBDevice([usb, usb], serial: "exact"))
        XCTAssertThrowsError(try IOSRunnerMux.selectUSBDevice([["DeviceID": true, "Properties": ["SerialNumber": "exact", "ConnectionType": "USB"]]], serial: "exact"))
    }

    func testDeadlineUsesMonotonicTimeAndRejectsInvalidTimeout() throws {
        let deadline = try IOSRunnerDeadline(timeout: 2, now: 100)
        XCTAssertEqual(try deadline.remaining(now: 101), 1)
        XCTAssertThrowsError(try deadline.remaining(now: 102))
        XCTAssertThrowsError(try IOSRunnerDeadline(timeout: .infinity, now: 100))
        XCTAssertThrowsError(try IOSRunnerDeadline(timeout: 0, now: 100))
    }

    func testScreenshotSignatureSizeAndDimensionBudget() throws {
        // Wire validator checks framing/IHDR; the caller owns durable PNG writing.
        let png = Data([137,80,78,71,13,10,26,10, 0,0,0,13, 73,72,68,82,
                        0,0,0,2, 0,0,0,3, 8,6,0,0,0, 0,0,0,0])
        let shot = IOSRunnerWireResponse(envelope: ["ok": true, "result": ["pngBase64": png.base64EncodedString(), "byteCount": png.count]])
        XCTAssertEqual(try shot.decodedScreenshot(), png)
        XCTAssertThrowsError(try shot.decodedScreenshot(maxPixels: 5))
        let invalid = IOSRunnerWireResponse(envelope: ["ok": true, "result": ["pngBase64": "!!!!", "byteCount": 4]])
        XCTAssertThrowsError(try invalid.decodedScreenshot())
    }

    func testUnknownEnvelopeNeverLeaksCredentialsOrRetries() {
        let result = IOSRunnerTransport.exchange(connection: connection, route: "health", body: nil, requestID: "r1", timeout: 0)
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error?["code"] as? String, "ios_runner_transport_unknown")
        XCTAssertEqual(result.error?["retryable"] as? Bool, false)
        XCTAssertFalse(String(decoding: try! result.serializedEnvelope(), as: UTF8.self).contains("private-token"))
    }
}
