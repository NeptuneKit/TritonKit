import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct HighlightCapabilityRoutingTests {
    @Test func ConnectionAloneDoesNotClaimWritableProvider() {
        let entries = runtimeCapabilities(host: "127.0.0.1", port: 19421, serverReachable: true, connected: true)
        let entry = entries.first { $0.name == "highlight" }
        #expect(entry?.supported == false)
        #expect(entry?.nextAction?.command == "highlight")
        #expect(entry?.nextAction?.args == ["capabilities", "--target", "<target>", "--json"])
        #expect(entry?.group == "runtime")
        #expect(entry?.evidence == ["stdout-json", "command-schema"])
        #expect(entry?.reason?.contains("highlight capabilities") == true)
        #expect(entries.first { $0.name == "screenshot" }?.supported == true)
    }

    @Test func OptionalHighlightDoesNotTakeOverDefaultReadinessRecovery() {
        for (serverReachable, connected) in [(false, false), (true, false), (true, true)] {
            let entries = runtimeCapabilities(host: "127.0.0.1", port: 19421, serverReachable: serverReachable, connected: connected)
            let response = TKCapabilitiesResponse(ok: true, serverReachable: serverReachable, connected: connected, latestHierarchyAvailable: connected, targetCount: connected ? 1 : 0, runtime: connected ? "embedded" : "none", capabilities: entries)
            #expect(response.primaryCapability == (connected ? "ios-real-device-screenshot" : "runtime-manifest"))
            #expect(response.primaryNextAction?.command == (connected ? "schema" : (serverReachable ? "status" : "serve")))
            #expect(response.capabilities.first { $0.name == "highlight" }?.nextAction?.command == "highlight")
        }
    }

    @Test func HighlightRecoveryUsesObservationAndPlanningWithoutAutomaticMutation() {
        #expect(TKCommandRecoveryCommand.category(forRootCommand: "highlight") == "diagnose")
        #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "highlight_busy") == ["diagnose", "plan"])
        #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "highlight_identity_unverifiable") == ["diagnose", "observe", "plan"])
        #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "highlight_restore_conflict") == ["diagnose", "observe"])
        #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "highlight_unsupported") == ["diagnose", "plan"])
    }
}
