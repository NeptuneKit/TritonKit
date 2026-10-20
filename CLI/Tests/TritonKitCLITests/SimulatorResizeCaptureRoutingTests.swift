import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct SimulatorResizeCaptureRoutingTests {
    @Test func resizedScreenshotSelectsBoundDisplay() throws {
        let udid = UUID().uuidString; let display = UUID().uuidString
        let displayProbe: IOSSimulatorDisplayProbe = { _, _ in .primary(IOSSimulatorDisplay(id: "main", primary: true, active: true, integrated: true)) }
        let command = TKSimctlCommand.screenshot(udid: udid, output: "/tmp/result.png")
        let routed = try resizeAwareSimulatorScreenshotCommand(command, simulator: udid, probe: { target, _ in
            #expect(target == udid)
            return .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 640, height: 480))
        }, displayProbe: displayProbe)
        #expect(routed.arguments.contains("--display=\(display)"))
        #expect(routed.arguments.last == "/tmp/result.png")
        #expect(routed.sensitiveOutput == command.sensitiveOutput)
        #expect(routed.requiredConfig == command.requiredConfig)
    }
    @Test func inactiveKeepsScreenshotAndUnknownRejects() throws {
        let udid = UUID().uuidString
        let displayProbe: IOSSimulatorDisplayProbe = { _, _ in .primary(IOSSimulatorDisplay(id: "main", primary: true, active: true, integrated: true)) }
        let command = TKSimctlCommand.screenshot(udid: udid, output: "/tmp/result.png")
        #expect(try resizeAwareSimulatorScreenshotCommand(command, simulator: udid, probe: { _, _ in .inactive }, displayProbe: displayProbe) == command)
        #expect(throws: IOSSimulatorResizeCaptureError.self) {
            try resizeAwareSimulatorScreenshotCommand(command, simulator: udid, probe: { _, _ in .unknown(.queryTimedOut) }, displayProbe: displayProbe)
        }
    }
    @Test func explicitDisplayMustMatchActiveResizeSession() throws {
        let udid = UUID().uuidString; let display = UUID().uuidString
        let displayProbe: IOSSimulatorDisplayProbe = { _, _ in .primary(IOSSimulatorDisplay(id: "main", primary: true, active: true, integrated: true)) }
        let probe: IOSSimulatorResizeProbe = { _, _ in .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 640, height: 480)) }
        let matching = TKSimctlCommand.screenshot(udid: udid, output: "/tmp/result.png", display: display)
        #expect(try resizeAwareSimulatorScreenshotCommand(matching, simulator: udid, probe: probe, displayProbe: displayProbe) == matching)
        let other = TKSimctlCommand.screenshot(udid: udid, output: "/tmp/result.png", display: "0")
        #expect(throws: IOSSimulatorResizeCaptureError.self) { try resizeAwareSimulatorScreenshotCommand(other, simulator: udid, probe: probe, displayProbe: displayProbe) }
    }
}
