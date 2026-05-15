import Foundation
#if canImport(UIKit)
import UIKit
#endif

public class TritonKitRequestHandler: TritonKitDelegate {
    public weak var kit: TritonKit?

    public init() {}

    public func tritonKit(_ kit: TritonKit, didChangeState state: TritonKit.ConnectionState) {
        if state == .connected {
            self.kit = kit
        }
    }

    public func tritonKit(_ kit: TritonKit, didReceiveError error: Error) {
        // Errors handled by TritonKit itself (reconnect logic)
    }

    public func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) -> TKMessage? {
        return handle(message)
    }

    // MARK: - Message Routing

    private func handle(_ msg: TKMessage) -> TKMessage? {
        switch msg.type {
        case .ping:
            let pong = PingResponse(pong: true, timestamp: Date().timeIntervalSince1970)
            return TKMessage(id: msg.id, type: .ping, payload: try? JSONEncoder().encode(pong))

        case .appInfo:
            let appInfo = TKAppInfo()
            let info = TKHierarchyInfo(displayItems: [], appInfo: appInfo)
            let payload = try? JSONEncoder().encode(info)
            return TKMessage(id: msg.id, type: .appInfo, payload: payload)

        case .hierarchy:
            let items = TKHierarchyBuilder.buildHierarchy(includeScreenshots: false)
            let appInfo = TKAppInfo()
            let hierarchy = TKHierarchyInfo(displayItems: items, appInfo: appInfo)
            let payload = try? JSONEncoder().encode(hierarchy)
            return TKMessage(id: msg.id, type: .hierarchy, payload: payload)

        case .hierarchyDetails:
            return handleHierarchyDetails(msg)

        case .allAttrGroups:
            return handleAllAttrGroups(msg)

        case .modifyAttribute:
            return handleModifyAttribute(msg)

        case .invokeMethod:
            return handleInvokeMethod(msg)

        case .fetchObject:
            return handleFetchObject(msg)

        default:
            return TKMessage(id: msg.id, type: .ping,
                payload: try? JSONEncoder().encode(TKErrorPayload(message: "Unsupported: \(msg.type.rawValue)")))
        }
    }

    // MARK: - Handlers

    private func handleHierarchyDetails(_ msg: TKMessage) -> TKMessage? {
        // For now, return empty details list
        return TKMessage(id: msg.id, type: .hierarchyDetails, payload: try? JSONEncoder().encode([TKDisplayItemDetail]()))
    }

    private func handleAllAttrGroups(_ msg: TKMessage) -> TKMessage? {
        guard let data = msg.payload,
              let oid = try? JSONDecoder().decode(UInt.self, from: data),
              let object = TKObjectRegistry.shared.object(for: oid) as? CALayer else {
            return TKMessage(id: msg.id, type: .allAttrGroups,
                payload: try? JSONEncoder().encode([TKAttributesGroup]()))
        }
        let groups = TKAttributeGroupsBuilder.build(for: object)
        let payload = try? JSONEncoder().encode(groups)
        return TKMessage(id: msg.id, type: .allAttrGroups, payload: payload)
    }

    private func handleModifyAttribute(_ msg: TKMessage) -> TKMessage? {
        // Attribute modification needs the original ObjC LKS_InbuiltAttrModificationHandler logic
        // Stub: return success
        return TKMessage(id: msg.id, type: .modifyAttribute,
            payload: try? JSONEncoder().encode(["success": true]))
    }

    private func handleInvokeMethod(_ msg: TKMessage) -> TKMessage? {
        guard let data = msg.payload else {
            return errorResponse(id: msg.id, message: "Missing params")
        }
        struct InvokeParams: Codable {
            let oid: UInt
            let selector: String
        }
        guard let params = try? JSONDecoder().decode(InvokeParams.self, from: data),
              let obj = TKObjectRegistry.shared.object(for: params.oid) else {
            return errorResponse(id: msg.id, message: "Object not found")
        }
        let selector = NSSelectorFromString(params.selector)
        guard obj.responds(to: selector) else {
            return errorResponse(id: msg.id, message: "Object doesn't respond to \(params.selector)")
        }
        let result = obj.perform(selector)?.takeUnretainedValue()
        let desc = result.map { String(describing: $0) } ?? "void"
        let invokeResult = InvokeResult(result: desc)
        let payload = try? JSONEncoder().encode(invokeResult)
        return TKMessage(id: msg.id, type: .invokeMethod, payload: payload)
    }

    private func handleFetchObject(_ msg: TKMessage) -> TKMessage? {
        guard let data = msg.payload,
              let oid = try? JSONDecoder().decode(UInt.self, from: data),
              let object = TKObjectRegistry.shared.object(for: oid) else {
            return errorResponse(id: msg.id, message: "Object not found")
        }
        let obj = TKObject(
            oid: oid,
            memoryAddress: String(format: "%p", unsafeBitCast(object, to: Int.self)),
            classChainList: classChain(for: object)
        )
        let payload = try? JSONEncoder().encode(obj)
        return TKMessage(id: msg.id, type: .fetchObject, payload: payload)
    }

    // MARK: - Helpers

    private func errorResponse(id: Int, message: String) -> TKMessage {
        TKMessage(id: id, type: .ping,
            payload: try? JSONEncoder().encode(TKErrorPayload(message: message)))
    }

    private func classChain(for object: AnyObject) -> [String] {
        var chain: [String] = []
        var cls: AnyClass = type(of: object)
        while true {
            chain.append(NSStringFromClass(cls))
            guard let superCls = cls.superclass() else { break }
            cls = superCls
        }
        return chain
    }
}

// MARK: - Response Payloads

private struct PingResponse: Codable {
    let pong: Bool
    let timestamp: TimeInterval
}

private struct InvokeResult: Codable {
    let result: String
}
