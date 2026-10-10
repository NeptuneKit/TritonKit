import ArgumentParser
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Standalone Simulator rename")
struct SimulatorRenameTests {
    @Test("rename is root-dispatchable without introducing Run or removing old commands")
    func rootDispatch() throws {
        #expect(Sim.configuration.subcommands.contains { $0.configuration.commandName == "rename" })
        let command = try TritonKitCLI.parseAsRoot(["sim", "rename", "00000000-0000-0000-0000-000000000001", "设备 名称; $(literal)", "--json"])
        #expect(type(of: command).configuration.commandName == "rename")
    }

    @Test("planner normalizes only the explicit UUID, preserving opaque Unicode name and command metadata")
    func planner() throws {
        let id = "01234567-89ab-cdef-0123-456789abcdef"
        let name = "  设备 名称; $(literal)  "
        let parsed = try #require(TritonKitCLI.parseAsRoot(["sim", "rename", id, name, "--timeout", "42", "--json"]) as? SimRename)
        #expect(parsed.udid == id && parsed.name == name && parsed.timeout == 42 && parsed.json)
        let command = try makeSimulatorRenameCommand(udid: parsed.udid, name: parsed.name, timeout: parsed.timeout)
        let legacy = TKSimctlCommand.rename(udid: id.uppercased(), name: name)
        #expect(command == legacy.withTimeout(42))
        #expect(try makeSimulatorRenameCommand(udid: id, name: name) == legacy)
    }

    @Test("ambiguous/physical selectors and blank/control names fail before backend", arguments: [
        ("booted", "name"), ("all", "name"), ("ios-real:fixture", "name"), ("sim:00000000-0000-0000-0000-000000000001", "name"),
        ("00000000-0000-0000-0000-000000000001", ""), ("00000000-0000-0000-0000-000000000001", "  "),
        ("00000000-0000-0000-0000-000000000001", "line\nname"), ("00000000-0000-0000-0000-000000000001", "nul\0name"),
    ])
    func rejectedInputs(input: (String, String)) {
        #expect(throws: (any Error).self) { _ = try makeSimulatorRenameCommand(udid: input.0, name: input.1) }
    }

    @Test("rename requires a positive finite explicit timeout", arguments: [0.0, -1.0, Double.infinity, Double.nan])
    func rejectedTimeout(timeout: Double) {
        #expect(throws: (any Error).self) { _ = try makeSimulatorRenameCommand(udid: "00000000-0000-0000-0000-000000000001", name: "name", timeout: timeout) }
    }

    @Test("rename schema advertises an explicit single UUID and optional phase timeout")
    func schemaContract() throws {
        let schema = try #require(commandSchemas().first { $0.name == "sim" })
        #expect(schema.usageForms.contains { $0.form.hasPrefix("rename <udid> <name>") })
        #expect(schema.failureCodes.contains("parameter_conflict"))
    }
}
