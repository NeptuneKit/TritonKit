import Foundation
import TritonKitShared
#if canImport(UIKit)
import UIKit
#endif

extension TritonKitRequestHandler {
    func handleHierarchyDetails(_ message: TKMessage) async -> TKMessage? {
        let result: TKHierarchyDetailsResponse
        guard let payload = message.payload,
              let request = try? JSONDecoder().decode(TKHierarchyDetailsRequest.self, from: payload),
              request.validationError == nil else {
            result = .init(ok: false, error: .init(code: "validation_failed",
                message: "Expected 1...8 unique positive oids and maxPixelCount in 1...1048576"))
            return TKMessage(id: message.id, type: .hierarchyDetails, payload: try? JSONEncoder().encode(result))
        }
        guard TritonKit.isRuntimeEnabled else {
            result = .init(ok: false, error: .init(code: "runtime_disabled", message: "Inspection requires a Debug runtime"))
            return TKMessage(id: message.id, type: .hierarchyDetails, payload: try? JSONEncoder().encode(result))
        }
        #if canImport(UIKit)
        result = await MainActor.run { collectHierarchyDetails(request) }
        #else
        result = .init(ok: false, error: .init(code: "unsupported_platform", message: "Node details require UIKit"))
        #endif
        return TKMessage(id: message.id, type: .hierarchyDetails, payload: try? JSONEncoder().encode(result))
    }
}

#if canImport(UIKit)
@MainActor
private func collectHierarchyDetails(_ request: TKHierarchyDetailsRequest) -> TKHierarchyDetailsResponse {
    // These budgets apply to the whole request, independently of its OID count.
    var remainingPixels = 4_194_304
    var remainingBytes = 4_194_304
    let deadline = ProcessInfo.processInfo.systemUptime + 2
    var details: [TKDisplayItemDetail] = []
    var hasReadableMetadata = false
    for oid in request.oids {
        if Task.isCancelled {
            details.append(.init(displayItemOid: oid, failureCode: 1, failureReason: "request_cancelled"))
            continue
        }
        if ProcessInfo.processInfo.systemUptime >= deadline {
            details.append(.init(displayItemOid: oid, failureCode: 1, failureReason: "budget_exceeded"))
            continue
        }
        guard let object = TKObjectRegistry.shared.object(for: oid) else {
            details.append(.init(displayItemOid: oid, failureCode: 1, failureReason: "object_not_found"))
            continue
        }
        let layer: CALayer
        if let view = object as? UIView { layer = view.layer }
        else if let objectLayer = object as? CALayer { layer = objectLayer }
        else {
            details.append(.init(displayItemOid: oid, failureCode: 1, failureReason: "unsupported_object"))
            continue
        }
        guard !layer.tk_isInspectorOverlay else {
            details.append(.init(displayItemOid: oid, failureCode: 1, failureReason: "unsupported_object"))
            continue
        }
        var group: Data?
        var solo: Data?
        var scale: Double?
        var failureReason: String?
        // Group first; it cannot observe the temporary solo exclusion state.
        let modes: [Bool]
        switch request.screenshots {
        case .none: modes = []
        case .solo: modes = [true]
        case .group: modes = [false]
        case .both: modes = [false, true]
        }
        let nodePixelLimit = min(request.maxPixelCount, remainingPixels / max(1, modes.count))
        for isSolo in modes {
            if Task.isCancelled { failureReason = "request_cancelled"; break }
            guard ProcessInfo.processInfo.systemUptime < deadline,
                  remainingPixels > 0, remainingBytes > 0 else {
                failureReason = "budget_exceeded"
                break
            }
            let capture = TKLayerScreenshotCapture.capture(layer, solo: isSolo,
                maxPixelCount: nodePixelLimit)
            remainingPixels -= capture.pixelCount
            guard let data = capture.data else {
                failureReason = capture.failureReason ?? "screenshot_unavailable"
                break
            }
            guard data.count <= remainingBytes else { failureReason = "budget_exceeded"; break }
            remainingBytes -= data.count
            scale = capture.scale
            if isSolo { solo = data } else { group = data }
            if Task.isCancelled { failureReason = "request_cancelled"; break }
            if ProcessInfo.processInfo.systemUptime >= deadline { failureReason = "budget_exceeded"; break }
        }
        let canReadAttributes = ProcessInfo.processInfo.systemUptime < deadline && !Task.isCancelled
        let attrs = request.includeAttributes && canReadAttributes ? TKAttributeGroupsBuilder.build(for: layer) : []
        if request.includeAttributes && !canReadAttributes {
            failureReason = Task.isCancelled ? "request_cancelled" : "budget_exceeded"
        }
        details.append(TKDisplayItemDetail(displayItemOid: oid,
            groupScreenshot: group, soloScreenshot: solo,
            frameValue: layer.tk_inspectionFrame, boundsValue: layer.bounds,
            hiddenValue: layer.isHidden, alphaValue: layer.opacity,
            attributesGroupList: attrs, failureCode: failureReason == nil ? 0 : 1,
            failureReason: failureReason, screenshotScale: scale))
        // A real resolved layer still supplies useful geometry/attributes when
        // its screenshot is unavailable. Do not infer this from the default
        // zero geometry on object-not-found/budget failure placeholders.
        hasReadableMetadata = true
    }
    let failed = details.contains { $0.failureCode != 0 }
    let hasResult = hasReadableMetadata || details.contains { $0.failureCode == 0 || $0.soloScreenshot != nil || $0.groupScreenshot != nil }
    return .init(ok: !failed, partial: failed && hasResult, details: details,
        error: failed ? .init(code: hasResult ? "details_partial" : "details_failed",
                             message: "One or more nodes could not be fully inspected; see failureReason") : nil)
}
#endif
