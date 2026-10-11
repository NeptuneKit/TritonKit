import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Apple platform report entry")
struct ApplePlatformReportEntryTests {
    @Test func parser() throws {
        let command = try TritonKitCLI.parseAsRoot(["device", "platforms", "--apple-platform", "watchos", "--inventory", "--json"])
        #expect(type(of: command).configuration.commandName == "platforms")
    }
    @Test func physicalParser() throws {
        let command = try TritonKitCLI.parseAsRoot(["device", "platforms", "--include-real-devices", "--device", "PRIVATE-PRIMARY", "--json"])
        #expect(type(of: command).configuration.commandName == "platforms")
    }
    @Test func schema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form.hasPrefix("platforms ") && $0.form.contains("--inventory") })
        #expect(schema.outputContracts.contains { $0.selector == "host.apple-platform-report" && $0.fields.contains { $0.name == "inventoryObserved" } && $0.fields.contains { $0.name == "profiles" } })
    }
}
