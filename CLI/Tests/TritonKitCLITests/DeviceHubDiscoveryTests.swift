import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Device Hub official discovery")
struct DeviceHubDiscoveryTests {
    private func simulator(source: String = "simctl", ready: Bool = true) -> HostDeviceTarget {
        HostDeviceTarget(platform: "ios", id: "sim:SIM-UDID", target: "SIM-UDID", state: ready ? "Booted" : "Shutdown", ready: ready, source: source, name: "Fixture", runtime: "iOS 27.1", transport: nil, scope: "simulator", kind: "simulator")
    }
    private func physical() -> HostDeviceTarget {
        hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "CORE-PHYSICAL", state: "connected", ready: true, blockedReasons: []))
    }

    @Test("real scope excludes CoreDevice simulators and unknown kinds")
    func realScope() throws {
        let unknown = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "UNKNOWN", state: "unknown", ready: false, blockedReasons: ["readiness-unknown"], scope: "unknown", kind: "unknown"))
        let result = try iosHostDeviceTargets(scope: .real, simulatorProvider: { Issue.record("real discovery must not invoke simctl"); return ([], "unexpected") }, coreDeviceProvider: { ([simulator(source: "devicectl"), physical(), unknown], "devicectl list") })
        #expect(result.targets.map(\.scope) == ["real"])
    }

    @Test("all scope deduplicates simulators and preserves simctl lifecycle facts")
    func allScopeDeduplicates() throws {
        let result = try iosHostDeviceTargets(scope: .all, simulatorProvider: { ([simulator(ready: false)], "simctl list") }, coreDeviceProvider: { ([simulator(source: "devicectl"), physical()], "devicectl list") })
        #expect(result.targets.count == 2)
        #expect(result.targets.filter { $0.id == "sim:SIM-UDID" }.count == 1)
        #expect(result.targets.first?.source == "simctl")
        #expect(result.targets.first?.ready == false)
        #expect(result.sourceCommand == "simctl list\ndevicectl list")
    }

    @Test("known simulator selectors do not expand discovery to physical devices", arguments: ["sim:00000000-0000-0000-0000-000000000001", "triton:ios-simulator:00000000-0000-0000-0000-000000000001", "booted"])
    func simulatorSelectorScope(selector: String) throws {
        let scope = hostDeviceDiscoveryScope(for: HostDeviceSelectionRequest(device: selector, platform: .ios))
        #expect(scope == .simulator)
        let result = try iosHostDeviceTargets(scope: scope, simulatorProvider: { ([simulator()], "simctl list") }, coreDeviceProvider: { throw ProbeError.unavailable })
        #expect(result.targets.count == 1)
    }

    @Test("real selectors and explicit all retain their intended backend scope")
    func realAndExplicitScope() {
        #expect(hostDeviceDiscoveryScope(for: HostDeviceSelectionRequest(device: "ios-real:fixture", platform: .ios)) == .real)
        #expect(hostDeviceDiscoveryScope(for: HostDeviceSelectionRequest(device: "sim:fixture", platform: .ios, scope: .all)) == .all)
    }

    @Test("device schema publishes official discovery and unknown readiness semantics")
    func schemaContract() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form == "list --platform ios --scope all" })
        #expect(schema.outputSemantics?.contains("readiness-unknown") == true)
        #expect(schema.outputSemantics?.contains("Device Hub") == true)
    }

    private enum ProbeError: Error, Equatable { case unavailable }
    @Test("UUID case joins inventories while retaining private CoreDevice aliases")
    func canonicalUUIDAliases() throws {
        let lower = "12345678-abcd-1234-abcd-123456789abc"
        let canonical = try #require(UUID(uuidString: lower)?.uuidString)
        let sim = HostDeviceTarget(platform: "ios", id: "sim:\(canonical)", target: canonical, state: "Booted", ready: true, source: "simctl", name: "Fixture", runtime: "iOS 27.1", transport: nil, scope: "simulator", kind: "simulator")
        let core = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "PRIVATE-CORE-SIM", state: "connected", ready: true, blockedReasons: [], alternateIdentifiers: [lower], scope: "simulator", kind: "simulator", simulatorUDID: lower))
        let result = try iosHostDeviceTargets(scope: .all, simulatorProvider: { ([sim], "simctl") }, coreDeviceProvider: { ([core], "devicectl") })
        let merged = try #require(result.targets.first)
        #expect(result.targets.count == 1)
        #expect(merged.rawTargetAliases.contains("PRIVATE-CORE-SIM"))
        let selected = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: "PRIVATE-CORE-SIM", platform: .ios), candidates: [.ios: result.targets], aliases: .empty)
        #expect(selected.target.rawTarget == canonical)
        let encoded = String(decoding: try JSONEncoder().encode(merged), as: UTF8.self)
        #expect(!encoded.contains("PRIVATE-CORE-SIM"))
        #expect(!encoded.contains("rawTargetAliases"))
    }

    @Test("all scope does not silently report complete discovery after backend failure")
    func allScopeFailure() {
        #expect(throws: ProbeError.unavailable) {
            _ = try iosHostDeviceTargets(scope: .all, simulatorProvider: { ([simulator()], "simctl list") }, coreDeviceProvider: { throw ProbeError.unavailable })
        }
    }

    @Test("default simulator scope remains isolated from physical-device backend")
    func defaultScope() throws {
        let result = try iosHostDeviceTargets(scope: nil, simulatorProvider: { ([simulator()], "simctl list") }, coreDeviceProvider: { Issue.record("default discovery must not query physical devices"); return ([], "unexpected") })
        #expect(result.targets.count == 1)
        #expect(result.sourceCommand == "simctl list")
    }

    @Test("CoreDevice simulator maps back to simctl UDID, not CoreDevice identifier")
    func simulatorDispatchIdentity() throws {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "CORE-SIM", state: "connected", ready: true, blockedReasons: [], alternateIdentifiers: ["SIM-UDID"], scope: "simulator", kind: "simulator", simulatorUDID: "SIM-UDID"))
        #expect(target.target == "SIM-UDID")
        #expect(target.rawTarget == "SIM-UDID")
        let selected = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: "sim:SIM-UDID", platform: .ios, scope: .simulator, ready: true), candidates: [.ios: [target]], aliases: .empty)
        #expect(selected.target.target == "SIM-UDID")
        #expect(selected.target.scope == "simulator")
    }
}
