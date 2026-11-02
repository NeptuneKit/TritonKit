import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct SchemaEffectsTests {
    @Test func omittedEffectIsUnknownAndExplicitNoneRemainsDistinct() throws {
        #expect(TKCommandSubcommandSchema(name: "future", summary: "Undeclared effect").sideEffect == "unknown")
        let absent = try JSONDecoder().decode(TKCommandSubcommandSchema.self, from: Data(#"{"name":"future","summary":"Undeclared effect"}"#.utf8))
        #expect(absent.sideEffect == "unknown")
        let explicit = try JSONDecoder().decode(TKCommandSubcommandSchema.self, from: Data(#"{"name":"reserved","summary":"Always rejects","sideEffect":"none"}"#.utf8))
        #expect(explicit.sideEffect == "none")
    }

    @Test func operationFamiliesDeclarePotentialEffects() throws {
        let expected: [(String, String)] = [
            ("act.find", "readonly"), ("act.tap", "input-submission"), ("act.type", "text-input"),
            ("act.paste", "text-input"), ("act.clear", "text-input"), ("act.swipe", "input-submission"),
            ("act.press", "input-submission"), ("act.focus", "ui-mutation"), ("act.set-text", "text-input"),
            ("act.select-segment", "ui-mutation"), ("act.set-switch", "ui-mutation"), ("act.input", "input-submission"),
            ("app.list", "readonly"), ("app.info", "readonly"), ("app.inspect", "readonly"), ("app.container", "readonly"),
            ("app.install", "app-install"), ("app.uninstall", "app-uninstall"), ("app.launch", "app-launch"),
            ("app.terminate", "app-terminate"), ("app.go", "app-open-url"), ("app.open-url", "app-open-url"),
            ("app.pull", "artifact-write"), ("app.prefs", "preferences-write"),
            ("sim.list", "readonly"), ("sim.pairs", "readonly"), ("sim.ax", "readonly"),
            ("sim.use", "workspace-settings-write"), ("sim.create", "simulator-create"),
            ("sim.boot", "simulator-boot"), ("sim.shutdown", "simulator-shutdown"),
            ("sim.screenshot", "artifact-write"), ("sim.record", "artifact-write"), ("sim.logs", "artifact-write"),
            ("sim.app-console", "app-launch-and-artifact-write"), ("sim.erase", "simulator-data-delete"),
            ("sim.tap", "input-submission"), ("sim.swipe", "input-submission"), ("sim.type", "none"),
            ("build.ios", "build-execution-filesystem-write"), ("build.android", "build-execution-filesystem-write"),
            ("build.harmony", "build-execution-filesystem-write"),
        ]
        for (command, effect) in expected { #expect(try node(command).sideEffect == effect, "\(command)") }
        for root in commandSchemas().filter({ ["act", "app", "sim", "build"].contains($0.name) }) {
            for child in root.subcommands {
                #expect(child.sideEffect != "unknown", "Audited family must classify \(root.name).\(child.name)")
                #expect(child.sideEffect != "none" || (root.name == "sim" && child.name == "type"))
            }
        }
    }

    @Test func dryRunAndReadOnlyCasesAreStructuredAndScoped() throws {
        let runtime = try effectCases("sim.runtime")
        let dryRun = try #require(runtime.first { ($0["argumentPrefix"] as? [String]) == ["delete"] && ($0["optionValues"] as? [String: String])?["--dry-run"] == "true" })
        #expect(dryRun["sourceCommand"] as? String == "sim.runtime")
        #expect(dryRun["sideEffect"] as? String == "readonly")
        #expect(dryRun["requiresConfirmation"] as? Bool == false)
        let deletion = try #require(runtime.first { ($0["optionValues"] as? [String: String])?["--dry-run"] == "false" })
        #expect(deletion["sideEffect"] as? String == "runtime-delete")
        #expect(deletion["requiresConfirmation"] as? Bool == true)
        #expect(try effectCases("app.prefs").contains { ($0["argumentPrefix"] as? [String]) == ["get"] && ($0["sideEffect"] as? String) == "readonly" })
        #expect(try effectCases("sim.ui").contains { ($0["argumentPrefix"] as? [String]) == ["appearance"] && ($0["argumentCount"] as? Int) == 1 && ($0["sideEffect"] as? String) == "readonly" })
        #expect(try effectCases("sim.proxy").contains { ($0["optionValues"] as? [String: String])?["--plan-only"] == "true" && ($0["sideEffect"] as? String) == "readonly" })
    }

    @Test func conditionalMetadataSurvivesDecodeCopyAndCompactProjection() throws {
        let json = Data(#"{"name":"mode","summary":"Modes","sideEffect":"write","sideEffectCases":[{"sourceCommand":"fixture.mode","argumentPrefix":[],"optionValues":{"--dry-run":"true"},"sideEffect":"readonly","requiresConfirmation":false}]}"#.utf8)
        let decoded = try JSONDecoder().decode(TKCommandSubcommandSchema.self, from: json)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
        #expect((encoded?["sideEffectCases"] as? [[String: Any]])?.count == 1)
        let full = try effectCases("sim.runtime")
        let compact = try JSONSerialization.jsonObject(with: JSONEncoder().encode(buildCompactSchemaResponse(command: "sim.runtime"))) as? [String: Any]
        let projected = try #require(compact?["sideEffectCases"] as? [[String: Any]])
        #expect(NSDictionary(dictionary: ["cases": projected]).isEqual(to: ["cases": full]))
        #expect(try buildCompactSchemaResponse(command: "sim.type").sideEffect == "none")
    }

    @Test func buildsDoNotInventDryRunSupportAndSafetyIsNotRetryPermission() throws {
        for name in ["ios", "android", "harmony"] {
            let schema = try node("build.\(name)")
            #expect(!schema.optionalOptions.contains("--dry-run"))
            #expect(try effectCases("build.\(name)").isEmpty)
            #expect(throws: (any Error).self) { try TritonKitCLI.parseAsRoot(["build", name, "--project", "fixture", "--dry-run", "--json"]) }
        }
        #expect(try node("app.uninstall").requiresConfirmation)
        #expect(try node("sim.erase").requiresConfirmation)
        #expect(try node("act.tap").retryable == false)
        #expect(try node("act.type").retryable == false)
    }

    private func node(_ command: String) throws -> TKCommandSubcommandSchema {
        try #require(buildSchemaResponse(command: command).commands.first?.subcommands.first)
    }

    private func effectCases(_ command: String) throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(node(command))) as? [String: Any]
        return try #require(object?["sideEffectCases"] as? [[String: Any]])
    }
}
