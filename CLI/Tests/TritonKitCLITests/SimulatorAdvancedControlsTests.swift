import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SimulatorAdvancedControlsTests {
    @Test("host command forwards stdin into child process")
    func runHostCommandForwardsStdin() throws {
        let command = TKHostCommand(executable: "/bin/cat", arguments: [], stdinData: Data("hello\n".utf8))

        let result = try runHostCommand(command)

        #expect(result.exitCode == 0)
        #expect(result.stdout == "hello\n")
        #expect(result.sourceCommand == "/bin/cat")
    }

    @Test("sim schema exposes advanced simulator maintenance commands")
    func simSchemaExposesAdvancedCommands() throws {
        let sim = try #require(commandSchemas().first { $0.name == "sim" })
        let optionNames = sim.options.map(\.name)

        #expect(optionNames.contains(where: { $0.hasPrefix("status-bar") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("privacy") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("location") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("ui ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("pasteboard") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("push ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("record") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("logs") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("diagnose") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("logverbose") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("runtime ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("pair ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("unpair ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("clone ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("erase ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("upgrade ") }))
        #expect(optionNames.contains(where: { $0.hasPrefix("personalization ") }))
        #expect(sim.providedCapabilities.contains("host-simulator"))
        #expect(sim.providedCapabilities.contains("sim-video"))
        #expect(sim.providedCapabilities.contains("sim-logs"))
        #expect(sim.providedCapabilities.contains("sim-diagnostics"))
        #expect(sim.providedCapabilities.contains("sim-runtime"))
        #expect(sim.providedCapabilities.contains("sim-device-maintenance"))
        #expect(sim.providedCapabilities.contains("sim-runtime-maintenance"))
        #expect(sim.providedCapabilities.contains("sim-personalization"))
        #expect(sim.providedCapabilities.contains("sim-push"))
    }

    @Test("schema exposes xctrace and coverage artifact commands")
    func schemaExposesXctraceAndCoverageCommands() throws {
        let xctrace = try #require(commandSchemas().first { $0.name == "xctrace" })
        let coverage = try #require(commandSchemas().first { $0.name == "coverage" })

        #expect(xctrace.options.map(\.name).contains(where: { $0.hasPrefix("record") }))
        #expect(xctrace.providedCapabilities.contains("xctrace-record"))
        #expect(coverage.options.map(\.name).contains(where: { $0.hasPrefix("report") }))
        #expect(coverage.providedCapabilities.contains("coverage-report"))
    }
}
