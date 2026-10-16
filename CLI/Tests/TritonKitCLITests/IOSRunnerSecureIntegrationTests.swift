import Foundation
import Darwin
import Network
import XCTest
@testable import TritonKitCLI
@testable import RunnerProtocol

final class IOSRunnerSecureIntegrationTests: XCTestCase {
    private let secret = String(repeating: "ab", count: 32)
    private func configuration() throws -> RunnerConfiguration {
        try RunnerConfiguration(environment: ["TRITON_RUNNER_TOKEN": secret, "TRITON_RUNNER_SESSION": "integration-session", "TRITON_RUNNER_TTL": "10"])
    }
    private func exchange(port: UInt16, route: String, body: String? = nil, id: String = UUID().uuidString, token: String? = nil, session: String = "integration-session") -> IOSRunnerWireResponse {
        let done = expectation(description: "CLI transport exchange")
        let connection = IOSRunnerConnection(scope: "simulator", targetAddress: "127.0.0.1", port: port, token: token ?? secret, sessionID: session)
        var result: IOSRunnerWireResponse!
        DispatchQueue(label: "runner-cli-integration").async {
            result = IOSRunnerTransport.exchange(connection: connection, route: route, body: body.map { Data($0.utf8) }, requestID: id, timeout: 3)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return result
    }
    private func start(_ server: IOSRunnerServer) -> UInt16 {
        let ready = expectation(description: "bound ephemeral server")
        var port: UInt16 = 0
        server.start { actual in port = actual; ready.fulfill() }
        wait(for: [ready], timeout: 3)
        return port
    }

    func testCLIExchangeUsesShippedServerAndRetainsReceiptsAndBusinessErrors() throws {
        var performed = 0
        let server = try IOSRunnerServer(config: configuration(), port: .any) { path, _ in
            performed += 1
            if path == "/tap" { return ["counter": performed] }
            throw ProtocolFailure("fixture_not_foreground", "Rejected by UI fixture", status: 409)
        }
        defer { server.stop() }
        let port = start(server)
        XCTAssertTrue(exchange(port: port, route: "health").ok)
        let first = exchange(port: port, route: "tap", body: "{\"expectedCounter\":0}", id: "tap-1")
        XCTAssertTrue(first.ok); XCTAssertEqual(first.result?["counter"] as? Int, 1)
        let duplicate = exchange(port: port, route: "tap", body: "{\"expectedCounter\":0}", id: "tap-1")
        XCTAssertTrue(duplicate.ok); XCTAssertEqual(performed, 1)
        let receipt = exchange(port: port, route: "receipt", body: "{\"actionRequestID\":\"tap-1\"}")
        XCTAssertEqual(receipt.result?["found"] as? Bool, true)
        let rejected = exchange(port: port, route: "snapshot", body: "{}")
        XCTAssertFalse(rejected.ok)
        XCTAssertEqual(rejected.error?["code"] as? String, "fixture_not_foreground")
        XCTAssertEqual(rejected.error?["retryable"] as? Bool, false)
        XCTAssertTrue(exchange(port: port, route: "stop", body: "{}").ok)
    }

    func testCLICannotReachUIWithWrongSecretSessionOrExpiredServer() throws {
        let clock = RunnerIntegrationClock()
        var performed = 0
        let server = try IOSRunnerServer(config: configuration(), port: .any, now: { clock.read() }) { _, _ in
            performed += 1; return [:]
        }
        defer { server.stop() }
        let port = start(server)
        for response in [exchange(port: port, route: "tap", body: "{}", token: String(repeating: "cd", count: 32)),
                         exchange(port: port, route: "tap", body: "{}", session: "another-session")] {
            XCTAssertFalse(response.ok)
            XCTAssertEqual(response.error?["cause"] as? String, "authentication_server_unverified")
            XCTAssertEqual(response.error?["retryable"] as? Bool, false)
        }
        clock.advance(11)
        let expired = exchange(port: port, route: "tap", body: "{}")
        XCTAssertFalse(expired.ok)
        XCTAssertEqual(expired.error?["code"] as? String, "session_expired")
        XCTAssertEqual(performed, 0)
    }

    func testCLIExchangeRejectsAuthenticatedResponsesBoundToAnotherRequestOrSession() throws {
        // The proof and AEAD are valid in every case. Only the encrypted response
        // identity changes, so rejection must occur in the production exchange.
        let control = try authenticatedListenerExchange()
        XCTAssertTrue(control.response.ok)
        for (session, requestID, cause) in [
            ("another-session", "bound-request", "session_mismatch"),
            ("integration-session", "another-request", "request_mismatch"),
        ] {
            let result = try authenticatedListenerExchange(responseSession: session, responseRequestID: requestID)
            XCTAssertFalse(result.response.ok)
            XCTAssertEqual(result.response.error?["cause"] as? String, cause)
            XCTAssertEqual(result.response.error?["delivery"] as? String, "unknown")
            XCTAssertEqual(result.response.error?["retryable"] as? Bool, false)
        }
    }

    func testCLIExchangeSharesOneDeadlineAcrossHandshakeAndEncryptedResponse() throws {
        // Each delay fits inside 1.3 seconds; their sum does not. A per-phase
        // timeout reset would accept this response. First prove the same exchange
        // succeeds with a sufficient total budget.
        let control = try authenticatedListenerExchange(proofDelay: 0.8, responseDelay: 0.8, timeout: 4)
        XCTAssertTrue(control.response.ok)
        let expired = try authenticatedListenerExchange(proofDelay: 0.8, responseDelay: 0.8, timeout: 1.3)
        XCTAssertFalse(expired.response.ok)
        XCTAssertEqual(expired.response.error?["cause"] as? String, "deadline_exceeded")
        XCTAssertEqual(expired.response.error?["retryable"] as? Bool, false)
        XCTAssertLessThan(expired.elapsed, 2.5, "The client must not consume a fresh timeout for each stage")
    }

    private func authenticatedListenerExchange(responseSession: String = "integration-session", responseRequestID: String = "bound-request", proofDelay: Double = 0, responseDelay: Double = 0, timeout: Double = 3) throws -> (response: IOSRunnerWireResponse, elapsed: Double) {
        let listener = try RunnerAuthenticatedSocketFixture()
        let finished = expectation(description: "authenticated listener completed")
        let token = secret
        DispatchQueue(label: "runner-authenticated-response-fixture").async {
            defer { finished.fulfill() }
            do {
                let client = try listener.acceptClient()
                defer { Darwin.close(client) }
                let hello = try RunnerAuthenticatedSocketFixture.readExactly(RunnerProtocol.RunnerSecureChannel.helloSize, from: client)
                let channel = try RunnerProtocol.RunnerSecureChannel.server(token: token, session: "integration-session", hello: hello)
                Thread.sleep(forTimeInterval: proofDelay)
                try RunnerAuthenticatedSocketFixture.write(channel.proof, to: client)
                let header = try RunnerAuthenticatedSocketFixture.readExactly(4, from: client)
                let length = try RunnerProtocol.RunnerSecureChannel.frameLength(header, maximumPlaintext: RunnerProtocol.RunnerSecureChannel.maximumRequestBytes)
                let plaintext = try channel.openRequest(header + RunnerAuthenticatedSocketFixture.readExactly(length, from: client))
                let request = String(decoding: plaintext, as: UTF8.self)
                XCTAssertTrue(request.hasPrefix("GET /health HTTP/1.1\r\n"))
                XCTAssertTrue(request.contains("X-Request-ID: bound-request\r\n"))
                XCTAssertTrue(request.contains("X-Session-ID: integration-session\r\n"))
                let body = try JSONSerialization.data(withJSONObject: ["ok": true, "sessionID": responseSession,
                    "requestID": responseRequestID, "result": ["listenerReady": true], "error": NSNull()])
                let response = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n".utf8) + body
                let encrypted = try channel.sealResponse(response)
                Thread.sleep(forTimeInterval: responseDelay)
                // A timed-out client may already have closed; that is expected.
                try? RunnerAuthenticatedSocketFixture.write(encrypted, to: client)
            } catch { XCTFail("Authenticated listener did not complete its request stage: \(error)") }
        }
        let connection = IOSRunnerConnection(scope: "simulator", targetAddress: "127.0.0.1", port: listener.port,
            token: token, sessionID: "integration-session")
        let started = ProcessInfo.processInfo.systemUptime
        let response = IOSRunnerTransport.exchange(connection: connection, route: "health", body: nil, requestID: "bound-request", timeout: timeout)
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        wait(for: [finished], timeout: 6)
        return (response, elapsed)
    }
}

/// Keeps port zero bound until the exchange ends; never reserves and releases a port.
private final class RunnerAuthenticatedSocketFixture {
    private let fd: Int32
    let port: UInt16
    private struct Failure: Error { let operation: String; let code: Int32 }

