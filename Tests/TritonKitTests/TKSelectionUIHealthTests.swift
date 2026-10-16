import Foundation
import Testing
import TritonKitShared
@testable import TritonKit

@Suite
struct TKSelectionUIHealthTests {
    @Test("all selection health failures retain the typed DTO and original diagnostics")
    func typedErrorContracts() throws {
        let health = TKRuntimeUIHealthController().snapshot()
        for type in [TKRequestType.selectionStatus, .selectionClear, .selectionCapabilities] {
            for code in ["runtime_ui_busy", "runtime_ui_timeout", "runtime_ui_circuit_open"] {
                let message = TKMessage(id: 81, type: type,
                    payload: try JSONEncoder().encode(TKSelectionRequest(runtimeInstanceID: "private-request-identity")))
                let response = runtimeUIHealthErrorResponse(message, code: code, health: health)
                let data = try #require(response.payload)
                let decoded = try JSONDecoder().decode(TKSelectionResponse.self, from: data)
                #expect(response.id == message.id)
                #expect(response.type == type)
                #expect(!decoded.ok)
                #expect(decoded.schemaVersion == 1)
                #expect(decoded.runtimeInstanceID == "unavailable")
                #expect(decoded.state == "unavailable")
                #expect(decoded.revision == 0)
                #expect(decoded.selection == nil)
                #expect(decoded.error?.code == code)
                #expect(decoded.outcome == (code == "runtime_ui_timeout" ? "unknown" : "not_started"))
                #expect(decoded.uiHealth == health)
                #expect(!String(decoding: data, as: UTF8.self).contains("private-request-identity"))
            }
        }
    }

    @Test("old successful selection payloads decode without health extension fields")
    func additiveCompatibility() throws {
        let oldPayload = Data(#"{"ok":true,"schemaVersion":1,"runtimeInstanceID":"runtime","revision":0,"state":"none"}"#.utf8)
        let decoded = try JSONDecoder().decode(TKSelectionResponse.self, from: oldPayload)
        #expect(decoded.ok)
        #expect(decoded.outcome == nil)
        #expect(decoded.uiHealth == nil)
        #expect(decoded == TKSelectionResponse(runtimeInstanceID: "runtime"))
    }

    @Test("selection handler preserves a busy admission refusal without running its provider")
    func busyHandlerContract() async throws {
        guard TritonKit.isRuntimeEnabled else { return }
        let controller = TKRuntimeUIHealthController(timeoutMilliseconds: 30_000)
        let latch = SelectionUIHealthLatch()
        let blocked = Task { await controller.execute(TKMessage(id: 71, type: .hierarchy)) { message in
            await latch.wait()
            return message
        } }
        await latch.waitUntilEntered()
        let handler = TritonKitRequestHandler(uiHealthController: controller, uiMessageHandler: { _ in
            Issue.record("A busy selection request must not reach the provider")
            return nil
        })
        var responses: [TKMessage?] = []
        for type in [TKRequestType.selectionStatus, .selectionClear, .selectionCapabilities] {
            responses.append(await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 72, type: type)))
        }
        await latch.release()
        _ = await blocked.value
        for response in responses {
            let data = try #require(response?.payload)
            let decoded = try JSONDecoder().decode(TKSelectionResponse.self, from: data)
            #expect(decoded.error?.code == "runtime_ui_busy")
            #expect(decoded.outcome == "not_started")
            #expect(decoded.uiHealth?.state == .busy)
            #expect(decoded.uiHealth?.inflight?.requestID == 71)
        }
    }
}

private actor SelectionUIHealthLatch {
    private var entered = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilEntered() async { while !entered { await Task.yield() } }
    func release() { continuation?.resume(); continuation = nil }
}
