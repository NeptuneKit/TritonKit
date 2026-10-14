import Foundation
import Testing
@testable import TritonKit
import TritonKitShared

@Suite(.serialized) struct TKHighlightUIHealthIntegrationTests {
    @Test("optional highlight recovery keeps its typed contract while observation is busy")
    func highlightRecoveryDoesNotAcquireObservationAdmission() async throws {
        let controller = TKRuntimeUIHealthController(timeoutMilliseconds: 30_000)
        let latch = HighlightObservationLatch()
        let observation = Task { await controller.execute(TKMessage(id: 1, type: .hierarchy)) { message in
            await latch.wait()
            return message
        } }
        await latch.waitUntilEntered()
        let handler = TritonKitRequestHandler(uiHealthController: controller, uiMessageHandler: { _ in
            Issue.record("Highlight was incorrectly routed through observation admission")
            return nil
        })
        let capabilityResponse = await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 2, type: .highlightCapabilities))
        let readback = await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 3, type: .highlightStatus, payload: Data("{\"sessionID\":\"unknown-highlight-session\"}".utf8)))
        let cleanup = await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 4, type: .highlightClear, payload: Data("{\"sessionID\":\"unknown-highlight-session\"}".utf8)))
        let inflight = controller.snapshot().inflight
        await latch.release()
        _ = await observation.value
        let data = try #require(capabilityResponse?.payload)
        let capability = try JSONDecoder().decode(TKHighlightCapabilitiesResponse.self, from: data)
        #expect(capability.ok)
        for response in [readback, cleanup] {
            let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: try #require(response?.payload))
            #expect(!receipt.ok)
            #expect(receipt.error?.code != "runtime_ui_busy")
            #expect(receipt.marks.isEmpty)
        }
        #expect(inflight?.requestID == 1)
        #expect(inflight?.timedOut == false)
    }
}

private actor HighlightObservationLatch {
    private var entered = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilEntered() async { while !entered { await Task.yield() } }
    func release() { continuation?.resume(); continuation = nil }
}
