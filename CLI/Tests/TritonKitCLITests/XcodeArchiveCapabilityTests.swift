import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcodeArchiveCapabilityTests {
    @Test("archive and export stay discoverable without a runtime and provide executable next actions")
    func archiveAndExportCapabilities() throws {
        for fixture in capabilityStateFixtures() {
            for action in ["archive", "export"] {
                let capability = try #require(fixture.capabilities.first { $0.name == "xcode-" + action })
                #expect(capability.supported)
                #expect(capability.group == "xcode")
                #expect(capability.requiredBy == ["project", "xcode", "evidence"])
                #expect(capability.evidence == ["xcodebuild-json", "host-artifact"])
                let next = try #require(capability.nextAction)
                #expect(next.command == "xcode")
                #expect(next.args.first == action)
                _ = try TritonKitCLI.parseAsRoot([next.command] + next.args)
            }
        }
    }

    @Test("collection selection rejection recovery diagnoses app eligibility without bypassing it")
    func collectionSelectionRecovery() {
        for code in ["collection_cell_selection_blocked", "collection_cell_selection_denied"] {
            #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: code) == ["diagnose"])
            #expect(recoveryCategories(forFailureCode: code) == ["diagnose"])
        }
    }
}
