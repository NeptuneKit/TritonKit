import Foundation
import Testing
import XPC
@testable import TritonKitCLI

/// A Triton-owned anonymous local peer; no launchd service, framework or device.
private final class AnonymousHIDPeer {
    enum Mode { case reply, silent, delayed }
    let listener: xpc_connection_t
    let received = DispatchSemaphore(value: 0)
    let replied = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var peers: [xpc_connection_t] = []
    private var messages: [String] = []
    var types: [String] { lock.lock(); defer { lock.unlock() }; return messages }

    init(mode: Mode) {
        let queue = DispatchQueue(label: "triton.tests.dtuhid.peer")
        listener = xpc_connection_create(nil, queue)
        xpc_connection_set_event_handler(listener) { [weak self] object in
            guard xpc_get_type(object) == XPC_TYPE_CONNECTION, let self else { return }
            let peer = object
            self.lock.lock(); self.peers.append(peer); self.lock.unlock()
            xpc_connection_set_event_handler(peer) { [weak self] event in
                guard xpc_get_type(event) == XPC_TYPE_DICTIONARY, let self else { return }
                let type = xpc_dictionary_get_string(event, "messageType").map { String(cString: $0) } ?? "invalid"
                self.lock.lock(); self.messages.append(type); self.lock.unlock()
                self.received.signal()
                guard mode != .silent, let response = xpc_dictionary_create_reply(event) else { return }
                let send = { xpc_connection_send_message(peer, response); self.replied.signal() }
                if mode == .delayed { queue.asyncAfter(deadline: .now() + 0.1, execute: send) }
                else { send() }
            }
            xpc_connection_resume(peer)
        }
        xpc_connection_resume(listener)
    }
    func client() -> xpc_connection_t { xpc_connection_create_from_endpoint(xpc_endpoint_create(listener)) }
    deinit {
        xpc_connection_cancel(listener)
        for peer in peers { xpc_connection_cancel(peer) }
    }
}

@Suite("DTUHID real local XPC callback lifetime", .serialized)
struct DTUHIDXPCPeerTests {
    @Test func realConnectionOrdersBarrierTouchAndFinish() throws {
        let peer = AnonymousHIDPeer(mode: .reply)
        let transport = DTUHIDXPCConnection(connection: peer.client())
        let session = try DTUHIDSession(connection: transport)
        try session.send(point: .zero, phase: .down, identifier: 1)
        try session.send(point: .zero, phase: .up, identifier: 1)
        try session.finish()
        #expect(peer.types == ["IndigoKeyboardButtonEvent", "IndigoDigitizerEvent", "IndigoDigitizerEvent", "IndigoKeyboardButtonEvent"])
    }

    @Test func cancelWakesPendingBarrierAndPoisonsConnection() throws {
        let peer = AnonymousHIDPeer(mode: .silent)
        let transport = DTUHIDXPCConnection(connection: peer.client())
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            #expect(throws: NativeDigitizerError.sendFailed) { try transport.barrier(timeout: 4) }
            done.signal()
        }
        #expect(peer.received.wait(timeout: .now() + 2) == .success)
        transport.cancel()
        #expect(done.wait(timeout: .now() + 1) == .success)
        #expect(throws: NativeDigitizerError.sendFailed) { try transport.send(.touch(x: 0, y: 0, phase: 0)) }
        #expect(peer.types.count == 1)
    }

    @Test func timeoutAndLatePeerReplyCannotReviveConnection() throws {
        let peer = AnonymousHIDPeer(mode: .delayed)
        let transport = DTUHIDXPCConnection(connection: peer.client())
        try transport.barrier(timeout: 2)
        #expect(peer.replied.wait(timeout: .now() + 2) == .success)
        #expect(throws: NativeDigitizerError.timeout) { try transport.barrier(timeout: 0.02) }
        #expect(peer.replied.wait(timeout: .now() + 2) == .success)
        #expect(throws: NativeDigitizerError.sendFailed) { try transport.barrier(timeout: 1) }
        #expect(throws: NativeDigitizerError.sendFailed) { try transport.send(.touch(x: 0, y: 0, phase: 0)) }
        #expect(peer.types.count == 2)
    }
}
