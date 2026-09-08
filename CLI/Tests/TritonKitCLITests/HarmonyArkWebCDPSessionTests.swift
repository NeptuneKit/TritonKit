import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Harmony ArkWeb real CDP protocol handling")
struct HarmonyArkWebCDPSessionTests {
    final class Transport: HarmonyArkWebCDPTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var responses: [String]
        private var cancelled = 0
        private let receiveDelay: UInt64
        init(_ responses: [String], receiveDelay: UInt64 = 1_000_000) { self.responses = responses; self.receiveDelay = receiveDelay }
        func sendMessage(_ data: Data) async throws {}
        func receiveMessage() async throws -> Data {
            try await Task.sleep(nanoseconds: receiveDelay)
            return lock.withLock {
                Data((responses.isEmpty ? #"{"method":"Runtime.consoleAPICalled","params":{}}"# : responses.removeFirst()).utf8)
            }
        }
        func cancelTransport() { lock.withLock { cancelled += 1 } }
        var cancelCount: Int { lock.withLock { cancelled } }
    }

    @Test("events and unrelated ids are skipped before the matching response")
    func eventRouting() async throws {
        let transport = Transport([
            #"{"method":"Runtime.executionContextCreated","params":{}}"#,
            #"{"id":42,"result":{"result":{"type":"string","value":"wrong"}}}"#,
            #"{"id":1,"result":{"result":{"type":"string","value":"ok"}}}"#,
        ])
        let session = HarmonyArkWebURLSessionCDPSession(transport: transport)
        #expect(try await session.evaluate(expression: "fixture", timeoutSeconds: 1) == "ok")
        await session.close()
        #expect(transport.cancelCount == 1)
    }

    @Test("nested exceptionDetails and protocol errors are immediate typed errors", arguments: [
        #"{"id":1,"result":{"result":{"type":"object","subtype":"error"},"exceptionDetails":{"text":"Uncaught fixture failure"}}}"#,
        #"{"id":1,"error":{"code":-32601,"message":"Method not found"}}"#,
        #"{"id":1,"result":{}}"#,
    ])
    func protocolErrors(payload: String) async {
        let session = HarmonyArkWebURLSessionCDPSession(transport: Transport([payload]))
        do {
            _ = try await session.evaluate(expression: "fixture", timeoutSeconds: 1)
            Issue.record("Expected javascript_error")
        } catch let error as HarmonyArkWebBridgeCallError {
            #expect(error.code.rawValue == "javascript_error")
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test("continuous events cannot extend the evaluate deadline")
    func absoluteDeadline() async {
        let transport = Transport([])
        let session = HarmonyArkWebURLSessionCDPSession(transport: transport)
        let started = Date()
        do {
            _ = try await session.evaluate(expression: "fixture", timeoutSeconds: 0.03)
            Issue.record("Expected bridge timeout")
        } catch let error as HarmonyArkWebBridgeCallError {
            #expect(error.code.rawValue == "webview_bridge_timeout")
            #expect(Date().timeIntervalSince(started) < 1)
            #expect(transport.cancelCount >= 1)
        } catch { Issue.record("Unexpected error: \(error)") }
    }
    @Test("a stalled receive is cancelled when the deadline expires")
    func stalledReceiveIsBounded() async {
        let transport = Transport([], receiveDelay: 10_000_000_000)
        let session = HarmonyArkWebURLSessionCDPSession(transport: transport)
        let started = Date()
        do {
            _ = try await session.evaluate(expression: "fixture", timeoutSeconds: 0.03)
            Issue.record("Expected timeout")
        } catch let error as HarmonyArkWebBridgeCallError {
            #expect(error.code.rawValue == "webview_bridge_timeout")
            #expect(Date().timeIntervalSince(started) < 1)
            #expect(transport.cancelCount >= 1)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

}
