import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Readonly Simulator pair listing")
struct SimulatorPairsTests {
    @Test func onlyMetadataQuery() throws {
        var calls = 0
        let output = try makeSimulatorPairsOutput(provider: { calls += 1; return Data(#"{"pairs":{}}"#.utf8) })
        #expect(calls == 1 && output.pairs.isEmpty && !output.actionsExecuted)
        #expect(output.verification == "executed-simctl-json")
    }
    @Test func entryAndContract() throws {
        let command = try SimPairs.parse(["--json"])
        #expect(command.json)
        #expect(hostSimulatorPairsOutputContract().selector == "host.simulator-pairs")
    }
    @Test func failClosed() {
        #expect(throws: HostSimulatorPairsFailure.self) { _ = try makeSimulatorPairsOutput(provider: { Data(#"{}"#.utf8) }) }
    }
}
