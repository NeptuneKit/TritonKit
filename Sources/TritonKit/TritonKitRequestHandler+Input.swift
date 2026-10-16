import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

extension TritonKitRequestHandler {
    func handleInput(_ message: TKMessage) async -> TKMessage? {
        guard let data = message.payload,
              let request = try? JSONDecoder().decode(TKInputRequest.self, from: data) else {
            let result = TKInputResult.failure(action: "input", message: "Missing or invalid input payload")
            return TKMessage(id: message.id, type: .input, payload: try? JSONEncoder().encode(result))
        }

        if let selection = request.selection {
            do {
                try selection.validate()
                guard request == TKInputRequest(type: .tap, selection: selection) else {
                    throw TKSelectionError(code: "validation_failed", message: "Do not combine a selection reference with another target or action.")
                }
            } catch {
                let failure = TKInputResult.failure(action: request.type.rawValue, message: "Selection references support only an unambiguous tap request.",
                    error: TKCLIErrorDetail(code: "validation_failed", message: String(describing: error)))
                return TKMessage(id: message.id, type: .input, payload: try? JSONEncoder().encode(failure))
            }
        }
        #if canImport(UIKit)
        if let selection = request.selection {
            let result = await MainActor.run { () -> TKInputResult in
                guard let kit, kit.configuration.isRuntimeCapabilityEnabled(.inspector), let manager = kit.pickerStorage.current() else {
                    return TKInputResult.failure(action: "tap", message: "Picker is disabled.",
                        error: TKCLIErrorDetail(code: "selection_unsupported", message: "The optional Debug UIKit picker is not enabled or ready."))
                }
                return manager.performGuardedTap(selection)
            }
            return TKMessage(id: message.id, type: .input, payload: try? JSONEncoder().encode(result))
        }
        let result = await performInput(request)
        return TKMessage(id: message.id, type: .input, payload: try? JSONEncoder().encode(result))
        #else
        let result = TKInputResult.unsupported(
            action: request.type.rawValue,
            message: "Input control requires UIKit runtime"
        )
        return TKMessage(id: message.id, type: .input, payload: try? JSONEncoder().encode(result))
        #endif
    }
}
