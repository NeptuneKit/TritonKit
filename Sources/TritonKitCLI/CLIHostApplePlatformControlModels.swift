import ArgumentParser
import Foundation

/// The Apple platform controls that have a public XCTest vocabulary but no
/// Triton host runner yet. These values are intentionally narrower than the
/// platform catalogue: a catalogue entry is not evidence of an executor.
enum HostApplePlatformControlPlatform: String, CaseIterable, Codable, ExpressibleByArgument {
    case watchos
    case tvos
    case visionos
    case macos
}

enum HostApplePlatformControlAction: String, CaseIterable, Codable, ExpressibleByArgument {
    case crownRotate = "crown-rotate"
    case actionButton = "action-button"
    case remoteUp = "remote-up"
    case remoteDown = "remote-down"
    case remoteLeft = "remote-left"
    case remoteRight = "remote-right"
    case remoteSelect = "remote-select"
    case remoteMenu = "remote-menu"
    case focus = "focus"
    case gaze = "gaze"
    case pinch = "pinch"
    case scene = "scene"
    case sideButton = "side-button"
}

enum HostApplePlatformControlCapabilityState: String, Codable {
    case fixtureOnly = "fixture-only"
    case unsupported
}

struct HostApplePlatformControlOutput: Encodable, Equatable {
    let ok = true
    let action = "device.platform-control"
    let platform: HostApplePlatformControlPlatform
    let control: HostApplePlatformControlAction
    let crownDelta: Double?
    let capabilityState: HostApplePlatformControlCapabilityState
    let executable = false
    let actionsExecuted = false
    let backend: String?
    let backendKind: String
    let sourceAPI: String?
    let verification: String
    let limitations: [String]
}

struct HostApplePlatformControlError: Error, CustomStringConvertible, Equatable {
    let code: String
    let message: String
    let hint: String
    var description: String { message }
}
