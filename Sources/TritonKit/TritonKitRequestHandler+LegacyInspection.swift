import Foundation
import TritonKitShared
#if canImport(UIKit)
import UIKit
#endif

extension TritonKitRequestHandler {
    func handleLegacyInspection(_ message: TKMessage) -> TKMessage? {
        switch message.type {
        case .hierarchyDetails:
            return handleHierarchyDetails(message)
        case .allAttrGroups:
            return handleAllAttrGroups(message)
        case .modifyAttribute:
            return handleModifyAttribute(message)
        case .invokeMethod:
            return handleInvokeMethod(message)
        case .fetchObject:
            return handleFetchObject(message)
        default:
            return unsupportedMessage(message)
        }
    }

    func handleHierarchyDetails(_ message: TKMessage) -> TKMessage? {
        TKMessage(id: message.id, type: .hierarchyDetails, payload: try? JSONEncoder().encode([TKDisplayItemDetail]()))
    }

    func handleAllAttrGroups(_ message: TKMessage) -> TKMessage? {
        #if canImport(UIKit)
        guard let data = message.payload,
              let oid = try? JSONDecoder().decode(UInt.self, from: data),
              let object = TKObjectRegistry.shared.object(for: oid) as? CALayer else {
            return TKMessage(id: message.id, type: .allAttrGroups,
                payload: try? JSONEncoder().encode([TKAttributesGroup]()))
        }
        let groups = TKAttributeGroupsBuilder.build(for: object)
        return TKMessage(id: message.id, type: .allAttrGroups, payload: try? JSONEncoder().encode(groups))
        #else
        return TKMessage(id: message.id, type: .allAttrGroups,
            payload: try? JSONEncoder().encode([TKAttributesGroup]()))
        #endif
    }

    func handleModifyAttribute(_ message: TKMessage) -> TKMessage? {
        let result = ModifyResult(success: true)
        return TKMessage(id: message.id, type: .modifyAttribute, payload: try? JSONEncoder().encode(result))
    }

    func handleInvokeMethod(_ message: TKMessage) -> TKMessage? {
        guard let data = message.payload else {
            return errorResponse(id: message.id, message: "Missing params")
        }
        struct InvokeParams: Codable {
            let oid: UInt
            let selector: String
        }
        guard let params = try? JSONDecoder().decode(InvokeParams.self, from: data),
              let obj = TKObjectRegistry.shared.object(for: params.oid) else {
            return errorResponse(id: message.id, message: "Object not found")
        }
        let selector = NSSelectorFromString(params.selector)
        guard obj.responds(to: selector) else {
            return errorResponse(id: message.id, message: "Object doesn't respond to \(params.selector)")
        }
        let result = obj.perform(selector)?.takeUnretainedValue()
        let desc = result.map { String(describing: $0) } ?? "void"
        let invokeResult = InvokeResult(result: desc)
        return TKMessage(id: message.id, type: .invokeMethod, payload: try? JSONEncoder().encode(invokeResult))
    }

    func handleFetchObject(_ message: TKMessage) -> TKMessage? {
        guard let data = message.payload,
              let oid = try? JSONDecoder().decode(UInt.self, from: data),
              let object = TKObjectRegistry.shared.object(for: oid) else {
            return errorResponse(id: message.id, message: "Object not found")
        }
        let obj = TKObject(
            oid: oid,
            memoryAddress: "\(Unmanaged.passUnretained(object).toOpaque())",
            classChainList: classChain(for: object)
        )
        return TKMessage(id: message.id, type: .fetchObject, payload: try? JSONEncoder().encode(obj))
    }
}
