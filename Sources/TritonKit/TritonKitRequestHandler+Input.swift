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

        #if canImport(UIKit)
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
