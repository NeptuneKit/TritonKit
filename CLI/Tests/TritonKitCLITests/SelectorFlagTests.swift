import ArgumentParser
import Testing
@testable import TritonKitCLI

@Suite
struct SelectorFlagTests {
    @Test("find accepts device as target selector alias")
    func findAcceptsDeviceAlias() throws {
        let command = try Find.parse(["Needle", "--device", "booted"])

        #expect(command.query == "Needle")
        #expect(command.target == "booted")
    }

    @Test("tap accepts device as target selector alias")
    func tapAcceptsDeviceAlias() throws {
        let command = try Tap.parse(["Needle", "--device", "booted"])

        #expect(command.query == "Needle")
        #expect(command.target == "booted")
    }

    @Test("wait and assert accept device as target selector alias")
    func waitAndAssertAcceptDeviceAlias() throws {
        let wait = try Wait.parse(["--text", "Ready", "--device", "booted"])
        let assertion = try UIAssert.parse(["text-exists", "Ready", "--device", "booted"])

        #expect(wait.target == "booted")
        #expect(assertion.target == "booted")
    }

    @Test("find and tap schemas expose target device selector vocabulary")
    func actionSchemasExposeDeviceAlias() throws {
        let schemas = Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
        let act = try #require(schemas["act"])

        #expect(act.options.contains(where: { $0.name == "--target/--device" }))
        #expect(act.subcommands.map(\.name).contains("find"))
        #expect(act.subcommands.map(\.name).contains("tap"))
    }
}
