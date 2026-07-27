import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("SP-140 server target selection")
struct ServerTargetSelectionTests {
    @Test("canonical iOS Simulator app target never falls back to a same-UDID bundle")
    func canonicalAppTargetRequiresExactServerID() throws {
        let udid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
        let requested = TKIOSSimulatorRuntimeTargetID(
            simulatorUDID: udid,
            bundleIdentifier: "com.example.expected"
        )
        let wrongBundle = TKTargetSummary(
            id: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: udid,
                bundleIdentifier: "com.example.wrong"
            ),
            transport: "ios-simulator",
            connected: true,
            latestHierarchyAvailable: true,
            bundleIdentifier: "com.example.wrong",
            simulatorUDID: udid,
            platform: "ios"
        )

        #expect(matchingServerTargetSummaries(requested: requested, in: [wrongBundle]).isEmpty)
        #expect(throws: TKTargetResolutionError.notFound(requested)) {
            _ = try resolveServerTargetSummary(requested: requested, in: [wrongBundle])
        }
    }

    @Test("bare iOS Simulator selector retains legacy UDID fallback")
    func bareSimulatorSelectorRetainsFallback() throws {
        let udid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
        let connection = TKTargetSummary(
            id: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: udid,
                bundleIdentifier: "com.example.connected"
            ),
            transport: "ios-simulator",
            connected: true,
            latestHierarchyAvailable: true,
            bundleIdentifier: "com.example.connected",
            simulatorUDID: udid,
            platform: "ios"
        )
        let bare = TKIOSSimulatorRuntimeTargetID(simulatorUDID: udid)

        #expect(try resolveServerTargetSummary(requested: bare, in: [connection]) == connection)
    }
}
