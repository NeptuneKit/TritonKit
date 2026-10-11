import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Apple specialized platform controls remain explicit fixture-only contracts")
struct ApplePlatformControlTests {
    @Test("device parser and schema expose the explicit control boundary")
    func parserAndSchemaSurface() throws {
        let command = try TritonKitCLI.parseAsRoot(["device", "platform-control", "--platform", "tvos", "--action", "focus", "--json"])
        #expect(command is DevicePlatformControl)
        let device = try #require(commandSchemas().first { $0.name == "device" })
        let control = try #require(device.subcommands.first { $0.name == "platform-control" })
        #expect(control.requiredOptions == ["--platform", "--action"])
        #expect(control.optionalOptions.contains("--delta"))
        #expect(control.outputSelectors == ["host.apple-platform-control"])
        #expect(commandSchemas().flatMap(\.outputContracts).contains { $0.selector == "host.apple-platform-control" })
    }

    @Test("watchOS Crown and Action map only to public XCTest symbols")
    func watchContractsAreFixtureOnly() throws {
        let crown = try makeApplePlatformControlPlan(platform: .watchos, action: .crownRotate, crownDelta: 1.5)
        #expect(crown.capabilityState == .fixtureOnly)
        #expect(crown.sourceAPI == "XCUIDevice.shared.rotateDigitalCrown(delta:)")
        #expect(crown.crownDelta == 1.5)
        #expect(crown.executable == false && crown.actionsExecuted == false)

        let action = try makeApplePlatformControlPlan(platform: .watchos, action: .actionButton)
        #expect(action.capabilityState == .fixtureOnly)
        #expect(action.sourceAPI == "XCUIDevice.shared.press(.action)")
    }

    @Test("Crown delta validation fails before any backend")
    func crownDeltaValidation() {
        #expect(throws: HostApplePlatformControlError.self) {
            _ = try makeApplePlatformControlPlan(platform: .watchos, action: .crownRotate)
        }
        #expect(throws: HostApplePlatformControlError.self) {
            _ = try makeApplePlatformControlPlan(platform: .tvos, action: .focus, crownDelta: 1)
        }
    }

    @Test("tvOS remote and focus map to public XCTest symbols")
    func tvContractsAreFixtureOnly() throws {
        for input in [HostApplePlatformControlAction.remoteUp, .remoteDown, .remoteLeft, .remoteRight, .remoteSelect, .remoteMenu] {
            let output = try makeApplePlatformControlPlan(platform: .tvos, action: input)
            #expect(output.capabilityState == .fixtureOnly)
            #expect(output.sourceAPI == "XCUIRemote.shared.press(_:)")
            #expect(output.actionsExecuted == false)
        }
        let focus = try makeApplePlatformControlPlan(platform: .tvos, action: .focus)
        #expect(focus.capabilityState == .fixtureOnly)
        #expect(focus.sourceAPI == "XCUIElement.hasFocus")
    }

    @Test("visionOS, macOS and watch side key fail closed")
    func unsupportedControlsRemainUnsupported() throws {
        for (platform, action) in [
            (HostApplePlatformControlPlatform.visionos, HostApplePlatformControlAction.gaze),
            (.visionos, .pinch),
            (.visionos, .scene),
            (.macos, .focus),
            (.watchos, .sideButton),
            (.tvos, .crownRotate)
        ] {
            let output = try makeApplePlatformControlPlan(platform: platform, action: action)
            #expect(output.capabilityState == .unsupported)
            #expect(output.backend == nil)
            #expect(output.executable == false && output.actionsExecuted == false)
        }
    }

    @Test("control output redacts target and command details")
    func outputHasNoTargetOrCommandEcho() throws {
        let output = try makeApplePlatformControlPlan(platform: .tvos, action: .remoteSelect)
        let json = try encodeJSON(output)
        #expect(!json.contains("PRIVATE"))
        #expect(!json.contains("xcrun"))
        #expect(json.contains("fixture-only"))
    }
}
