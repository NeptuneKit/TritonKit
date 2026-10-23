import Foundation
import Testing
import TritonKit
import TritonKitShared
@testable import TritonKitCLI

@Suite struct SimulatorDisplaySafetyTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    var arguments: [String] { ["devicectl", "device", "info", "displays", "--device", target, "--json-output", "/private/display.json", "--log-output", "/private/display.log", "--timeout", "5", "--quiet"] }
    func display(_ id: Int = 1, primary: Bool = true, state: String = "activeOn", type: String = "integrated") -> [String: Any] {
        ["displayId": id, "uniqueId": id == 1 ? "11111111-1111-1111-1111-111111111111" : "22222222-2222-2222-2222-222222222222", "primary": primary, "backlightState": state, "type": [type: [:] as [String: Any]]]
    }
    func fixture(_ displays: [[String: Any]], args: [String]? = nil, error: Bool = false) -> Data {
        var root: [String: Any] = ["info": ["commandType":"devicectl.device.info.displays", "outcome":"success", "arguments": args ?? arguments], "result":["displays": displays]]
        if error { root["error"] = ["code": 1] }
        return try! JSONSerialization.data(withJSONObject: root)
    }
    @Test func acceptsCapturedNativeShapeWithInactiveVirtualScreen() {
        let topology = classifyIOSSimulatorDisplayTopology(data: fixture([display(), display(4, primary: false, state: "off", type: "virtual")]), target: target, exitCode: 0, expectedArguments: arguments)
        #expect(topology == .primary(IOSSimulatorDisplay(id: "1", primary: true, active: true, integrated: true)))
    }
    @Test func rejectsUnsafeAndMalformedNativeShapes() {
        var invalid = [[String: Any]]()
        for key in ["displayId", "uniqueId", "primary", "backlightState", "type"] {
            var item = display(); item.removeValue(forKey: key); invalid.append(item)
        }
        var numericBool = display(); numericBool["primary"] = 1; invalid.append(numericBool)
        var fractionalID = display(); fractionalID["displayId"] = 1.5; invalid.append(fractionalID)
        var boolID = display(); boolID["displayId"] = true; invalid.append(boolID)
        var badUUID = display(); badUUID["uniqueId"] = "not-a-uuid"; invalid.append(badUUID)
        var ambiguous = display(); ambiguous["type"] = ["integrated": [:], "virtual": [:]]; invalid.append(ambiguous)
        invalid += [display(state: "unknown"), display(type: "external"), display(primary: false), display(state: "off"), display(type: "virtual")]
        invalid.append(["id": "main", "primary": true, "active": true, "integrated": true])
        for item in invalid {
            let actual = classifyIOSSimulatorDisplayTopology(data: fixture([item]), target: target, exitCode: 0, expectedArguments: arguments)
            guard case .unknown = actual else { Issue.record("Accepted malformed native display: \(item)"); continue }
        }
        var duplicateUnique = display(2, primary: false, state: "off"); duplicateUnique["uniqueId"] = display()["uniqueId"]
        for items in [[display(), duplicateUnique], [display(), display()], [display(), display(2, primary: false)], [display(), display(2, primary: true, state: "off")], [display(), display(2, primary: false, type: "virtual")]] {
            let actual = classifyIOSSimulatorDisplayTopology(data: fixture(items), target: target, exitCode: 0, expectedArguments: arguments)
            guard case .unknown = actual else { Issue.record("Accepted ambiguous display topology"); continue }
        }
    }
    @Test func rejectsUnboundArgumentsAndMixedFailure() {
        for args in [Array(arguments.prefix(6)), arguments + ["--device", target], arguments.map { $0 == target ? "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE" : $0 }, arguments.map { $0 == "/private/display.json" ? "/private/other.json" : $0 }] {
            #expect(classifyIOSSimulatorDisplayTopology(data: fixture([display()], args: args), target: target, exitCode: 0, expectedArguments: arguments) == .unknown(.invalidResponse))
        }
        #expect(classifyIOSSimulatorDisplayTopology(data: fixture([display()], error: true), target: target, exitCode: 0, expectedArguments: arguments) == .unknown(.invalidResponse))
        #expect(classifyIOSSimulatorDisplayTopology(data: fixture([display()]), target: target, exitCode: 1, expectedArguments: arguments) == .unknown(.invalidResponse))
        #expect(classifyIOSSimulatorDisplayTopology(data: fixture([display()]), target: target, exitCode: 0, expectedArguments: Array(arguments.prefix(6))) == .unknown(.identityMismatch))
    }
    @Test func bindsExactTargetAndGateHasZeroSideEffectsOnUnknown() {
        var submits = 0
        #expect(throws: IOSSimulatorDisplayError.self) { try assertIOSSimulatorMainDisplayAllowed(target: target, probe: { _, _ in .unknown(.identityMismatch) }) }
        #expect(submits == 0)
        try! assertIOSSimulatorMainDisplayAllowed(target: target, probe: { _, _ in .primary(IOSSimulatorDisplay(id: "main", primary: true, active: true, integrated: true)) })
        submits += 1
        #expect(submits == 1)
    }
    @Test func fakeToolProbeBindsCommandAndFailsClosedOnTimeout() {
        var seen: [String] = []
        let result = probeIOSSimulatorDisplay(target: target, artifactProvider: { _ in ("/tmp/no-display.json", "/tmp/no-display.log") }, runner: { command in seen = command.arguments; throw HostCommandRunError.timeout(command: command, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil) }, reader: { _, _ in Data() })
        #expect(seen.contains("displays"))
        #expect(seen.contains(target))
        #expect(result == IOSSimulatorDisplayTopology.unknown(.timedOut))
    }
}
