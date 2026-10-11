import Foundation
import Testing
@testable import TritonKitShared

@Suite("Simulator relationship metadata")
struct TKSimulatorPairsTests {
    @Test func emptyAndExplicitRelationships() throws {
        #expect(try TKSimulatorPairsParser.parse(Data(#"{"pairs":{}}"#.utf8)).isEmpty)
        let json = #"{"pairs":{"11111111-1111-1111-1111-111111111111":{"watch":{"udid":"22222222-2222-2222-2222-222222222222","name":"PRIVATE"},"phone":{"udid":"33333333-3333-3333-3333-333333333333"},"state":"(active, disconnected)"}}}"#
        let pairs = try TKSimulatorPairsParser.parse(Data(json.utf8))
        #expect(pairs.count == 1 && pairs[0].watchID.hasPrefix("sim:"))
        #expect(pairs[0].state == "active-disconnected")
        #expect(!String(decoding: try JSONEncoder().encode(pairs), as: UTF8.self).contains("PRIVATE"))
        #expect(TKSimulatorPairsParser.command().arguments == ["simctl", "list", "pairs", "--json"])
    }
    @Test func malformedAndIdentityCollisionsFail() {
        for json in [#"{}"#, #"{"pairs":[]}"#, #"{"pairs":{"bad":{}}}"#, #"{"pairs":{"11111111-1111-1111-1111-111111111111":{"watch":{"udid":"22222222-2222-2222-2222-222222222222"},"phone":{"udid":"22222222-2222-2222-2222-222222222222"}}}}"#] {
            #expect(throws: TKSimulatorPairsError.self) { _ = try TKSimulatorPairsParser.parse(Data(json.utf8)) }
        }
    }
}
