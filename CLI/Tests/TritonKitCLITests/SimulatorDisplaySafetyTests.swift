import Foundation
import Testing
@testable import TritonKitCLI

@Suite struct SimulatorDisplaySafetyTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    func fixture(_ displays: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["info": ["commandType":"devicectl.device.info.displayTopology", "outcome":"success", "arguments":["--device", target]], "result":["displays": displays]])
    }
    @Test func acceptsOneActivePrimaryIntegratedDisplay() {
        let topology = classifyIOSSimulatorDisplayTopology(data: fixture([["id":"main", "primary":true, "active":true, "integrated":true]]), target: target, exitCode: 0)
        #expect(topology == .primary(IOSSimulatorDisplay(id: "main", primary: true, active: true, integrated: true)))
    }
    @Test func rejectsSecondaryOnlyMultipleOrMalformedTopology() {
        #expect(classifyIOSSimulatorDisplayTopology(data: fixture([["id":"secondary", "primary":false, "active":true, "integrated":true]]), target: target, exitCode: 0) == .unknown(.missingField))
        #expect(classifyIOSSimulatorDisplayTopology(data: fixture([["id":"a", "primary":true, "active":true, "integrated":true], ["id":"b", "primary":false, "active":true, "integrated":true]]), target: target, exitCode: 0) == .unknown(.multipleActive))
        #expect(classifyIOSSimulatorDisplayTopology(data: fixture([["id":"a", "primary":1, "active":true, "integrated":true]]), target: target, exitCode: 0) == .unknown(.missingField))
        #expect(classifyIOSSimulatorDisplayTopology(data: fixture([["id":"a", "primary":true, "active":true, "integrated":true], ["id":"a", "primary":false, "active":false, "integrated":true]]), target: target, exitCode: 0) == .unknown(.duplicateID))
    }
    @Test func bindsExactTargetAndGateHasZeroSideEffectsOnUnknown() {
        var submits = 0
        #expect(throws: IOSSimulatorDisplayError.self) { try assertIOSSimulatorMainDisplayAllowed(target: target, probe: { _, _ in .unknown(.identityMismatch) }) }
        #expect(submits == 0)
        try! assertIOSSimulatorMainDisplayAllowed(target: target, probe: { _, _ in .primary(IOSSimulatorDisplay(id: "main", primary: true, active: true, integrated: true)) })
        submits += 1
        #expect(submits == 1)
    }
}
