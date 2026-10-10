import Foundation
import TritonKitShared

func appleSimulatorPlatformFamily(runtime: String?) -> HostApplePlatformFamily {
    guard let runtime, runtime.utf8.count <= 256, runtime.utf8.allSatisfy({ $0 >= 32 && $0 <= 126 }) else { return .unknown }
    let prefix = "com.apple.CoreSimulator.SimRuntime."
    for (name, family) in [("iOS", HostApplePlatformFamily.ios), ("watchOS", .watchos), ("tvOS", .tvos), ("xrOS", .visionos), ("visionOS", .visionos)] {
        let key = prefix + name + "-"
        guard runtime.hasPrefix(key) else { continue }
        let version = runtime.dropFirst(key.count).split(separator: "-", omittingEmptySubsequences: false)
        guard (1...4).contains(version.count), version.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 8 && $0.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } }) else { return .unknown }
        return family
    }
    return .unknown
}

private func applePlatformProfiles() -> [HostApplePlatformProfile] {
    [
        HostApplePlatformProfile(family: .ios, integrationState: "partial", legacyDeviceNamespace: "ios", existingEntryPoints: ["device list/info/files/mountpoint/fs list", "sim lifecycle/artifacts", "device pair/unpair/diagnose --plan-only"], missingCapabilities: ["Complete Device Hub control coverage", "Accepted real administration execution/postconditions/archive policy", "DeviceFS semantic container/crash/Temporary domains"]),
        HostApplePlatformProfile(family: .ipados, integrationState: "shared-ios-adapter-not-separate-platform-acceptance", legacyDeviceNamespace: "ios", existingEntryPoints: ["Existing ios adapter entrypoints; not per-iPad acceptance"], missingCapabilities: ["Hardware-specific inventory/classification acceptance", "Dedicated iPadOS control/acceptance matrix; never inferred from names/iOS runtime"]),
        HostApplePlatformProfile(family: .watchos, integrationState: "specialized-control-not-integrated", legacyDeviceNamespace: "ios", existingEntryPoints: ["Generic Simulator discovery/lifecycle command surface", "sim pair/unpair (not physical pairing or watch input proof)"], missingCapabilities: ["Crown/side/Action input contract and acceptance", "Physical watch metadata/control contracts"]),
        HostApplePlatformProfile(family: .tvos, integrationState: "specialized-control-not-integrated", legacyDeviceNamespace: "ios", existingEntryPoints: ["Generic Simulator discovery/lifecycle command surface"], missingCapabilities: ["Focus/select/back dedicated contract and acceptance", "Physical tvOS contracts"]),
        HostApplePlatformProfile(family: .visionos, integrationState: "specialized-control-not-integrated", legacyDeviceNamespace: "ios", existingEntryPoints: ["Generic Simulator discovery/lifecycle command surface"], missingCapabilities: ["Gaze/pinch/camera/view/scene/SharePlay/controller dedicated public backend and acceptance", "Physical viewing/input restrictions require separate current official evidence; not inferred here"]),
        HostApplePlatformProfile(family: .macos, integrationState: "xcode-workflow-only-not-device-hub-control", legacyDeviceNamespace: nil, existingEntryPoints: ["xcode build/test workflow command surface"], missingCapabilities: ["Device Hub macOS observation/control contract", "Not a CoreSimulator runtime or ios real target assumption"])
    ]
}

func makeApplePlatformReport(inventory: Bool = false, family: HostApplePlatformFamily? = nil, simulatorProvider: (() throws -> [HostDeviceTarget])? = nil) throws -> HostApplePlatformReport {
    guard family != .unknown else { throw HostDeviceSelectionError.parameterConflict("Choose a known Apple catalog family; unknown is metadata classification only, not a control selector.") }
    let profiles = applePlatformProfiles().filter { family == nil || $0.family == family }
    guard inventory else { return HostApplePlatformReport(profiles: profiles, inventoryObserved: false, simulatorCounts: [], sourceCommands: []) }
    let targets: [HostDeviceTarget]
    do { targets = try (simulatorProvider ?? { try hostDeviceTargets(platform: .ios, scope: .simulator, hdc: "hdc", adb: "adb").targets })() }
    catch { throw HostApplePlatformInventoryFailure(error) }
    var counts: [HostApplePlatformFamily: Int] = [:]
    for target in targets { counts[appleSimulatorPlatformFamily(runtime: target.runtime), default: 0] += 1 }
    return HostApplePlatformReport(profiles: profiles, inventoryObserved: true, simulatorCounts: HostApplePlatformFamily.allCases.map { HostAppleSimulatorPlatformCount(family: $0, count: counts[$0, default: 0]) }, sourceCommands: [hostSourceCommand(TKSimctlCommand.listAvailableDevices())])
}