    init() throws {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw Failure(operation: "socket", code: errno) }
        do {
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
            let bound = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard bound == 0, Darwin.listen(descriptor, 1) == 0 else { throw Failure(operation: "bind/listen", code: errno) }
            var size = socklen_t(MemoryLayout<sockaddr_in>.size)
            let named = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &size) }
            }
            guard named == 0 else { throw Failure(operation: "getsockname", code: errno) }
            fd = descriptor; port = UInt16(bigEndian: address.sin_port)
        } catch { Darwin.close(descriptor); throw error }
    }
    deinit { Darwin.close(fd) }
    func acceptClient() throws -> Int32 {
        var readiness = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        guard Darwin.poll(&readiness, 1, 3000) > 0 else { throw Failure(operation: "accept deadline", code: errno) }
        let client = Darwin.accept(fd, nil, nil)
        guard client >= 0 else { throw Failure(operation: "accept", code: errno) }
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        var noSignal: Int32 = 1
        guard setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0,
              setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0,
              setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal))) == 0 else {
            let code = errno; Darwin.close(client); throw Failure(operation: "socket options", code: code)
        }
        return client
    }
    static func readExactly(_ count: Int, from fd: Int32) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while result.count < count {
            let received = Darwin.recv(fd, &buffer, min(buffer.count, count - result.count), 0)
            if received < 0, errno == EINTR { continue }
            guard received > 0 else { throw Failure(operation: "receive", code: errno) }
            result.append(contentsOf: buffer.prefix(received))
        }
        return result
    }
    static func write(_ bytes: Data, to fd: Int32) throws {
        try bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < bytes.count {
                let sent = Darwin.send(fd, buffer.baseAddress!.advanced(by: offset), bytes.count - offset, 0)
                if sent < 0, errno == EINTR { continue }
                guard sent > 0 else { throw Failure(operation: "send", code: errno) }
                offset += sent
            }
        }
    }
}

private final class RunnerIntegrationClock {
    private let lock = NSLock()
    private var time: Double = 100
    func read() -> Double { lock.lock(); defer { lock.unlock() }; return time }
    func advance(_ delta: Double) { lock.lock(); time += delta; lock.unlock() }
}
