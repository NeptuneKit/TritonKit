import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct DeviceCrossPlatformTests {
    @Test("device schema exposes a cross-platform list/use/wait-ready/screenshot surface")
    func deviceSchemaExposesCrossPlatformSurface() throws {
        let device = try #require(commandSchemas().first { $0.name == "device" })
        let optionNames = device.options.map(\.name)

        #expect(optionNames.contains("doctor --platform ios|harmony"))
        #expect(optionNames.contains("list --platform ios|harmony"))
        #expect(optionNames.contains("alias set <name> --platform ios|harmony --target <id>"))
        #expect(optionNames.contains("use <selector>"))
        #expect(optionNames.contains("current"))
        #expect(optionNames.contains("resolve <selector>"))
        #expect(optionNames.contains("wait-ready --device <selector>"))
        #expect(optionNames.contains("screenshot --device <selector> --output <path>"))
        #expect(optionNames.contains("--device"))
        #expect(optionNames.contains("--name"))
        #expect(optionNames.contains("--runtime"))
        #expect(optionNames.contains("runtime-url --platform harmony --target <target>"))
        #expect(device.providedCapabilities.contains("host-device"))
        #expect(device.providedCapabilities.contains("device-alias"))
        #expect(device.providedCapabilities.contains("host-device-selector"))
        #expect(device.providedCapabilities.contains("device-list"))
        #expect(device.providedCapabilities.contains("device-use"))
        #expect(device.providedCapabilities.contains("device-wait-ready"))
        #expect(device.providedCapabilities.contains("device-screenshot"))
    }

    @Test("app and smoke schemas expose unified device selector with compatibility paths")
    func appAndSmokeSchemasExposeUnifiedDeviceSelector() throws {
        let app = try #require(commandSchemas().first { $0.name == "app" })
        let smoke = try #require(commandSchemas().first { $0.name == "smoke" })

        let appOptionNames = app.options.map(\.name)
        let smokeOptionNames = smoke.options.map(\.name)

        #expect(appOptionNames.contains("--device"))
        #expect(appOptionNames.contains("--simulator"))
        #expect(appOptionNames.contains("--target"))
        #expect(appOptionNames.contains("--name"))
        #expect(appOptionNames.contains("--runtime"))
        #expect(app.examples.contains("triton app list --device iphone15 --user-only --json"))
        #expect(app.examples.contains("triton app install --device harmony-a --hap /tmp/Demo.hap --json"))
        #expect(app.examples.contains("triton app prefs get DEBUG-mock --device iphone15 --bundle-id com.example.app --json"))

        #expect(smokeOptionNames.contains("--device"))
        #expect(smokeOptionNames.contains("--simulator"))
        #expect(smokeOptionNames.contains("--target"))
        #expect(smokeOptionNames.contains("--ready"))
        #expect(smoke.examples.contains("triton smoke ios --device iphone15 --bundle-id com.example.app --open-url myapp://home --wait-text Ready --json"))
        #expect(smoke.examples.contains("triton smoke harmony --device harmony-a --bundle com.example.app --ability EntryAbility --open-url example://home --wait-text Ready --screenshot /tmp/smoke.jpeg --evidence /tmp/harmony.tritonevidence --json"))
    }

    @Test("unified device selector rejects legacy selector conflicts")
    func unifiedDeviceSelectorRejectsLegacySelectorConflicts() {
        #expect(throws: HostDeviceSelectionError.self) {
            try ensureHostDeviceSelectorCompatibility(device: "iphone15", simulator: "booted", target: nil)
        }
        #expect(throws: HostDeviceSelectionError.self) {
            try ensureHostDeviceSelectorCompatibility(device: "harmony-a", simulator: nil, target: "127.0.0.1:10100")
        }
        #expect((try? ensureHostDeviceSelectorCompatibility(device: "iphone15", simulator: nil, target: nil)) != nil)
        #expect((try? ensureHostDeviceSelectorCompatibility(device: nil, simulator: "booted", target: nil)) != nil)
    }

    @Test("host device target mapping keeps a platform-neutral envelope")
    func hostDeviceTargetMappingKeepsAPlatformNeutralEnvelope() {
        let iosSimulator = TKHostSimulatorTarget(
            udid: "SIM-1",
            name: "iPhone 15",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
            state: "Booted",
            isAvailable: true,
            source: "simctl"
        )
        let harmonyTarget = TKHarmonyTarget(target: "127.0.0.1:10100", state: "Connected", transport: "TCP", source: "hdc")

        let ios = hostDeviceTarget(from: iosSimulator)
        let harmony = hostDeviceTarget(from: harmonyTarget)

        #expect(ios.platform == "ios")
        #expect(ios.id == "sim:SIM-1")
        #expect(ios.target == "SIM-1")
        #expect(ios.ready)
        #expect(ios.runtime == "iOS 26.5")
        #expect(ios.transport == nil)
        #expect(harmony.platform == "harmony")
        #expect(harmony.id == "harmony:127.0.0.1:10100")
        #expect(harmony.target == "127.0.0.1:10100")
        #expect(harmony.ready)
        #expect(harmony.transport == "TCP")
    }

    @Test("host device selector prefers explicit matches and unique ready candidates")
    func hostDeviceSelectorPrefersExplicitMatchesAndUniqueReadyCandidates() {
        let first = HostDeviceTarget(
            platform: "ios",
            id: "sim:SIM-1",
            target: "SIM-1",
            state: "Booted",
            ready: true,
            source: "simctl",
            name: "iPhone 15",
            runtime: "iOS 26.5",
            transport: nil
        )
        let second = HostDeviceTarget(
            platform: "ios",
            id: "sim:SIM-2",
            target: "SIM-2",
            state: "Shutdown",
            ready: false,
            source: "simctl",
            name: "iPhone 14",
            runtime: "iOS 25.0",
            transport: nil
        )

        #expect(selectHostDeviceTarget(target: "SIM-2", candidates: [first, second]) == second)
        #expect(selectHostDeviceTarget(target: "booted", candidates: [first, second]) == first)
        #expect(selectHostDeviceTarget(target: nil, candidates: [first, second]) == first)
        #expect(selectHostDeviceTarget(target: nil, candidates: [second]) == second)
    }

    @Test("host device current selector falls back to stable target ids")
    func hostDeviceCurrentSelectorFallsBackToStableTargetIDs() {
        let selected = HostDeviceSelectionResult(
            platform: .ios,
            target: iosTarget(udid: "SIM-1"),
            selector: "ios",
            source: .platformFilter,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios))
        )

        #expect(hostDeviceCurrentSelector(explicitSelector: "iphone15", explicitTarget: nil, selected: selected) == "iphone15")
        #expect(hostDeviceCurrentSelector(explicitSelector: nil, explicitTarget: "sim:SIM-1", selected: selected) == "sim:SIM-1")
        #expect(hostDeviceCurrentSelector(explicitSelector: nil, explicitTarget: nil, selected: selected) == "sim:SIM-1")
    }

    @Test("host device selector can resolve a single ready target across platforms")
    func hostDeviceSelectorResolvesUniqueReadyTargetAcrossPlatforms() throws {
        let ios = iosTarget(udid: "SIM-1", state: "Booted", ready: true, name: "iPhone 15")
        let harmony = HostDeviceTarget(
            platform: "harmony",
            id: "harmony:127.0.0.1:10100",
            target: "127.0.0.1:10100",
            state: "Connected",
            ready: false,
            source: "hdc",
            name: nil,
            runtime: nil,
            transport: "TCP"
        )

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(),
            candidates: [.ios: [ios], .harmony: [harmony]],
            aliases: .empty
        )

        #expect(resolved.platform == .ios)
        #expect(resolved.target == ios)
        #expect(resolved.selector == "ready")
        #expect(resolved.source == .globalUnique)
    }

    @Test("host device screenshot rejects not-ready targets before invoking platform tools")
    func hostDeviceScreenshotRejectsNotReadyTargets() {
        let target = iosTarget(udid: "SIM-2", state: "Shutdown", ready: false)

        #expect(throws: HostCommandRunError.self) {
            _ = try captureHostDeviceScreenshot(
                platform: .ios,
                target: target,
                hdc: "hdc",
                output: "/tmp/should-not-be-written.png"
            )
        }
    }

    @Test("host device selector resolves aliases before raw platform ids")
    func hostDeviceSelectorResolvesAliasesBeforeRawPlatformIDs() throws {
        let store = HostTargetAliasStore(
            current: nil,
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "SIM-1")
            ]
        )
        let first = iosTarget(udid: "SIM-1", name: "iPhone 15")
        let second = iosTarget(udid: "SIM-2", name: "iPhone 16")

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(device: "iphone15"),
            candidates: [.ios: [first, second]],
            aliases: store
        )

        #expect(resolved.platform == .ios)
        #expect(resolved.target == first)
        #expect(resolved.selector == "iphone15")
        #expect(resolved.source == .alias)
    }

    @Test("host device selector auto-selects only unique ready platform target")
    func hostDeviceSelectorAutoSelectsOnlyUniqueReadyPlatformTarget() throws {
        let first = iosTarget(udid: "SIM-1", state: "Booted", ready: true)
        let second = iosTarget(udid: "SIM-2", state: "Shutdown", ready: false)

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(platform: .ios),
            candidates: [.ios: [first, second]],
            aliases: .empty
        )

        #expect(resolved.target == first)
        #expect(resolved.selector == "ios")
        #expect(resolved.source == .platformFilter)
    }

    @Test("host device selector rejects ambiguous platform candidates")
    func hostDeviceSelectorRejectsAmbiguousPlatformCandidates() throws {
        let first = iosTarget(udid: "SIM-1", state: "Booted", ready: true, name: "iPhone 15")
        let second = iosTarget(udid: "SIM-2", state: "Booted", ready: true, name: "iPhone 16")

        #expect(throws: HostDeviceSelectionError.self) {
            try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(platform: .ios),
                candidates: [.ios: [first, second]],
                aliases: .empty
            )
        }
    }

    @Test("host device selector filters by name runtime state and ready")
    func hostDeviceSelectorFiltersByNameRuntimeStateAndReady() throws {
        let first = iosTarget(udid: "SIM-1", state: "Booted", ready: true, name: "iPhone 15", runtime: "iOS 26.5")
        let second = iosTarget(udid: "SIM-2", state: "Booted", ready: true, name: "iPhone 16", runtime: "iOS 26.5")

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(platform: .ios, name: "15", runtime: "26.5", state: "booted", ready: true),
            candidates: [.ios: [first, second]],
            aliases: .empty
        )

        #expect(resolved.target == first)
        #expect(resolved.source == .platformFilter)
    }

    @Test("host target aliases persist current target and aliases")
    func hostTargetAliasesPersistCurrentTargetAndAliases() throws {
        let store = HostTargetAliasStore(
            current: "iphone15",
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "SIM-1"),
                "harmony-a": HostTargetAlias(platform: .harmony, target: "127.0.0.1:10100"),
            ]
        )

        let decoded = try JSONDecoder().decode(HostTargetAliasStore.self, from: JSONEncoder().encode(store))

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.current == "iphone15")
        #expect(decoded.aliases["iphone15"]?.platform == .ios)
        #expect(decoded.aliases["harmony-a"]?.target == "127.0.0.1:10100")
    }
}

private func iosTarget(
    udid: String,
    state: String = "Booted",
    ready: Bool = true,
    name: String = "iPhone",
    runtime: String = "iOS 26.5"
) -> HostDeviceTarget {
    HostDeviceTarget(
        platform: "ios",
        id: "sim:\(udid)",
        target: udid,
        state: state,
        ready: ready,
        source: "simctl",
        name: name,
        runtime: runtime,
        transport: nil
    )
}
