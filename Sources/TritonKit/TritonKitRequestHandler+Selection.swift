import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

extension TritonKitRequestHandler {
    func handleSelection(_ message: TKMessage) async -> TKMessage {
        let response: TKSelectionResponse
        do {
            guard let payload = message.payload else {
                throw TKSelectionError(code: "validation_failed", message: "A selection request payload is required.")
            }
            let request = try JSONDecoder().decode(TKSelectionRequest.self, from: payload)
            if let runtime = request.runtimeInstanceID, runtime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw TKSelectionError(code: "validation_failed", message: "runtimeInstanceID must not be empty.")
            }
            #if canImport(UIKit)
            if TritonKit.isRuntimeEnabled, let kit, kit.configuration.isRuntimeCapabilityEnabled(.inspector) {
                response = await MainActor.run {
                    guard let manager = kit.pickerStorage.current() else { return selectionUnavailable() }
                    let status = manager.status()
                    if let expected = request.runtimeInstanceID, expected != status.runtimeInstanceID {
                        return TKSelectionResponse(ok: false, runtimeInstanceID: status.runtimeInstanceID,
                            revision: status.revision, state: "stale", error: TKSelectionError(code: "selection_stale", message: "The App runtime instance has changed."))
                    }
                    switch message.type {
                    case .selectionCapabilities:
                        return TKSelectionResponse(runtimeInstanceID: status.runtimeInstanceID, revision: status.revision, state: "available")
                    case .selectionClear: return manager.clear()
                    default: return status
                    }
                }
            } else { response = selectionUnavailable() }
            #else
            response = selectionUnavailable()
            #endif
        } catch {
            let failure = error as? TKSelectionError ?? TKSelectionError(code: "validation_failed", message: "Invalid selection payload.")
            response = TKSelectionResponse(ok: false, runtimeInstanceID: "unavailable", error: failure)
        }
        return TKMessage(id: message.id, type: message.type, payload: try? JSONEncoder().encode(response))
    }
}

private func selectionUnavailable() -> TKSelectionResponse {
    TKSelectionResponse(ok: false, runtimeInstanceID: "unavailable", state: "unsupported",
        error: TKSelectionError(code: "selection_unsupported", message: "The optional Debug UIKit picker is not enabled or ready."))
}
