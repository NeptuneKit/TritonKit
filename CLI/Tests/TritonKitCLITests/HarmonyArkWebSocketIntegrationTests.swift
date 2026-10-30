import Foundation
import Network
import Testing
@testable import TritonKitCLI

/// Actual loopback handshake and frames; no emulator/HDC or private page.
@Suite("ArkWeb CDP WebSocket wire contract", .serialized)
struct HarmonyArkWebSocketIntegrationTests {
    @Test("CDP uses text frames accepted by a text-only endpoint")
    func textFrames() async throws {
        let server = try SocketFixture()
        defer { server.stop() }
        let url = try await server.start()
        let session = HarmonyArkWebURLSessionCDPSession(url: url)
        do {
            #expect(try await session.evaluate(expression: "'fixture'", timeoutSeconds: 2) == "fixture")
            #expect(server.opcodes == [.text])
            await session.close()
        } catch {
            await session.close()
            throw error
        }
    }

    @Test("a peer disconnect is transport failure rather than page JavaScript")
    func disconnectedPeer() async throws {
        let server = try SocketFixture(disconnect: true)
        defer { server.stop() }
        let session = HarmonyArkWebURLSessionCDPSession(url: try await server.start())
        do {
            _ = try await session.evaluate(expression: "'fixture'", timeoutSeconds: 2)
            Issue.record("Expected transport failure")
        } catch let error as HarmonyArkWebBridgeCallError {
            #expect(error.code.rawValue == "webview_transport_error")
        } catch { Issue.record("Expected typed transport error, got \(error)") }
        await session.close()
    }
}

private final class SocketFixture: @unchecked Sendable {
    let listener: NWListener
    let queue = DispatchQueue(label: "triton.arkweb.fixture")
    let lock = NSLock()
    var connections: [NWConnection] = []
    var received: [NWProtocolWebSocket.Opcode] = []
    var failure: String?
    var ready = false
    let disconnect: Bool
    var opcodes: [NWProtocolWebSocket.Opcode] { lock.withLock { received } }

    init(disconnect: Bool = false) throws {
        self.disconnect = disconnect
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        listener = try NWListener(using: parameters)
    }

    func start() async throws -> URL {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.lock.withLock {
                if case .ready = state { self.ready = true }
                if case .failed(let error) = state { self.failure = String(describing: error) }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { connection.cancel(); return }
            self.lock.withLock { self.connections.append(connection) }
            connection.start(queue: self.queue)
            self.receive(connection)
        }
        listener.start(queue: queue)
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            let state = lock.withLock { (ready, failure) }
            if let failure = state.1 { throw RuntimeError(failure) }
            if state.0, let port = listener.port {
                return URL(string: "ws://127.0.0.1:\(port.rawValue)/devtools/page/fixture")!
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw RuntimeError("Loopback WebSocket fixture did not become ready")
    }

    func receive(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self, error == nil,
                  let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata else {
                connection.cancel(); return
            }
            self.lock.withLock { self.received.append(metadata.opcode) }
            guard !self.disconnect, metadata.opcode == .text, let data,
                  let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = request["id"] as? Int else {
                connection.cancel(); return
            }
            let response: [String: Any] = ["id": id, "result": ["result": ["type": "string", "value": "fixture"]]]
            let content = try! JSONSerialization.data(withJSONObject: response)
            let outgoing = NWProtocolWebSocket.Metadata(opcode: .text)
            let context = NWConnection.ContentContext(identifier: "fixture", metadata: [outgoing])
            connection.send(content: content, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
        }
    }

    func stop() {
        listener.cancel()
        lock.withLock { connections }.forEach { $0.cancel() }
    }
}
