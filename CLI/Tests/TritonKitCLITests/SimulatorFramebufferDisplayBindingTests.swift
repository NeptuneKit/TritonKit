import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Framebuffer normal-topology binding")
struct SimulatorFramebufferDisplayBindingTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    let primary = "11111111-2222-3333-4444-555555555555"
    var arguments: [String] { iosSimulatorDisplayTopologyQueryCommand(target: target, json: "/fixture/fresh.json", log: "/fixture/fresh.log", environment: [:]).arguments }
    var lcd: [String: Any] {
        ["displayId": 1, "uniqueId": primary, "primary": true, "backlightState": "activeOn", "type": ["integrated": [:]], "nativeSize": [1206, 2622]]
    }
    var inactiveVirtual: [String: Any] {
        ["displayId": 4, "uniqueId": "22222222-2222-3333-4444-555555555555", "primary": false, "backlightState": "off", "type": ["virtual": [:]], "nativeSize": [7680, 4320]]
    }
    func document(_ displays: [[String: Any]]? = nil, mutate: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        var root: [String: Any] = [
            "info": ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": arguments],
            "result": ["displays": displays ?? [lcd, inactiveVirtual]],
        ]
        mutate(&root)
        return try JSONSerialization.data(withJSONObject: root)
    }
    func classify(_ data: Data) -> SimulatorFramebufferDisplayResolution {
        classifySimulatorFramebufferDisplayBinding(data: data, target: target, exitCode: 0, expectedArguments: arguments)
    }

    @Test func inactiveLargerVirtualDoesNotBlockOrBecomeThePrimary() throws {
        #expect(classify(try document()) == .binding(.init(displayUniqueID: UUID(uuidString: primary)!, nativePixelSize: .init(width: 1206, height: 2622))))
        #expect(classify(try document([inactiveVirtual, lcd])) == classify(try document()))
    }

    @Test func invalidOrContradictoryTopologyNeverProducesBinding() throws {
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": Array(arguments.dropLast())] },
            { $0["result"] = ["displays": [lcd, inactiveVirtual], "deviceIdentifier": "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE"] },
            { $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": arguments, "error": [:]] },
            { $0["result"] = ["displays": [lcd, lcd]] },
        ]
        for mutate in mutations {
            if case .binding = classify(try document(mutate: mutate)) { Issue.record("Invalid topology must not bind a native surface") }
        }
        for field in ["uniqueId", "primary", "backlightState", "type"] {
            var invalid = lcd; invalid.removeValue(forKey: field)
            if case .binding = classify(try document([invalid, inactiveVirtual])) { Issue.record("Incomplete primary accepted") }
        }
        var activeVirtual = inactiveVirtual; activeVirtual["backlightState"] = "activeOn"
        #expect(classify(try document([lcd, activeVirtual])) == .unknown(.multipleActive))
    }

    @Test func geometryIsVerificationMetadataAndCannotChooseTheDisplay() throws {
        for invalidSize: Any in [[], [true, 2622], [1206.5, 2622], [0, 2622], [1206, 2622, 1]] {
            var primaryDisplay = lcd; primaryDisplay["nativeSize"] = invalidSize
            #expect(classify(try document([primaryDisplay, inactiveVirtual])) == .binding(.init(displayUniqueID: UUID(uuidString: primary)!, nativePixelSize: nil)))
        }
    }
}
