import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

public class TritonKitRequestHandler: TritonKitDelegate {
    public weak var kit: TritonKit?
    private let uiHealthController: TKRuntimeUIHealthController
    private let uiMessageHandler: ((TKMessage) async -> TKMessage?)?

    public init() {
        uiHealthController = TKRuntimeUIHealthController()
        uiMessageHandler = nil
    }

    /// Explicit bounded runtime policy; invalid values fall back to safe defaults.
    public init(uiRequestTimeoutMilliseconds: Int, uiCircuitFailureThreshold: Int = 3) {
        uiHealthController = TKRuntimeUIHealthController(timeoutMilliseconds: uiRequestTimeoutMilliseconds, failureThreshold: uiCircuitFailureThreshold)
        uiMessageHandler = nil
    }

    // A non-UIKit provider seam lets tests exercise the actual request admission path.
    init(uiHealthController: TKRuntimeUIHealthController, uiMessageHandler: @escaping (TKMessage) async -> TKMessage?) {
        self.uiHealthController = uiHealthController
        self.uiMessageHandler = uiMessageHandler
    }

    public func tritonKit(_ kit: TritonKit, didChangeState state: TritonKit.ConnectionState) {
        if state == .connected {
            self.kit = kit
        }
    }

    public func tritonKit(_ kit: TritonKit, didReceiveError error: Error) {
        // Errors handled by TritonKit itself (reconnect logic)
    }

    public func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) async -> TKMessage? {
        guard TritonKit.isRuntimeEnabled else {
            if message.type == .runtimeManifest {
                return TKMessage(
                    id: message.id,
                    type: .runtimeManifest,
                    payload: try? JSONEncoder().encode(TKRuntimeManifestResponse.releaseDisabled(sdkVersion: "0.1.0-dev"))
                )
            }
            return TKMessage(id: message.id, type: .ping,
                payload: try? JSONEncoder().encode(TKErrorPayload(message: "TritonKit runtime is disabled outside DEBUG builds")))
        }
        self.kit = kit
        let startedAt = Date()
        let response: TKMessage?
        if let disabled = TKRuntimeCapabilityGate.disabledResponse(for: message, configuration: kit.configuration) {
            response = disabled
        } else {
            switch TKRuntimeRequestDomain.domain(for: message.type) {
            case .observation, .input, .webView, .semantic, .legacyInspection:
                response = await uiHealthController.execute(message) { [self] request in
                    if let uiMessageHandler { return await uiMessageHandler(request) }
                    return await handle(request)
                }
            case .control, .ledger, .unsupported:
                response = await handle(message)
            }
        }
        if message.type != .runtimeLedger {
            recordRuntimeLedger(message: message, response: response, elapsedMs: elapsedMilliseconds(since: startedAt))
        }
        return response
    }

    // MARK: - Message Routing

    private func handle(_ msg: TKMessage) async -> TKMessage? {
        switch msg.type {
        case .ping:
            let pong = TKRuntimePingResponse(pong: true, timestamp: Date().timeIntervalSince1970, uiHealth: uiHealthController.snapshot())
            return TKMessage(id: msg.id, type: .ping, payload: try? JSONEncoder().encode(pong))

        case .runtimeManifest:
            let manifest = currentRuntimeManifestWithWebViewProvider(sdkVersion: "0.1.0-dev")
            let payload = try? JSONEncoder().encode(manifest)
            return TKMessage(id: msg.id, type: .runtimeManifest, payload: payload)

        default:
            if let kit, let disabled = TKRuntimeCapabilityGate.disabledResponse(for: msg, configuration: kit.configuration) {
                return disabled
            }
        }

        switch TKRuntimeRequestDomain.domain(for: msg.type) {
        case .control:
            return nil
        case .observation:
            return await handleObservation(msg)
        case .input:
            return await handleInput(msg)
        case .webView:
            return await handleWebView(msg)
        case .semantic:
            return await handleSemanticAction(msg)
        case .ledger:
            let request = msg.payload.flatMap { try? JSONDecoder().decode(TKRuntimeLedgerRequest.self, from: $0) } ?? TKRuntimeLedgerRequest()
            let response = runtimeLedgerStore.response(limit: request.limit)
            return TKMessage(id: msg.id, type: .runtimeLedger, payload: try? JSONEncoder().encode(response))
        case .legacyInspection:
            return await handleLegacyInspection(msg)
        case .unsupported:
            return unsupportedMessage(msg)
        }
    }

    // MARK: - Helpers

    func unsupportedMessage(_ message: TKMessage) -> TKMessage {
        TKMessage(id: message.id, type: .ping,
            payload: try? JSONEncoder().encode(TKErrorPayload(message: "Unsupported: \(message.type.rawValue)")))
    }

    func errorResponse(id: Int, message: String) -> TKMessage {
        TKMessage(id: id, type: .ping,
            payload: try? JSONEncoder().encode(TKErrorPayload(message: message)))
    }

}
