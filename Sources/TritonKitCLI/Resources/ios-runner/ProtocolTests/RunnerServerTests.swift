import XCTest
import Foundation
import CryptoKit
import Network
import Darwin
#if SWIFT_PACKAGE
@testable import RunnerProtocol
#endif

/// Every request below goes through the same NWListener, secure channel, HTTP
/// parser, router and UI queue that the bundled XCTest runner uses on iOS.
final class RunnerServerTests: XCTestCase {
    private let token = "0123456789abcdef0123456789abcdef"
    private let session = "route-session"
    private let routes = ["/health", "/receipt", "/probe", "/snapshot", "/screenshot", "/tap", "/home", "/activateFixture", "/crossApp", "/environment", "/stop"]
    private var uiRoutes: [String] { routes.filter { !["/health", "/receipt", "/stop"].contains($0) } }

    func testAllRealRoutesRejectWrongTokenBeforeExecutingUIOrStop() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        for route in routes {
            let response = try await exchange(port: port, bytes: request(route), invalidFrameToken: "wrong-token-0123456789abcdef")
            XCTAssertTrue(response.isEmpty, route)
            XCTAssertEqual(effects.count, 0, route)
            XCTAssertFalse(server.stopped, route)
        }
    }
    func testAllRealRoutesRejectWrongSessionBeforeExecutingUIOrStop() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        for route in routes {
            let response = try responseJSON(await exchange(port: port, bytes: request(route, boundSession: "another-session")))
            assertFailure(response, code: "session_mismatch", route: route)
            XCTAssertEqual(effects.count, 0, route)
            XCTAssertFalse(server.stopped, route)
        }
    }
    func testAllRealRoutesRejectWrongMethodBeforeExecutingUIOrStop() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        for route in routes {
            let response = try responseJSON(await exchange(port: port, bytes: request(route, method: "DELETE")))
            assertFailure(response, code: "route_rejected", route: route)
            XCTAssertEqual(effects.count, 0, route)
            XCTAssertFalse(server.stopped, route)
        }
    }
    func testAllExpiredRealRoutesCannotExecuteUIOrStop() async throws {
        let clock = TestClock(); let effects = Effects()
        let server = try makeServer(clock: clock, effects: effects)
        let port = await start(server); defer { server.stop() }
        clock.advance(300) // The exact TTL boundary is expired.
        for route in routes {
            let response = try responseJSON(await exchange(port: port, bytes: request(route)))
            assertFailure(response, code: "session_expired", route: route)
            XCTAssertEqual(effects.count, 0, route)
            XCTAssertFalse(server.stopped, route)
        }
    }
    func testValidControlRequestsReachEveryRealRouteAndStop() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        for route in routes {
            let response = try responseJSON(await exchange(port: port, bytes: request(route)))
            XCTAssertEqual(response["ok"] as? Bool, true, route)
            XCTAssertEqual(response["sessionID"] as? String, session, route)
            let result = try XCTUnwrap(response["result"] as? [String: Any])
            switch route {
            case "/health": XCTAssertEqual(result["listenerReady"] as? Bool, true)
            case "/receipt": XCTAssertEqual(result["found"] as? Bool, false)
            case "/stop": XCTAssertEqual(result["stopping"] as? Bool, true)
            default: XCTAssertEqual(result["executed"] as? String, route)
            }
        }
        XCTAssertEqual(effects.recordedPaths, uiRoutes)
        // The completion callback cancels before publishing stop; await its queue.
        for _ in 0..<100 where !server.stopped { try await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertTrue(server.stopped)
    }
    func testEveryUIRouteRechecksSessionExpiryAfterQueueing() async throws {
        for route in uiRoutes {
            let clock = TestClock(); let effects = Effects()
            let server = try makeServer(clock: clock, effects: effects, queuedAdvance: 300)
            let port = await start(server); defer { server.stop() }
            let response = try responseJSON(await exchange(port: port, bytes: request(route)))
            assertFailure(response, code: "session_expired", route: route)
            XCTAssertEqual(effects.count, 0, route)
        }
    }
    func testUIQueueUsesOriginalConnectionDeadline() async throws {
        let clock = TestClock(); let effects = Effects()
        let server = try makeServer(clock: clock, effects: effects, queuedAdvance: 20)
        let port = await start(server); defer { server.stop() }
        let response = try responseJSON(await exchange(port: port, bytes: request("/tap")))
        assertFailure(response, code: "request_expired", route: "/tap")
        XCTAssertEqual(effects.count, 0)
    }
    func testLegacyPlaintextAndTamperedFramesCannotExecuteUIOrStop() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        for route in routes {
            let bytes = try request(route)
            let plaintext = try await exchange(port: port, bytes: bytes, plaintext: true)
            XCTAssertTrue(plaintext.isEmpty, route)
            let tampered = try await exchange(port: port, bytes: bytes, tamper: true)
            XCTAssertTrue(tampered.isEmpty, route)
            XCTAssertEqual(effects.count, 0, route)
            XCTAssertFalse(server.stopped, route)
        }
    }
    func testFragmentedHandshakeAndFrameReachTheRealRouter() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        let response = try responseJSON(await exchange(port: port, bytes: request("/tap"), fragmented: true))
        XCTAssertEqual(response["ok"] as? Bool, true)
        XCTAssertEqual(effects.recordedPaths, ["/tap"])
    }
    func testDuplicatesReturnReceiptWithoutReexecutingAndConflictsFailClosed() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        let first = try request("/tap", requestID: "one-action")
        let firstResponse = try responseJSON(await exchange(port: port, bytes: first))
        let duplicate = try responseJSON(await exchange(port: port, bytes: first))
        XCTAssertEqual(firstResponse["ok"] as? Bool, true)
        XCTAssertEqual(duplicate["ok"] as? Bool, true)
        let conflict = try responseJSON(await exchange(port: port, bytes: request("/home", requestID: "one-action")))
        assertFailure(conflict, code: "request_id_conflict", route: "/home")
        XCTAssertEqual(effects.recordedPaths, ["/tap"])
    }
    func testOnlyOneFrameIsConsumedPerConnectionAndCrossConnectionReplayFails() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        let recorder = FrameRecorder()
        let response = try responseJSON(await exchange(port: port, bytes: request("/tap"), duplicateFrame: true, recorder: recorder))
        XCTAssertEqual(response["ok"] as? Bool, true)
        XCTAssertEqual(effects.recordedPaths, ["/tap"])
        let replay = try await exchange(port: port, bytes: request("/home"), replayedFrame: try XCTUnwrap(recorder.frame))
        XCTAssertTrue(replay.isEmpty)
        XCTAssertEqual(effects.recordedPaths, ["/tap"])
        XCTAssertFalse(server.stopped)
    }
    func testBundleAllowlistIsCheckedBeforeUIExecution() async throws {
        let effects = Effects(); let server = try makeServer(effects: effects)
        let port = await start(server); defer { server.stop() }
        let response = try responseJSON(await exchange(port: port, bytes: request("/crossApp", body: ["app": "target", "expectedBundle": "com.example.unapproved", "operation": "activate"])))
        assertFailure(response, code: "cross_app_binding", route: "/crossApp")
        XCTAssertEqual(effects.count, 0)
    }

    private func assertFailure(_ response: [String: Any], code: String, route: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(response["ok"] as? Bool, false, route, file: file, line: line)
        XCTAssertEqual((response["error"] as? [String: Any])?["code"] as? String, code, route, file: file, line: line)
    }
    private func makeServer(clock: TestClock = TestClock(), effects: Effects, queuedAdvance: TimeInterval = 0) throws -> IOSRunnerServer {
        let config = try RunnerConfiguration(environment: ["TRITON_RUNNER_TOKEN": token, "TRITON_RUNNER_SESSION": session])
        return try IOSRunnerServer(config: config, port: .any, now: { clock.read() }, scheduleUI: { work in
            clock.advance(queuedAdvance)
            DispatchQueue.main.async(execute: work)
        }, perform: { path, _ in effects.record(path); return ["executed": path] })
    }
    private func start(_ server: IOSRunnerServer) async -> UInt16 {
        await withCheckedContinuation { continuation in server.start { continuation.resume(returning: $0) } }
    }
    private func request(_ path: String, method: String? = nil, boundSession: String? = nil, requestID: String = UUID().uuidString, body: [String: Any]? = nil) throws -> Data {
        let defaults: [String: [String: Any]] = ["/tap": ["expectedCounter": 0], "/receipt": ["actionRequestID": "absent"], "/environment": ["operation": "foreground"], "/crossApp": ["app": "fixture", "expectedBundle": "dev.tritonkit.runnerfixture", "operation": "probe"]]
        let json = try JSONSerialization.data(withJSONObject: body ?? defaults[path] ?? [:])
        let header = "\(method ?? (path == "/health" ? "GET" : "POST")) \(path) HTTP/1.1\r\nHost: localhost\r\nX-Session-ID: \(boundSession ?? session)\r\nX-Request-ID: \(requestID)\r\nContent-Length: \(json.count)\r\n\r\n"
        return Data(header.utf8) + json
    }
    private func responseJSON(_ bytes: Data) throws -> [String: Any] {
        let delimiter = try XCTUnwrap(bytes.range(of: Data("\r\n\r\n".utf8)))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: bytes.suffix(from: delimiter.upperBound)) as? [String: Any])
    }
    // Adversarial client fixture bypasses only proof verification. Use CryptoKit
    // primitives with the genuine transcript to test the server's key check.
    private static func unverifiedClientFrame(token: String, session: String, hello: Data, proof: Data, plaintext: Data) throws -> Data {
        func length(_ count: Int) -> Data {
            let n = UInt32(count)
            return Data([UInt8(truncatingIfNeeded: n >> 24), UInt8(truncatingIfNeeded: n >> 16), UInt8(truncatingIfNeeded: n >> 8), UInt8(truncatingIfNeeded: n)])
        }
        let nonce = Data(proof[8..<40])
        let transcript = Data("TritonRunner/v2/server-proof\0".utf8) + length(session.utf8.count) + Data(session.utf8) + hello + nonce
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(token.utf8)), salt: hello + nonce,
            info: Data("TritonRunner/v2/request-key\0".utf8) + transcript, outputByteCount: 32)
        let sealed = try XCTUnwrap(AES.GCM.seal(plaintext, using: key, authenticating: transcript + Data("request".utf8)).combined)
        return length(sealed.count) + sealed
    }
    private func exchange(port: UInt16, bytes: Data, invalidFrameToken: String? = nil, plaintext: Bool = false, tamper: Bool = false, fragmented: Bool = false, duplicateFrame: Bool = false, recorder: FrameRecorder? = nil, replayedFrame: Data? = nil) async throws -> Data {
        let token = token; let session = session
        return try await Task.detached {
            let socket = try TestSocket(port: port)
            if plaintext {
                try socket.send(bytes)
                return try socket.readToEOF()
            }
            let hello = RunnerSecureChannel.clientHello()
            try socket.send(hello, fragmented: fragmented)
            let proof = try socket.readExactly(RunnerSecureChannel.proofSize)
            let channel = try RunnerSecureChannel.client(token: token, session: session, hello: hello, proof: proof)
            var frame: Data
            if let invalidFrameToken {
                XCTAssertThrowsError(try RunnerSecureChannel.client(token: invalidFrameToken, session: session, hello: hello, proof: proof))
                // Hold the real client/server nonces and session fixed. The only
                // changed variable is the secret, not a fresh server transcript.
                let control = try Self.unverifiedClientFrame(token: token, session: session, hello: hello, proof: proof, plaintext: bytes)
                XCTAssertEqual(try channel.openRequest(control), bytes)
                frame = try Self.unverifiedClientFrame(token: invalidFrameToken, session: session, hello: hello, proof: proof, plaintext: bytes)
            } else {
                frame = try replayedFrame ?? channel.sealRequest(bytes)
            }
            recorder?.save(frame)
            if tamper { frame[frame.count - 1] ^= 1 }
            try socket.send(duplicateFrame ? frame + frame : frame, fragmented: fragmented)
            let response = try socket.readToEOF()
            if response.isEmpty { return response }
            return try channel.openResponse(response)
        }.value
    }
}
private struct SocketFailure: Error { let operation: String; let code: Int32 }
private final class TestSocket {
    private let fd: Int32
    init(port: UInt16) throws {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketFailure(operation: "socket", code: errno) }
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        var noSignal: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let result = withUnsafePointer(to: &address) { pointer in pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard result == 0 else { let code = errno; close(fd); throw SocketFailure(operation: "connect", code: code) }
    }
    deinit { close(fd) }
    func send(_ bytes: Data, fragmented: Bool = false) throws {
        var offset = 0
        while offset < bytes.count {
            let length = fragmented ? min(7, bytes.count - offset) : bytes.count - offset
            let sent = bytes.withUnsafeBytes { Darwin.send(fd, $0.baseAddress!.advanced(by: offset), length, 0) }
            guard sent > 0 else { throw SocketFailure(operation: "send", code: errno) }; offset += sent
        }
    }
    func readExactly(_ length: Int) throws -> Data {
        var output = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
        while output.count < length {
            let count = recv(fd, &buffer, min(buffer.count, length - output.count), 0)
            guard count > 0 else { throw SocketFailure(operation: "receive exact", code: errno) }
            output.append(contentsOf: buffer.prefix(count))
        }
        return output
    }
    func readToEOF() throws -> Data {
        var output = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count < 0, errno == ECONNRESET { return output }
            guard count >= 0 else { throw SocketFailure(operation: "receive", code: errno) }
            if count == 0 { return output }
            output.append(contentsOf: buffer.prefix(count))
            guard output.count <= RunnerSecureChannel.maximumResponseBytes + 32 else { throw SocketFailure(operation: "response budget", code: 0) }
        }
    }
}
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock(); private var value: TimeInterval = 100
    func read() -> TimeInterval { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ delta: TimeInterval) { lock.lock(); defer { lock.unlock() }; value += delta }
}
private final class Effects: @unchecked Sendable {
    private let lock = NSLock(); private var paths: [String] = []
    var count: Int { lock.lock(); defer { lock.unlock() }; return paths.count }
    var recordedPaths: [String] { lock.lock(); defer { lock.unlock() }; return paths }
    func record(_ path: String) { lock.lock(); defer { lock.unlock() }; paths.append(path) }
}

private final class FrameRecorder: @unchecked Sendable {
    private let lock = NSLock(); private var storage: Data?
    var frame: Data? { lock.lock(); defer { lock.unlock() }; return storage }
    func save(_ value: Data) { lock.lock(); defer { lock.unlock() }; storage = value }
}
