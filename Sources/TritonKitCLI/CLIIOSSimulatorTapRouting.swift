import Foundation
import TritonKitShared

struct HIDOnlyTapValidationError: Error {
    let code: String
    let message: String
    let hint: String
}

struct IOSHostCoordinateTapRequest: Equatable {
    let device: String?
    let x: Double
    let y: Double
}

extension Tap {
    /// Pure preflight: reject incompatible modes before selection, runtime, WebView or host I/O.
    func hidOnlyCoordinateTapRequest() throws -> IOSHostCoordinateTapRequest? {
        guard hidOnly else { return nil }
        let hint = "Use --hid-only with only --x/--y or --at and an iOS Simulator selector; omit it for AX, embedded, or WebView actions."
        guard platform == nil || platform == .ios else {
            throw HIDOnlyTapValidationError(code: "unsupported_capability", message: "--hid-only supports only local iOS Simulator coordinate taps; no input was dispatched.", hint: hint)
        }
        guard selection == nil, selectionRevision == nil, runtimeInstanceID == nil,
              query == nil, text == nil, oid == nil, axOID == nil, axLabel == nil,
              !webViewAware, selector == nil, webViewID == nil, pageSessionID == nil, expectText == nil, timeout == 3,
              strategy == nil, index == nil, within == nil, duration == nil,
              width == nil, height == nil, !allowHostHIDFallback else {
            throw HIDOnlyTapValidationError(code: "validation_failed", message: "--hid-only requires a pure coordinate tap and cannot be combined with semantic, selection, WebView, geometry override, duration, or fallback options; no input was dispatched.", hint: hint)
        }
        let device: String?
        if platform == .ios && target == TKLocalTargetID {
            device = nil
        } else if let explicitSelector = iosHostSimulatorSelector(target) {
            device = explicitSelector
        } else {
            throw HIDOnlyTapValidationError(code: "unsupported_capability", message: "--hid-only requires --platform ios or an explicit Simulator selector (sim:<udid>, raw UUID, booted, or current); embedded and physical-device targets are unsupported and no input was dispatched.", hint: hint)
        }
        guard (at != nil && x == nil && y == nil) || (at == nil && x != nil && y != nil) else {
            throw HIDOnlyTapValidationError(code: "validation_failed", message: "--hid-only requires exactly one coordinate selector: --x with --y, or --at x,y; no input was dispatched.", hint: hint)
        }
        let point: (x: Double, y: Double)
        if let at {
            do {
                point = try parsePoint(at)
            } catch {
                throw HIDOnlyTapValidationError(code: "validation_failed", message: "--hid-only requires --at x,y with finite coordinates; no input was dispatched.", hint: hint)
            }
        } else if let x, let y {
            point = (x, y)
        } else {
            throw HIDOnlyTapValidationError(code: "validation_failed", message: "--hid-only requires a coordinate pair; no input was dispatched.", hint: hint)
        }
        guard point.x.isFinite, point.y.isFinite else {
            throw HIDOnlyTapValidationError(code: "validation_failed", message: "--hid-only coordinates must be finite; no input was dispatched.", hint: hint)
        }
        return IOSHostCoordinateTapRequest(device: device, x: point.x, y: point.y)
    }
}

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

    return iosHostSimulatorSelector(target)
}

private func iosHostSimulatorSelector(_ target: String) -> String? {
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
