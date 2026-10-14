import Foundation
import ArgumentParser

// Environment controls report host configuration separately from App/business acceptance.
enum DeviceOrientationValue: String, ExpressibleByArgument, CaseIterable {
    case portrait
    case landscapeLeft = "landscape-left"
    case landscapeRight = "landscape-right"
    case upsideDown = "portrait-upside-down"
    var rotation: Int { switch self { case .portrait: 0; case .landscapeLeft: 1; case .upsideDown: 2; case .landscapeRight: 3 } }
    static func from(rotation: Int) -> Self? { allCases.first { $0.rotation == rotation } }
}
enum DeviceFoldValue: String, ExpressibleByArgument { case folded, halfOpen = "half-open", open }
enum DeviceEnvironmentOperation: String {
    case orientationGet = "orientation.get", orientationSet = "orientation.set", fold, locationSet = "location.set", locationClear = "location.clear", clipboardGet = "clipboard.get", clipboardSet = "clipboard.set", foreground
}
struct DeviceEnvironmentFailure: Encodable, Error { let code: String; let message: String }
struct DeviceEnvironmentOutput: Encodable {
    var ok = true
    let action: String
    let target: HostDeviceTarget
    let source: String
    var supported = true
    var executed = false
    var verified = false
    var previous: [String: String]?
    var requested: [String: String]?
    var observed: [String: String]?
    var sourceCommands: [String] = []
    var error: DeviceEnvironmentFailure?
    var note: String?
    var businessReadinessVerified = false
}
