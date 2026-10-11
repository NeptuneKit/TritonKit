import Testing
@testable import TritonKitCLI

@Suite("Device capability batches recursive schema")
struct DeviceCapabilityBatchSchemaTests {
    @Test func recursiveActionsHaveAccurateContracts() throws {
        let device = try #require(commandSchemas().first { $0.name == "device" })
        for (name, selector) in [("containers", "host.app-container-binding"), ("platforms", "host.apple-platform-report"), ("files", "host.device-files"), ("pair", "host.device-administration-execution"), ("unpair", "host.device-administration-execution"), ("diagnose", "host.device-administration-execution")] {
            let child = try #require(device.subcommands.first { $0.name == name })
            #expect(child.outputSelectors.contains(selector))
        }
        let sim = try #require(commandSchemas().first { $0.name == "sim" })
        #expect(try #require(sim.subcommands.first { $0.name == "pairs" }).outputSelectors.contains("host.simulator-pairs"))
    }
}
