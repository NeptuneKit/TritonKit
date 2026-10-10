import ArgumentParser
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("DeviceFS fixed container namespace views")
struct DeviceFSNamespaceTests {
    @Test("container-relative subdirectory parser and machine scope contract")
    func subdirectoryEntry() throws {
        _ = try TritonKitCLI.parseAsRoot(["device", "fs", "list", "--view", "app-group-containers", "--container-identifier", "native.fixture", "--subdirectory", "Library/PrivateFixture", "--json"])
    }
    @Test("schema advertises fs list subdirectory separately from files and denies host paths")
    func subdirectorySchema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form.contains("--container-identifier") && $0.form.contains("--subdirectory") })
        #expect(schema.options.contains { $0.name == "--subdirectory" && $0.description.contains("fs list") })
    }
    @Test("explicit one native container component option and schema, no arbitrary paths")
    func containerEntry() throws {
        let command = try TritonKitCLI.parseAsRoot(["device", "fs", "list", "--view", "app-data-containers", "--container-identifier", "private.fixture", "--json"])
        #expect(type(of: command).configuration.commandName == "list")
    }
    @Test("machine contract advertises private container selection and directory scope token")
    func containerSchema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.options.contains { $0.name == "--container-identifier" })
        #expect(schema.usageForms.contains { $0.form.contains("--container-identifier") })
        let output = try #require(schema.outputContracts.first { $0.selector == "host.device-fs-list" })
        #expect(output.fields.contains { $0.name == "directoryToken" })
    }
    @Test("fixed namespace views dispatch without arbitrary paths")
    func dispatch() throws {
        for view in ["mount-root", "app-data-containers", "app-group-containers"] {
            let command = try TritonKitCLI.parseAsRoot(["device", "fs", "list", "--view", view, "--device", "fixture", "--json"])
            #expect(type(of: command).configuration.commandName == "list")
        }
        for view in ["temporary", "root/tmp", "DiagnosticReports", "../AppDataContainers"] {
            #expect(throws: (any Error).self) { _ = try TritonKitCLI.parseAsRoot(["device", "fs", "list", "--view", view, "--json"]) }
        }
    }
    @Test("schema makes namespace metadata independent of bundle/group/domain claims")
    func schema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form.contains("--view") && $0.form.contains("app-group-containers") })
        let output = try #require(schema.outputContracts.first { $0.selector == "host.device-fs-list" })
        let view = try #require(output.fields.first { $0.name == "view" })
        #expect(view.description.contains("app-data-containers") && view.description.contains("app-group-containers"))
    }
}
