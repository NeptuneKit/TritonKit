import Foundation
import Testing
@testable import TritonKit
import TritonKitShared

@Suite(.serialized)
struct TKRuntimeUIHealthTests {
    @Test("the production deadline returns independently of a blocked provider")
    func productionDeadlineDoesNotWaitForProvider() async throws {
        let latch = UIHealthLatch()
        let controller = TKRuntimeUIHealthController(timeoutMilliseconds: 10)
        let request = Task { await controller.execute(TKMessage(id: 9, type: .hierarchy)) { message in
            await latch.wait()
            return message
        } }
        await latch.waitUntilEntered()
        let response = try #require(await request.value)
        let data = try #require(response.payload)
        let error = try JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
        #expect(error.error.code == "runtime_ui_timeout")
        #expect(controller.snapshot().inflight?.requestID == 9)
        await latch.release()
        await waitUntilIdle(controller)
    }

    @Test("invalid admission policies use finite defaults")
    func invalidPoliciesUseDefaults() {
        for value in [0, -1, Int.max] {
            let snapshot = TKRuntimeUIHealthController(timeoutMilliseconds: value, failureThreshold: value).snapshot()
            #expect(snapshot.timeoutMilliseconds == 30_000)
            #expect(snapshot.failureThreshold == 3)
            #expect(snapshot.allowsUIRequests)
        }
    }

