import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif
#if canImport(UIKit)
import UIKit
#endif

extension TritonKitRequestHandler {
    func handleLegacyInspection(_ message: TKMessage) async -> TKMessage? {
        switch message.type {
        case .hierarchyDetails:
            return handleHierarchyDetails(message)
        case .allAttrGroups:
            return handleAllAttrGroups(message)
        case .modifyAttribute:
            return await handleModifyAttribute(message)
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

    func handleModifyAttribute(_ message: TKMessage) async -> TKMessage? {
        guard let data = message.payload,
              let request = try? JSONDecoder().decode(TKNodePropertyPatchRequest.self, from: data) else {
            let result = TKNodePropertyPatchResponse(
                ok: false,
                skipped: ["payload"],
                message: "Unsupported node property patch payload"
            )
            return TKMessage(id: message.id, type: .modifyAttribute, payload: try? JSONEncoder().encode(result))
        }
        guard !request.changes.isEmpty else {
            let result = TKNodePropertyPatchResponse(
                ok: true,
                nodeId: request.nodeId,
                oid: request.resolvedOID,
                skipped: ["no_changes"],
                message: "No node property changes to apply"
            )
            return TKMessage(id: message.id, type: .modifyAttribute, payload: try? JSONEncoder().encode(result))
        }
        guard let oid = request.resolvedOID else {
            let result = TKNodePropertyPatchResponse(
                ok: false,
                nodeId: request.nodeId,
                skipped: ["oid"],
                message: "Missing node oid"
            )
            return TKMessage(id: message.id, type: .modifyAttribute, payload: try? JSONEncoder().encode(result))
        }

        #if canImport(UIKit)
        let result = await applyNodePropertyPatch(request: request, oid: oid)
        return TKMessage(id: message.id, type: .modifyAttribute, payload: try? JSONEncoder().encode(result))
        #else
        let result = TKNodePropertyPatchResponse(
            ok: false,
            nodeId: request.nodeId,
            oid: oid,
            skipped: ["platform"],
            message: "Node property patch is only supported in UIKit runtimes"
        )
        return TKMessage(id: message.id, type: .modifyAttribute, payload: try? JSONEncoder().encode(result))
        #endif
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

#if canImport(UIKit)
@MainActor
private func applyNodePropertyPatch(request: TKNodePropertyPatchRequest, oid: UInt) -> TKNodePropertyPatchResponse {
    guard let object = TKObjectRegistry.shared.object(for: oid) else {
        return TKNodePropertyPatchResponse(
            ok: false,
            nodeId: request.nodeId,
            oid: oid,
            skipped: ["object"],
            message: "Object not found"
        )
    }

    let targets = resolveNodePatchTargets(object)
    var applied: [String] = []
    var skipped: [String] = []

    applyFramePatch(request.changes.frame, view: targets.view, layer: targets.layer, applied: &applied, skipped: &skipped)
    applyViewPatch(request.changes.view, view: targets.view, applied: &applied, skipped: &skipped)
    applyLayerPatch(request.changes.layer, layer: targets.layer, applied: &applied, skipped: &skipped)
    applyStylePatch(request.changes.style, view: targets.view, layer: targets.layer, applied: &applied, skipped: &skipped)

    return TKNodePropertyPatchResponse(
        ok: !applied.isEmpty,
        nodeId: request.nodeId,
        oid: oid,
        applied: applied,
        skipped: skipped,
        message: applied.isEmpty ? "No supported node properties were applied" : nil
    )
}

@MainActor
private func resolveNodePatchTargets(_ object: AnyObject) -> (view: UIView?, layer: CALayer?) {
    if let view = object as? UIView {
        return (view, view.layer)
    }
    if let layer = object as? CALayer {
        return (layer.delegate as? UIView, layer)
    }
    if let controller = object as? UIViewController {
        return (controller.view, controller.view.layer)
    }
    return (nil, nil)
}

@MainActor
private func applyFramePatch(
    _ changes: TKNodeFramePropertyChanges?,
    view: UIView?,
    layer: CALayer?,
    applied: inout [String],
    skipped: inout [String]
) {
    guard let changes, !changes.isEmpty else { return }
    guard view != nil || layer != nil else {
        appendChangedFrameFields(changes, prefix: "frame", into: &skipped)
        return
    }

    var frame = view?.frame ?? layer?.frame ?? .zero
    if let value = finiteCGFloat(changes.x) {
        frame.origin.x = value
        applied.append("frame.x")
    }
    if let value = finiteCGFloat(changes.y) {
        frame.origin.y = value
        applied.append("frame.y")
    }
    if let value = finiteCGFloat(changes.width) {
        frame.size.width = max(0, value)
        applied.append("frame.width")
    }
    if let value = finiteCGFloat(changes.height) {
        frame.size.height = max(0, value)
        applied.append("frame.height")
    }
    if let view {
        view.frame = frame
    } else {
        layer?.frame = frame
    }
}

@MainActor
private func applyViewPatch(
    _ changes: TKNodeViewPropertyChanges?,
    view: UIView?,
    applied: inout [String],
    skipped: inout [String]
) {
    guard let changes, !changes.isEmpty else { return }
    guard let view else {
        appendChangedViewFields(changes, prefix: "view", into: &skipped)
        return
    }
    if let isHidden = changes.isHidden {
        view.isHidden = isHidden
        applied.append("view.isHidden")
    }
    if let alpha = finiteCGFloat(changes.alpha) {
        view.alpha = clamp(alpha, min: 0, max: 1)
        applied.append("view.alpha")
    }
    if let enabled = changes.isUserInteractionEnabled {
        view.isUserInteractionEnabled = enabled
        applied.append("view.isUserInteractionEnabled")
    }
    if let identifier = changes.accessibilityIdentifier {
        view.accessibilityIdentifier = identifier
        applied.append("view.accessibilityIdentifier")
    }
    if let label = changes.accessibilityLabel {
        view.accessibilityLabel = label
        applied.append("view.accessibilityLabel")
    }
}

@MainActor
private func applyLayerPatch(
    _ changes: TKNodeLayerPropertyChanges?,
    layer: CALayer?,
    applied: inout [String],
    skipped: inout [String]
) {
    guard let changes, !changes.isEmpty else { return }
    guard let layer else {
        appendChangedLayerFields(changes, prefix: "layer", into: &skipped)
        return
    }
    if let isHidden = changes.isHidden {
        layer.isHidden = isHidden
        applied.append("layer.isHidden")
    }
    if let masksToBounds = changes.masksToBounds {
        layer.masksToBounds = masksToBounds
        applied.append("layer.masksToBounds")
    }
    if let opacity = finiteFloat(changes.opacity) {
        layer.opacity = clamp(opacity, min: 0, max: 1)
        applied.append("layer.opacity")
    }
    if let cornerRadius = finiteCGFloat(changes.cornerRadius) {
        layer.cornerRadius = max(0, cornerRadius)
        applied.append("layer.cornerRadius")
    }
    if let zPosition = finiteCGFloat(changes.zPosition) {
        layer.zPosition = zPosition
        applied.append("layer.zPosition")
    }
}

@MainActor
private func applyStylePatch(
    _ changes: TKNodeStylePropertyChanges?,
    view: UIView?,
    layer: CALayer?,
    applied: inout [String],
    skipped: inout [String]
) {
    guard let changes, !changes.isEmpty else { return }
    if let text = changes.text {
        if let view, setNodeText(text, on: view) {
            applied.append("style.text")
        } else {
            skipped.append("style.text")
        }
    }
    if let colorText = changes.backgroundColor {
        if let view, let color = UIColor(tritonHexString: colorText) {
            view.backgroundColor = color
            applied.append("style.backgroundColor")
        } else {
            skipped.append("style.backgroundColor")
        }
    }
    if let colorText = changes.foregroundColor {
        if let view, let color = UIColor(tritonHexString: colorText), setNodeForegroundColor(color, on: view) {
            applied.append("style.foregroundColor")
        } else {
            skipped.append("style.foregroundColor")
        }
    }
    if let alpha = finiteCGFloat(changes.alpha) {
        if let view {
            view.alpha = clamp(alpha, min: 0, max: 1)
            applied.append("style.alpha")
        } else {
            skipped.append("style.alpha")
        }
    }
    if let cornerRadius = finiteCGFloat(changes.cornerRadius) {
        if let layer {
            layer.cornerRadius = max(0, cornerRadius)
            applied.append("style.cornerRadius")
        } else {
            skipped.append("style.cornerRadius")
        }
    }
}

@MainActor
private func setNodeText(_ text: String, on view: UIView) -> Bool {
    if let label = view as? UILabel {
        label.text = text
        return true
    }
    if let button = view as? UIButton {
        button.setTitle(text, for: .normal)
        return true
    }
    if let textField = view as? UITextField {
        textField.text = text
        return true
    }
    if let textView = view as? UITextView {
        textView.text = text
        return true
    }
    return false
}

@MainActor
private func setNodeForegroundColor(_ color: UIColor, on view: UIView) -> Bool {
    if let label = view as? UILabel {
        label.textColor = color
        return true
    }
    if let button = view as? UIButton {
        button.setTitleColor(color, for: .normal)
        return true
    }
    if let textField = view as? UITextField {
        textField.textColor = color
        return true
    }
    if let textView = view as? UITextView {
        textView.textColor = color
        return true
    }
    return false
}

private func appendChangedFrameFields(_ changes: TKNodeFramePropertyChanges, prefix: String, into fields: inout [String]) {
    if changes.x != nil { fields.append("\(prefix).x") }
    if changes.y != nil { fields.append("\(prefix).y") }
    if changes.width != nil { fields.append("\(prefix).width") }
    if changes.height != nil { fields.append("\(prefix).height") }
}

private func appendChangedViewFields(_ changes: TKNodeViewPropertyChanges, prefix: String, into fields: inout [String]) {
    if changes.isHidden != nil { fields.append("\(prefix).isHidden") }
    if changes.alpha != nil { fields.append("\(prefix).alpha") }
    if changes.isUserInteractionEnabled != nil { fields.append("\(prefix).isUserInteractionEnabled") }
    if changes.accessibilityIdentifier != nil { fields.append("\(prefix).accessibilityIdentifier") }
    if changes.accessibilityLabel != nil { fields.append("\(prefix).accessibilityLabel") }
}

private func appendChangedLayerFields(_ changes: TKNodeLayerPropertyChanges, prefix: String, into fields: inout [String]) {
    if changes.isHidden != nil { fields.append("\(prefix).isHidden") }
    if changes.masksToBounds != nil { fields.append("\(prefix).masksToBounds") }
    if changes.opacity != nil { fields.append("\(prefix).opacity") }
    if changes.cornerRadius != nil { fields.append("\(prefix).cornerRadius") }
    if changes.zPosition != nil { fields.append("\(prefix).zPosition") }
}

private func finiteCGFloat(_ value: Double?) -> CGFloat? {
    guard let value, value.isFinite else { return nil }
    return CGFloat(value)
}

private func finiteFloat(_ value: Double?) -> Float? {
    guard let value, value.isFinite else { return nil }
    return Float(value)
}

private func clamp<T: Comparable>(_ value: T, min lower: T, max upper: T) -> T {
    Swift.max(lower, Swift.min(upper, value))
}

private extension UIColor {
    convenience init?(tritonHexString: String) {
        var text = tritonHexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6 || text.count == 8,
              let raw = UInt64(text, radix: 16) else {
            return nil
        }

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64
        if text.count == 8 {
            red = (raw >> 24) & 0xff
            green = (raw >> 16) & 0xff
            blue = (raw >> 8) & 0xff
            alpha = raw & 0xff
        } else {
            red = (raw >> 16) & 0xff
            green = (raw >> 8) & 0xff
            blue = raw & 0xff
            alpha = 0xff
        }
        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }
}
#endif
