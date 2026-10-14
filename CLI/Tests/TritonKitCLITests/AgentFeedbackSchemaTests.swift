import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct AgentFeedbackSchemaTests {
    @Test func feedbackMechanismsAreDiscoverableThroughActualSchema() throws {
        let schemas = Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
        let observe = try #require(schemas["observe"])
        for name in ["ocr", "settle"] {
            let command = try #require(observe.subcommands.first { $0.name == name })
            #expect(command.outputSelectors == ["observe.\(name)"])
            #expect(observe.outputContracts.contains { $0.selector == "observe.\(name)" })
        }
        let health = try #require(schemas["debug"]?.subcommands.first { $0.name == "ui-health" })
        #expect(health.optionalOptions.contains("--timeout"))
        let workspace = try #require(schemas["workspace"])
        let run = try #require(workspace.outputContracts.first { $0.selector == "workspace.run" })
        #expect(run.fields.contains { $0.name == "visualFeedback" })
        for selector in ["input.result", "semantic.action", "act.webview-aware-tap"] {
            let contract = try #require(schemas["act"]?.outputContracts.first { $0.selector == selector })
            #expect(contract.fields.contains { $0.name == "outcome" })
            #expect(contract.fields.contains { $0.name == "uiHealth" })
        }
    }
}
