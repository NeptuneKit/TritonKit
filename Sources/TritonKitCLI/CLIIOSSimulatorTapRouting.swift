import Foundation
import TritonKitShared

func implicitIOSHostCoordinateTapSelector(
    platform: HostPlatform?,
    target: String,
    query: String?,
    x: Double?,
    y: Double?,
    at: String?,
    oid: UInt?,
    axOID: UInt?,
    axLabel: String?
) -> String? {
    guard platform == nil,
          query == nil,
          oid == nil,
          axOID == nil,
          axLabel == nil,
          at != nil || (x != nil && y != nil) else {
        return nil
    }

    let selector = target.trimmingCharacters(in: .whitespacesAndNewlines)
    if selector == "booted" || selector == "current" {
        return selector
    }
    if UUID(uuidString: selector) != nil {
        return selector
    }
    guard selector.hasPrefix("sim:") else {
        return nil
    }
    let simulatorUDID = String(selector.dropFirst("sim:".count))
    guard UUID(uuidString: simulatorUDID) != nil else {
        return nil
    }
    return selector
}

func shouldRouteImplicitIOSHostCoordinateTap(
    platform: HostPlatform?,
    target: String,
    query: String?,
    x: Double?,
    y: Double?,
    at: String?,
    oid: UInt?,
    axOID: UInt?,
    axLabel: String?
) -> Bool {
    implicitIOSHostCoordinateTapSelector(
        platform: platform,
        target: target,
        query: query,
        x: x,
        y: y,
        at: at,
        oid: oid,
        axOID: axOID,
        axLabel: axLabel
    ) != nil
}