    @Test("ping and ledger remain independent of an occupied UI request")
    func diagnosticsDoNotWaitForUI() async throws {
        guard TritonKit.isRuntimeEnabled else { return }
        let timeout = UIHealthManualTimeout()
        let latch = UIHealthLatch()
        let controller = TKRuntimeUIHealthController(timeoutMilliseconds: 30_000, scheduleTimeout: timeout.schedule)
        let handler = TritonKitRequestHandler(uiHealthController: controller, uiMessageHandler: { message in
            await latch.wait()
            return TKMessage(id: message.id, type: message.type)
        })
        let request = Task { await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 17, type: .hierarchy)) }
        await latch.waitUntilEntered()

        let ping = try #require(await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 18, type: .ping)))
        let pingData = try #require(ping.payload)
        let health = try JSONDecoder().decode(TKRuntimePingResponse.self, from: pingData)
        #expect(health.pong)
        #expect(health.uiHealth?.inflight?.requestID == 17)
        #expect(health.uiHealth?.state == .busy)
        #expect(health.uiHealth?.allowsUIRequests == false)
        let ledger = await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 19, type: .runtimeLedger))
        #expect(ledger?.type == .runtimeLedger)
        let manifest = await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 20, type: .runtimeManifest))
        #expect(manifest?.type == .runtimeManifest)

        await latch.release()
        _ = await request.value
    }

    @Test("timeout is unknown, retains inflight, and rejects duplicate writes without dispatch")
    func timedOutOperationRemainsOccupied() async throws {
        guard TritonKit.isRuntimeEnabled else { return }
        let timeout = UIHealthManualTimeout()
        let latch = UIHealthLatch()
        let controller = TKRuntimeUIHealthController(timeoutMilliseconds: 30_000, scheduleTimeout: timeout.schedule)
        let handler = TritonKitRequestHandler(uiHealthController: controller, uiMessageHandler: { message in
            await latch.wait()
            return TKMessage(id: message.id, type: message.type)
        })
        let message = TKMessage(id: 71, type: .input, payload: try JSONEncoder().encode(TKInputRequest.tap(x: 1, y: 2)))
        let first = Task { await handler.tritonKit(TritonKit.shared, didReceiveMessage: message) }
        await latch.waitUntilEntered()
        timeout.fire()
        let result = try #require(await first.value)
        let resultData = try #require(result.payload)
        let input = try JSONDecoder().decode(TKInputResult.self, from: resultData)
        let object = try #require(try JSONSerialization.jsonObject(with: resultData) as? [String: Any])
        #expect(input.error?.code == "runtime_ui_timeout")
        #expect(input.outcome == "unknown")
        #expect(input.uiHealth?.inflight?.requestID == 71)
        #expect(object["outcome"] as? String == "unknown")
        #expect(controller.snapshot().inflight?.requestID == 71)
        #expect(controller.snapshot().inflight?.timedOut == true)

        let retry = try #require(await handler.tritonKit(TritonKit.shared, didReceiveMessage: message))
        let retryData = try #require(retry.payload)
        let rejected = try JSONDecoder().decode(TKInputResult.self, from: retryData)
        #expect(rejected.error?.code == "runtime_ui_busy")
        #expect(await latch.entryCount == 1)
        await latch.release()
        await waitUntilIdle(controller)
        #expect(controller.snapshot().state == .ready)
        #expect(controller.snapshot().lastCompletion?.timedOut == true)
    }

    @Test("repeated timeouts open the circuit; ping probes do not reset it")
    func repeatedTimeoutsOpenCircuit() async throws {
        guard TritonKit.isRuntimeEnabled else { return }
        let timeout = UIHealthManualTimeout()
        let controller = TKRuntimeUIHealthController(timeoutMilliseconds: 30_000, failureThreshold: 2, scheduleTimeout: timeout.schedule)
        for id in [1, 2] {
            let latch = UIHealthLatch()
            let operation = Task { await controller.execute(TKMessage(id: id, type: .hierarchy)) { message in
                await latch.wait()
                return TKMessage(id: message.id, type: message.type)
            } }
            await latch.waitUntilEntered()
            timeout.fire()
            _ = await operation.value
            await latch.release()
            await waitUntilIdle(controller)
        }
        #expect(controller.snapshot().state == .circuitOpen)
        let handler = TritonKitRequestHandler(uiHealthController: controller, uiMessageHandler: { _ in
            Issue.record("An open circuit dispatched a UI operation")
            return nil
        })
        _ = await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 3, type: .ping))
        #expect(controller.snapshot().state == .circuitOpen)
        let rejected = try #require(await handler.tritonKit(TritonKit.shared, didReceiveMessage: TKMessage(id: 4, type: .accessibility)))
        let rejectionData = try #require(rejected.payload)
        let error = try JSONDecoder().decode(TKCLIErrorResponse.self, from: rejectionData)
        #expect(error.error.code == "runtime_ui_circuit_open")
    }

    @Test("late timer from a completed token cannot expire a successor")
    func completedTokenCannotAffectSuccessor() async throws {
        let timeout = UIHealthManualTimeout()
        let controller = TKRuntimeUIHealthController(timeoutMilliseconds: 30_000, scheduleTimeout: timeout.schedule)
        _ = await controller.execute(TKMessage(id: 1, type: .hierarchy)) { message in message }
        let previousTimer = try #require(timeout.take())
        let latch = UIHealthLatch()
        let next = Task { await controller.execute(TKMessage(id: 2, type: .hierarchy)) { message in
            await latch.wait()
            return message
        } }
        await latch.waitUntilEntered()
        previousTimer()
        previousTimer()
        #expect(controller.snapshot().inflight?.requestID == 2)
        #expect(controller.snapshot().inflight?.timedOut == false)
        #expect(controller.snapshot().consecutiveTimeouts == 0)
        await latch.release()
        _ = await next.value
    }

    @Test("timeouts preserve semantic and WebView response contracts")
    func errorContractsAreDomainSpecific() throws {
        let snapshot = TKRuntimeUIHealthController().snapshot()
        let semanticRequest = TKMessage(id: 1, type: .semanticAction, payload: try JSONEncoder().encode(TKSemanticActionRequest(action: .setText, text: "private")))
        let semantic = try #require(runtimeUIHealthErrorResponse(semanticRequest, code: "runtime_ui_timeout", health: snapshot).payload)
        let decoded = try JSONDecoder().decode(TKSemanticActionResponse.self, from: semantic)
        #expect(decoded.action == .setText)
        #expect(decoded.error?.code == "runtime_ui_timeout")
        #expect(decoded.outcome == "unknown")
        #expect(decoded.uiHealth == snapshot)
        let web = try #require(runtimeUIHealthErrorResponse(TKMessage(id: 2, type: .webViewTap), code: "runtime_ui_busy", health: snapshot).payload)
        #expect(try JSONDecoder().decode(TKWebViewErrorResponse.self, from: web).action == "webview.tap")
        #expect(String(decoding: semantic, as: UTF8.self).contains("private") == false)
    }

    @Test("input ledger preserves the UI timeout error code")
    func ledgerPreservesTimeoutCode() throws {
        let request = TKMessage(id: 3, type: .input, payload: try JSONEncoder().encode(TKInputRequest.tap(x: 1, y: 1)))
        let response = runtimeUIHealthErrorResponse(request, code: "runtime_ui_timeout", health: TKRuntimeUIHealthController().snapshot())
        let details = runtimeLedgerDetails(message: request, response: response)
        #expect(details.ok == false)
        #expect(details.errorCode == "runtime_ui_timeout")
    }

    private func waitUntilIdle(_ controller: TKRuntimeUIHealthController) async {
        for _ in 0..<10_000 {
            if controller.snapshot().inflight == nil { return }
            await Task.yield()
        }
        Issue.record("The completed fake provider did not release admission")
    }
}

private final class UIHealthManualTimeout: @unchecked Sendable {
    private let lock = NSLock()
    private var callbacks: [@Sendable () -> Void] = []
    func schedule(_ milliseconds: Int, _ callback: @escaping @Sendable () -> Void) {
        lock.withLock { callbacks.append(callback) }
    }
    func take() -> (@Sendable () -> Void)? { lock.withLock { callbacks.isEmpty ? nil : callbacks.removeFirst() } }
    func fire() { take()?() }
}

private actor UIHealthLatch {
    var entryCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        entryCount += 1
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilEntered() async {
        while entryCount == 0 { await Task.yield() }
    }
    func release() { continuation?.resume(); continuation = nil }
}
