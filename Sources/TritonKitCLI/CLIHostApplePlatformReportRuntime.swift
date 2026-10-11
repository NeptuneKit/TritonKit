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
        HostApplePlatformProfile(family: .ios, integrationState: "partial", legacyDeviceNamespace: "ios", existingEntryPoints: ["device list/info/files/mountpoint/fs list", "sim lifecycle/artifacts", "device containers SDK binding/native Simulator metadata", "device pair/unpair/diagnose explicit execution policy (fixture-tested)"], missingCapabilities: ["Complete Device Hub control coverage", "Physical administration live acceptance", "DeviceFS bundle/group mapping remains separate from SDK native binding; Temporary creation observation unknown"]),
        HostApplePlatformProfile(family: .ipados, integrationState: "shared-ios-adapter-not-separate-platform-acceptance", legacyDeviceNamespace: "ios", existingEntryPoints: ["Existing ios adapter entrypoints; not per-iPad acceptance"], missingCapabilities: ["Hardware-specific inventory/classification acceptance", "Dedicated iPadOS control/acceptance matrix; never inferred from names/iOS runtime"]),
        HostApplePlatformProfile(family: .watchos, integrationState: "specialized-control-not-integrated", legacyDeviceNamespace: "ios", existingEntryPoints: ["Generic Simulator discovery/lifecycle command surface", "sim pairs native relationship metadata; sim pair/unpair (not physical pairing or watch input proof)", "device platforms --include-real-devices independent exact hardware inventory"], missingCapabilities: ["Crown/side/Action input contract and acceptance", "Physical watch control and per-family live acceptance"]),
        HostApplePlatformProfile(family: .tvos, integrationState: "specialized-control-not-integrated", legacyDeviceNamespace: "ios", existingEntryPoints: ["Generic Simulator discovery/lifecycle command surface"], missingCapabilities: ["Focus/select/back dedicated contract and acceptance", "Physical tvOS control and per-family live acceptance"]),
        HostApplePlatformProfile(family: .visionos, integrationState: "specialized-control-not-integrated", legacyDeviceNamespace: "ios", existingEntryPoints: ["Generic Simulator discovery/lifecycle command surface"], missingCapabilities: ["Gaze/pinch/camera/view/scene/SharePlay/controller dedicated public backend and acceptance", "Physical viewing/input restrictions require separate current official evidence; not inferred here"]),
        HostApplePlatformProfile(family: .macos, integrationState: "xcode-workflow-only-not-device-hub-control", legacyDeviceNamespace: nil, existingEntryPoints: ["xcode build/test workflow command surface"], missingCapabilities: ["Device Hub macOS observation/control contract", "Not a CoreSimulator runtime or ios real target assumption"])
    ]
}

func makeApplePlatformReport(inventory: Bool = false, family: HostApplePlatformFamily? = nil, includeRealDevices: Bool = false, device: String? = nil, simulatorProvider: (() throws -> [HostDeviceTarget])? = nil, physicalProvider: (() throws -> Data)? = nil) throws -> HostApplePlatformReport {
    guard family != .unknown else { throw HostDeviceSelectionError.parameterConflict("Choose a known Apple catalog family; unknown is metadata classification only, not a control selector.") }
    if let device {
        guard includeRealDevices, !device.isEmpty, device.utf8.count <= 1024,
              device == device.trimmingCharacters(in: .whitespacesAndNewlines),
              !device.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw HostDeviceSelectionError.parameterConflict("A metadata --device selector requires --include-real-devices and one exact primary identifier or apple-physical inventory ID.")
        }
    }
    let profiles = applePlatformProfiles().filter { family == nil || $0.family == family }
    var counts: [HostApplePlatformFamily: Int] = [:]
    var sources: [String] = []
    var physicalDevices: [TKApplePhysicalInventoryDevice] = []
    do {
        if inventory {
            let targets = try (simulatorProvider ?? { try hostDeviceTargets(platform: .ios, scope: .simulator, hdc: "hdc", adb: "adb").targets })()
            for target in targets { counts[appleSimulatorPlatformFamily(runtime: target.runtime), default: 0] += 1 }
            sources.append(hostSourceCommand(TKSimctlCommand.listAvailableDevices()))
        }
        if includeRealDevices {
            physicalDevices = try TKApplePhysicalInventoryParser.parse((physicalProvider ?? applePhysicalInventoryJSON)())
            sources.append("/usr/bin/xcrun devicectl list devices --json-output <private-json> --log-output <private-log>")
        }
    } catch { throw HostApplePlatformInventoryFailure(error) }
    if let device {
        physicalDevices = physicalDevices.filter { $0.matches(selector: device) }
        guard physicalDevices.count == 1 else { throw HostDeviceSelectionError.parameterConflict("The exact metadata selector did not match exactly one explicitly physical device in this fresh inventory.") }
    }
    return HostApplePlatformReport(profiles: profiles, inventoryObserved: inventory, simulatorCounts: inventory ? HostApplePlatformFamily.allCases.map { HostAppleSimulatorPlatformCount(family: $0, count: counts[$0, default: 0]) } : [], sourceCommands: sources, physicalInventoryObserved: includeRealDevices, physicalDevices: physicalDevices)
}

private func applePhysicalInventoryJSON() throws -> Data {
    let paths = try freshDeviceInfoArtifactPaths(action: "apple-physical-inventory")
    defer {
        for path in [paths.json, paths.log] where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
    }
    let result = try runHostCommand(TKDevicectlCommand.listDevices(jsonOutput: paths.json, logOutput: paths.log))
    guard result.exitCode == 0 else { throw TKApplePhysicalInventoryError.invalidJSON }
    return try readBoundedDeviceFilesJSON(paths.json, maximumBytes: 1_048_576)
}
