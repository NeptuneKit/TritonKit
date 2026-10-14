import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

extension TritonKitRequestHandler {
    func handleHighlight(_ message: TKMessage) async -> TKMessage {
        let encoder = JSONEncoder()
        guard TritonKit.isRuntimeEnabled else { return highlightUnavailable(message, reason: "Highlight runtime is disabled outside Debug builds.") }
        #if canImport(UIKit)
        guard let kit else { return highlightUnavailable(message, reason: "No optional in-process provider is available for this request.") }
        let generation = TKHighlightRequestContext.generation ?? kit.highlightGeneration
        if (message.type == .highlightApply || message.type == .highlightCapabilities), !kit.configuration.features.contains(.highlight) {
            return highlightUnavailable(message, reason: "The optional highlight feature is disabled in this runtime configuration.")
        }
        if message.type == .highlightApply, kit.highlightCleanupPending {
            let error = TKHighlightError(code: "highlight_busy", message: "Runtime stop cleanup must finish before applying a new session.")
            let response = TKHighlightReceipt(ok: false, runtimeInstanceID: "unavailable", error: error, errors: [error])
            return TKMessage(id: message.id, type: message.type, payload: try? encoder.encode(response))
        }
        let manager = await kit.highlightSessionManager()
        do {
            switch message.type {
            case .highlightCapabilities:
                let request = try decodeHighlight(TKHighlightCapabilitiesRequest.self, from: message)
                let response = await manager.capabilities(request)
                return TKMessage(id: message.id, type: message.type, payload: try encoder.encode(response))
            case .highlightApply:
                let request = try decodeHighlight(TKHighlightApplyRequest.self, from: message)
                let response = await kit.applyHighlight(request, expectedGeneration: generation)
                return TKMessage(id: message.id, type: message.type, payload: try encoder.encode(response))
            case .highlightStatus:
                let request = try decodeHighlight(TKHighlightStatusRequest.self, from: message)
                let response = await manager.status(request)
                return TKMessage(id: message.id, type: message.type, payload: try encoder.encode(response))
            case .highlightClear:
                let request = try decodeHighlight(TKHighlightClearRequest.self, from: message)
                let response = await manager.clear(request)
                return TKMessage(id: message.id, type: message.type, payload: try encoder.encode(response))
            default:
                return highlightUnavailable(message, reason: "Unsupported highlight request type.")
            }
        } catch {
            let runtimeID = await manager.runtimeInstanceID
            let failure = TKHighlightError(code: "validation_failed", message: "Invalid highlight payload: \(error.localizedDescription)")
            if message.type == .highlightCapabilities {
                let response = TKHighlightCapabilitiesResponse(ok: false, runtimeInstanceID: runtimeID, capability: .unsupported(reason: "invalid_request"), error: failure)
                return TKMessage(id: message.id, type: message.type, payload: try? encoder.encode(response))
            }
            let response = TKHighlightReceipt(ok: false, runtimeInstanceID: runtimeID, reason: "invalid_request", error: failure, errors: [failure])
            return TKMessage(id: message.id, type: message.type, payload: try? encoder.encode(response))
        }
        #else
        return highlightUnavailable(message, reason: "No optional writable highlight provider is available on this platform.")
        #endif
    }
    private func decodeHighlight<T: Decodable>(_ type: T.Type, from message: TKMessage) throws -> T {
        guard let payload = message.payload else { throw TKHighlightError(code: "validation_failed", message: "A highlight request payload is required.") }
        return try JSONDecoder().decode(type, from: payload)
    }
    private func highlightUnavailable(_ message: TKMessage, reason: String) -> TKMessage {
        let error = TKHighlightError(code: "highlight_unsupported", message: reason)
        if message.type == .highlightCapabilities {
            let response = TKHighlightCapabilitiesResponse(runtimeInstanceID: "unavailable", capability: .unsupported(reason: reason))
            return TKMessage(id: message.id, type: message.type, payload: try? JSONEncoder().encode(response))
        }
        let response = TKHighlightReceipt(ok: false, runtimeInstanceID: "unavailable", reason: "unsupported", error: error, errors: [error])
        return TKMessage(id: message.id, type: message.type, payload: try? JSONEncoder().encode(response))
    }
}
