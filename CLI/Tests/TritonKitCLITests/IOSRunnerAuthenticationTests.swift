import Foundation
import Darwin
import XCTest
@testable import TritonKitCLI

final class IOSRunnerAuthenticationTests: XCTestCase {
    private let token = String(repeating: "ab", count: 32)
    func testServiceProofBindsSessionBothNoncesAndRole() throws {
        let hello = RunnerSecureChannel.clientHello()
        let server = try RunnerSecureChannel.server(token: token, session: "s", hello: hello)
        XCTAssertNoThrow(try RunnerSecureChannel.client(token: token, session: "s", hello: hello, proof: server.proof))
        XCTAssertThrowsError(try RunnerSecureChannel.client(token: token, session: "other", hello: hello, proof: server.proof))
        XCTAssertThrowsError(try RunnerSecureChannel.client(token: String(repeating: "cd", count: 32), session: "s", hello: hello, proof: server.proof))
        XCTAssertThrowsError(try RunnerSecureChannel.client(token: token, session: "s", hello: RunnerSecureChannel.clientHello(), proof: server.proof))
        var altered = server.proof; altered[10] ^= 1
        XCTAssertThrowsError(try RunnerSecureChannel.client(token: token, session: "s", hello: hello, proof: altered))
        altered = server.proof; altered[71] ^= 1
        XCTAssertThrowsError(try RunnerSecureChannel.client(token: token, session: "s", hello: hello, proof: altered))
        XCTAssertThrowsError(try RunnerSecureChannel.server(token: token, session: "s", hello: Data("GET /health HTTP/1.1".utf8)))
    }

    func testEncryptedRecordsRejectTamperingReflectionAndCrossConnectionReplay() throws {
        let hello = RunnerSecureChannel.clientHello()
        let server = try RunnerSecureChannel.server(token: token, session: "s", hello: hello)
        let client = try RunnerSecureChannel.client(token: token, session: "s", hello: hello, proof: server.proof)
        let plaintext = Data("POST /tap HTTP/1.1\r\nContent-Length: 2\r\n\r\n{}".utf8)
        let request = try client.sealRequest(plaintext)
        XCTAssertEqual(try server.openRequest(request), plaintext)
        XCTAssertNil(request.range(of: plaintext))
        XCTAssertThrowsError(try client.openResponse(request))
        let reply = Data("HTTP/1.1 200 OK\r\n\r\n{\"ok\":true}".utf8)
        let response = try server.sealResponse(reply)
        XCTAssertEqual(try client.openResponse(response), reply)
        XCTAssertThrowsError(try server.openRequest(response))
        for index in [4, request.count - 1] {
            var corrupted = request; corrupted[index] ^= 1
            XCTAssertThrowsError(try server.openRequest(corrupted))
        }
        var corrupted = response; corrupted[response.count - 1] ^= 1
        XCTAssertThrowsError(try client.openResponse(corrupted))
        let replacement = try RunnerSecureChannel.server(token: token, session: "s", hello: hello)
        XCTAssertNotEqual(replacement.proof, server.proof)
        XCTAssertThrowsError(try replacement.openRequest(request))
        XCTAssertThrowsError(try replacement.openResponse(response))
        XCTAssertThrowsError(try server.openRequest(request + Data([0])))
        XCTAssertThrowsError(try server.openRequest(Data(request.dropLast())))
    }

    func testRecordBudgetsAreValidatedBeforeAllocation() throws {
        XCTAssertThrowsError(try RunnerSecureChannel.frameLength(Data([255, 255, 255, 255]), maximumPlaintext: 100))
        XCTAssertThrowsError(try RunnerSecureChannel.frameLength(Data([0, 0, 0, 27]), maximumPlaintext: 100))
        XCTAssertEqual(try RunnerSecureChannel.frameLength(Data([0, 0, 0, 28]), maximumPlaintext: 100), 28)
        let server = try RunnerSecureChannel.server(token: token, session: "s", hello: RunnerSecureChannel.clientHello())
        XCTAssertThrowsError(try server.sealRequest(Data(repeating: 1, count: RunnerSecureChannel.maximumRequestBytes + 1)))
    }

    // Port 0 remains bound throughout the fixture: never reserve then release.
    func testMaliciousListenerCannotCaptureCredentialOrForgeReady() throws {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(listener, 0)
        defer { Darwin.close(listener) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        XCTAssertEqual(bound, 0); XCTAssertEqual(listen(listener, 1), 0)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &length) }
        }
        let token = String(repeating: "ab", count: 32)
        let connection = IOSRunnerConnection(scope: "simulator", targetAddress: "127.0.0.1", port: UInt16(bigEndian: address.sin_port), token: token, sessionID: "session-1")
        let completed = expectation(description: "single exchange")
        DispatchQueue(label: "runner-auth-test-client").async {
            let response = IOSRunnerTransport.exchange(connection: connection, route: "health", body: nil, requestID: "r1", timeout: 5)
            XCTAssertFalse(response.ok, "Echo identifiers are not server authentication")
            XCTAssertEqual(response.error?["retryable"] as? Bool, false)
            completed.fulfill()
        }
        var ready = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
        guard poll(&ready, 1, 2000) > 0 else { return XCTFail("client did not connect") }
        let client = accept(listener, nil, nil)
        XCTAssertGreaterThanOrEqual(client, 0)
        defer { Darwin.close(client) }
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        _ = setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var bytes = [UInt8](repeating: 0, count: 4096)
        let count = recv(client, &bytes, bytes.count, 0)
        XCTAssertGreaterThan(count, 0)
        let captured = Data(bytes.prefix(max(0, count)))
        XCTAssertNil(captured.range(of: Data(token.utf8)), "Must not disclose reusable session credential")
        XCTAssertNil(captured.range(of: Data("Bearer ".utf8)))
        let body = Data("{\"ok\":true,\"sessionID\":\"session-1\",\"requestID\":\"r1\",\"result\":{\"listenerReady\":true}}".utf8)
        let echo = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n".utf8) + body
        _ = echo.withUnsafeBytes { send(client, $0.baseAddress, $0.count, 0) }
        wait(for: [completed], timeout: 7)
        ready.revents = 0
        XCTAssertEqual(poll(&ready, 1, 20), 0, "Unknown delivery must not reconnect or retry")
    }
}
