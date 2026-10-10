import Foundation

// Joining discovery sources must not replace primary lifecycle/App facts or lose
// the secondary backend's selector identity. Aliases stay outside CodingKeys.
func mergingHostDeviceAliases(_ primary: HostDeviceTarget, from secondary: HostDeviceTarget) -> HostDeviceTarget {
    let aliases = Set(primary.rawTargetAliases + secondary.rawTargetAliases + [secondary.rawTarget])
        .filter { !$0.isEmpty && $0 != primary.rawTarget }
        .sorted()
    return HostDeviceTarget(
        platform: primary.platform,
        id: primary.id,
        target: primary.target,
        state: primary.state,
        ready: primary.ready,
        source: primary.source,
        name: primary.name,
        runtime: primary.runtime,
        transport: primary.transport,
        scope: primary.scope,
        kind: primary.kind,
        appName: primary.appName,
        bundleIdentifier: primary.bundleIdentifier,
        identityState: primary.identityState,
        current: primary.current,
        blockedReasons: primary.blockedReasons,
        sensitive: primary.sensitive,
        rawTarget: primary.rawTarget,
        rawTargetAliases: aliases
    )
}
