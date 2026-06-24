import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

extension TritonKitRequestHandler {
    func handleSemanticAction(_ message: TKMessage) async -> TKMessage? {
        guard let data = message.payload,
              let request = try? JSONDecoder().decode(TKSemanticActionRequest.self, from: data) else {
            let result = TKSemanticActionResponse(
                ok: false,
                action: .focus,
                strategy: "invalid-payload",
                elapsedMs: 0,
                message: "Missing or invalid semantic action payload",
                error: TKCLIErrorDetail(code: "invalid_payload", message: "Missing or invalid semantic action payload")
            )
            return TKMessage(id: message.id, type: .semanticAction, payload: try? JSONEncoder().encode(result))
        }

        #if canImport(UIKit)
        let result = await MainActor.run { performSemanticAction(request) }
        #else
        let result = TKSemanticActionResponse(
            ok: false,
            action: request.action,
            strategy: request.strategy ?? "unsupported-runtime",
            elapsedMs: 0,
            message: "Semantic actions require UIKit runtime",
            error: TKCLIErrorDetail(code: "unsupported_runtime_scope", message: "Semantic actions require UIKit runtime")
        )
        #endif
        return TKMessage(id: message.id, type: .semanticAction, payload: try? JSONEncoder().encode(result))
    }
}
