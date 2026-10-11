import Foundation

private let publicFixtureBackend = "public-xctest-api-fixture"
private let fixtureVerification = "public-xctest-contract-fixture-only; no host runner or device action executed"

private struct ControlDescriptor {
    let platform: HostApplePlatformControlPlatform
    let action: HostApplePlatformControlAction
    let sourceAPI: String
}

private func controlDescriptor(platform: HostApplePlatformControlPlatform, action: HostApplePlatformControlAction) -> ControlDescriptor? {
    switch (platform, action) {
    case (.watchos, .crownRotate):
        return ControlDescriptor(platform: platform, action: action, sourceAPI: "XCUIDevice.shared.rotateDigitalCrown(delta:)")
    case (.watchos, .actionButton):
        return ControlDescriptor(platform: platform, action: action, sourceAPI: "XCUIDevice.shared.press(.action)")
    case (.tvos, .remoteUp), (.tvos, .remoteDown), (.tvos, .remoteLeft), (.tvos, .remoteRight), (.tvos, .remoteSelect), (.tvos, .remoteMenu):
        return ControlDescriptor(platform: platform, action: action, sourceAPI: "XCUIRemote.shared.press(_:)")
    case (.tvos, .focus):
        return ControlDescriptor(platform: platform, action: action, sourceAPI: "XCUIElement.hasFocus")
    default:
        return nil
    }
}

func makeApplePlatformControlPlan(platform: HostApplePlatformControlPlatform, action: HostApplePlatformControlAction, crownDelta: Double? = nil) throws -> HostApplePlatformControlOutput {
    if platform == .watchos && action == .crownRotate {
        guard let crownDelta, crownDelta.isFinite, abs(crownDelta) <= 1000, crownDelta != 0 else {
            throw HostApplePlatformControlError(code: "invalid_crown_delta", message: "watchOS Crown control requires one finite non-zero delta between -1000 and 1000.", hint: "Pass --delta <number>; no device action was executed.")
        }
    } else if crownDelta != nil {
        throw HostApplePlatformControlError(code: "unexpected_crown_delta", message: "--delta is valid only for watchOS crown-rotate.", hint: "Remove --delta for Action, tvOS remote/focus, visionOS, or macOS contracts.")
    }
    if let descriptor = controlDescriptor(platform: platform, action: action) {
        return HostApplePlatformControlOutput(
            platform: descriptor.platform,
            control: descriptor.action,
            crownDelta: crownDelta,
            capabilityState: .fixtureOnly,
            backend: publicFixtureBackend,
            backendKind: "public-xctest-api",
            sourceAPI: descriptor.sourceAPI,
            verification: fixtureVerification,
            limitations: [
                "This request only describes a public XCTest contract; explicit runner execution requires a dedicated built artifact, exact target and complete execution policy.",
                "No simulator, physical device, app, focus tree, Crown delta, or remote event was read or changed.",
                "A fixture-only result must not be reported as input delivery or business-state completion."
            ]
        )
    }

    let familyHint: String
    switch platform {
    case .visionos: familyHint = "visionOS spatial/gaze/scene controls have no verified headless host backend in this surface."
    case .macos: familyHint = "macOS is limited to the Xcode workflow surface; Device Hub input control is not defined here."
    case .watchos: familyHint = "The public XCTest vocabulary does not provide a precise generic watch side-key control for this contract."
    case .tvos: familyHint = "Only XCUIRemote navigation and XCUIElement.hasFocus are recorded; this action is outside that public vocabulary."
    }
    return HostApplePlatformControlOutput(
        platform: platform,
        control: action,
        crownDelta: crownDelta,
        capabilityState: .unsupported,
        backend: nil,
        backendKind: "none",
        sourceAPI: nil,
        verification: "unsupported-contract; no host runner or device action executed",
        limitations: [familyHint, "Do not infer support from SDK capability names, platform catalogue rows, or simulator availability."]
    )
}
