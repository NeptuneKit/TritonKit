import Testing
@testable import TritonKitCLI

@Suite("Device administration plan standalone entry")
struct DeviceAdministrationEntryTests {
    @Test(arguments: ["pair", "unpair", "diagnose"])
    func entry(_ operation: String) throws {
        var args = ["device", operation, "--platform", "ios", "--device", "ios-real:fixture", "--scope", "real", "--plan-only", "--json"]
        if operation == "diagnose" { args += ["--output", "private-archive.zip"] }
        let command = try TritonKitCLI.parseAsRoot(args)
        #expect(type(of: command).configuration.commandName == operation)
    }
    @Test("schema explicitly calls ok policy-plan not execution and includes independent operations")
    func schema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        for operation in ["pair", "unpair", "diagnose"] { #expect(schema.usageForms.contains { $0.form.hasPrefix(operation + " ") && $0.form.contains("--plan-only") }) }
        #expect(schema.outputContracts.contains { $0.selector == "host.device-administration-plan" && $0.fields.contains { $0.name == "executable" } && $0.fields.contains { $0.name == "plannedSourceCommand" } })
    }
}
