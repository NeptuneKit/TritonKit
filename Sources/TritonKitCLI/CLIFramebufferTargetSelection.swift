import Foundation
import TritonKitShared

/// Resolve only the platform used by this framebuffer route. Foreground app
/// metadata is not needed to subscribe to an explicitly selected device.
func resolveFramebufferTarget(
    platform: HostDevicePlatform,
    target: String,
    hdc: String,
    adb: String = "adb",
    runner: HostDeviceCommandRunner = { try runHostCommand($0) },
    aliases: HostTargetAliasStore? = nil,
    liveCurrentResolver: (() throws -> HostDeviceSelectionResult)? = nil
) throws -> String {
    guard platform != .ios else {
        throw HostDeviceSelectionError.parameterConflict("iOS framebuffer targets use the simulator resolver")
    }
    var selector = target.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selector.isEmpty else {
        throw HostDeviceSelectionError.targetNotFound(target)
    }
    if selector.hasPrefix("host:") {
        guard let hostTarget = parseWebHostTargetID(selector) else {
            throw HostDeviceSelectionError.targetNotFound(selector)
        }
        guard hostTarget.platform == platform else {
            throw HostDeviceSelectionError.platformMismatch(
                selector: selector, expected: platform, actual: hostTarget.platform
            )
        }
        selector = hostTarget.selector
    }

    let aliasStore = try aliases ?? loadHostTargetAliasStore()
    let targets: [HostDeviceTarget]
    switch platform {
    case .harmony:
        // Enriched discovery queries foreground apps on every online target.
        // A selected framebuffer only needs target identity and readiness.
        targets = try harmonyTargets(hdc: hdc, runner: runner).targets.map(hostDeviceTarget(from:))
    case .android:
        let result = try runner(TKAndroidADBCommand.listDevices(executable: adb))
        targets = TKAdbDeviceListParser.targets(
            TKAdbDeviceListParser.parse(result.stdout), matching: nil
        ).map(hostDeviceTarget(from:))
    case .ios:
        throw HostDeviceSelectionError.parameterConflict("iOS framebuffer targets use the simulator resolver")
    }

    let selected: HostDeviceSelectionResult
    do {
        selected = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(device: selector, platform: platform),
            candidates: [platform: targets],
            aliases: aliasStore
        )
    } catch HostDeviceSelectionError.targetNotFound(let missing) where selector == "current" {
        guard let liveCurrentResolver else {
            throw HostDeviceSelectionError.targetNotFound(missing)
        }
        selected = try liveCurrentResolver()
    }
    guard selected.platform == platform else {
        throw HostDeviceSelectionError.platformMismatch(
            selector: selector, expected: platform, actual: selected.platform
        )
    }
    guard selected.target.ready else {
        throw HostDeviceRunError.targetOffline(selected.target.rawTarget)
    }
    return selected.target.rawTarget
}
