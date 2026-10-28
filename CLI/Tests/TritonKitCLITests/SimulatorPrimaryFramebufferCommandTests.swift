import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct SimulatorPrimaryFramebufferCommandTests {
    @Test func explicitOptionIsAvailableOnlyOnSimScreenshot() throws {
        _ = try SimScreenshot.parse(["--output", "/tmp/primary.png", "--primary-framebuffer"])
        #expect(throws: (any Error).self) {
            let conflict = try SimScreenshot.parse(["--output", "/tmp/primary.png", "--primary-framebuffer", "--display", "internal"])
            try conflict.validateCaptureOptions()
        }
        #expect(throws: (any Error).self) {
            _ = try DeviceScreenshot.parse(["--platform", "ios", "--output", "/tmp/primary.png", "--primary-framebuffer"])
        }
        #expect(throws: (any Error).self) {
            _ = try SimRecord.parse(["--output", "/tmp/primary.mov", "--primary-framebuffer"])
        }
        _ = try SimScreenshot.parse(["--output", "/tmp/primary.png", "--display", "internal"])
    }
    @Test func schemaDescribesSeparateCaptureEvidence() throws {
        #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "ios_simulator_display_safety_unknown") == ["diagnose", "plan"])
        let sim = try #require(commandSchemas().first { $0.name == "sim" })
        let screenshot = try #require(sim.subcommands.first { $0.name == "screenshot" })
        #expect(screenshot.optionalOptions.contains("--primary-framebuffer"))
        let contract = try #require(sim.outputContracts.first { $0.selector == "host.simulator-screenshot" })
        let names = Set(contract.fields.map(\.name))
        for field in ["primaryFramebuffer", "primaryFramebuffer.captureScope", "primaryFramebuffer.displayUniqueID", "primaryFramebuffer.resizeState", "primaryFramebuffer.resizeReason", "primaryFramebuffer.resizeVerified", "primaryFramebuffer.inputDispatchVerified", "primaryFramebuffer.topologySource"] {
            #expect(names.contains(field))
        }
    }
}
