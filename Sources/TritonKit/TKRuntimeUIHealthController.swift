import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

/// Admission and diagnostics never execute on MainActor. A deadline releases only the
/// caller's continuation: the original operation owns admission until it really completes.
final class TKRuntimeUIHealthController: @unchecked Sendable {
    typealias TimeoutScheduler = (Int, @escaping @Sendable () -> Void) -> Void
    private struct Inflight {
        let token: String
        let message: TKMessage
        let started: UInt64
        let response: UIResponseContinuation
        var timedOut = false
    }

    private let lock = NSLock()
    private let timeoutMilliseconds: Int
    private let failureThreshold: Int
    private let scheduleTimeout: TimeoutScheduler
    private var inflight: Inflight?
    private var consecutiveTimeouts = 0
    private var lastCompletion: TKRuntimeUICompletion?

    init(timeoutMilliseconds: Int = 30_000, failureThreshold: Int = 3, scheduleTimeout: @escaping TimeoutScheduler = { milliseconds, callback in
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: callback)
    }) {
        // Invalid values never remove the deadline or allow an unbounded failure streak.
        self.timeoutMilliseconds = timeoutMilliseconds > 0 && timeoutMilliseconds <= 120_000 ? timeoutMilliseconds : 30_000
        self.failureThreshold = failureThreshold > 0 && failureThreshold <= 100 ? failureThreshold : 3
        self.scheduleTimeout = scheduleTimeout
    }

    func snapshot() -> TKRuntimeUIHealthSnapshot { lock.withLock { snapshotLocked() } }

    func execute(_ message: TKMessage, operation: @escaping (TKMessage) async -> TKMessage?) async -> TKMessage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<TKMessage?, Never>) in
            let token = UUID().uuidString
            let response = UIResponseContinuation(continuation)
            let refusal: TKMessage? = lock.withLock {
                if inflight != nil {
                    return runtimeUIHealthErrorResponse(message, code: "runtime_ui_busy", health: snapshotLocked())
                }
                if consecutiveTimeouts >= failureThreshold {
                    return runtimeUIHealthErrorResponse(message, code: "runtime_ui_circuit_open", health: snapshotLocked())
                }
                inflight = Inflight(token: token, message: message, started: DispatchTime.now().uptimeNanoseconds, response: response)
                return nil
            }
            if let refusal {
                response.finish(refusal)
                return
            }
            scheduleTimeout(timeoutMilliseconds) { [weak self] in self?.expire(token: token) }
            // Unstructured work is deliberate: a structured task group would keep waiting
            // for a blocked UIKit provider after cancellation of its timeout race.
            Task.detached { [self] in
                let result = await operation(message)
                complete(token: token, result: result)
            }
        }
    }

    private func expire(token: String) {
        let expired: (UIResponseContinuation, TKMessage)? = lock.withLock { () -> (UIResponseContinuation, TKMessage)? in
            guard var current = inflight, current.token == token, !current.timedOut else { return nil }
            current.timedOut = true
            inflight = current
            consecutiveTimeouts += 1
            return (current.response, runtimeUIHealthErrorResponse(current.message, code: "runtime_ui_timeout", health: snapshotLocked()))
        }
        if let expired { expired.0.finish(expired.1) }
    }

    private func complete(token: String, result: TKMessage?) {
        let response: UIResponseContinuation? = lock.withLock { () -> UIResponseContinuation? in
            guard let current = inflight, current.token == token else { return nil }
            lastCompletion = TKRuntimeUICompletion(token: token, requestID: current.message.id, requestType: current.message.type.rawValue, timedOut: current.timedOut, producedResponse: result != nil)
            if !current.timedOut { consecutiveTimeouts = 0 }
            inflight = nil
            // Once the deadline owns the response, real completion only releases admission.
            return current.timedOut ? nil : current.response
        }
        response?.finish(result)
    }

    private func snapshotLocked() -> TKRuntimeUIHealthSnapshot {
        let state: TKRuntimeUIHealthState
        if let inflight { state = inflight.timedOut ? .timedOut : .busy }
        else { state = consecutiveTimeouts >= failureThreshold ? .circuitOpen : .ready }
        let request = inflight.map { current in
            TKRuntimeUIInflightRequest(token: current.token, requestID: current.message.id, requestType: current.message.type.rawValue, elapsedMilliseconds: Int((DispatchTime.now().uptimeNanoseconds - current.started) / 1_000_000), timedOut: current.timedOut)
        }
        return TKRuntimeUIHealthSnapshot(state: state, allowsUIRequests: state == .ready, inflight: request, consecutiveTimeouts: consecutiveTimeouts, failureThreshold: failureThreshold, timeoutMilliseconds: timeoutMilliseconds, lastCompletion: lastCompletion)
    }
}

private final class UIResponseContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<TKMessage?, Never>?
    init(_ continuation: CheckedContinuation<TKMessage?, Never>) { self.continuation = continuation }
    func finish(_ result: TKMessage?) {
        let callback = lock.withLock { () -> CheckedContinuation<TKMessage?, Never>? in
            defer { continuation = nil }
            return continuation
        }
        callback?.resume(returning: result)
    }
}
