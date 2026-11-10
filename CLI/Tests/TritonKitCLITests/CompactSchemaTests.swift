import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct CompactSchemaTests {
    @Test func resolvedLeafKeepsArgumentsAliasesConstraintsAndSafety() throws {
        let response = try buildCompactSchemaResponse(command: "act.type")
        #expect(response.command == "act.type")
        #expect(response.requiredOptions.isEmpty)
        #expect(response.oneOfRequiredOptions == [["<text>", "--text"]])
        #expect(response.options.contains { $0.name == "--target/--device" })
        #expect(response.argumentForms.contains { $0.name == "<text>" })
        #expect(response.requiresServer && response.requiresTarget)
        #expect(response.sideEffect == "text-input")
        let root = try #require(commandSchemas().first { $0.name == "act" })
        #expect(response.outputSemantics == root.outputSemantics)
        #expect(Set(response.outputContracts.map(\.selector)) == Set(["input.result", "host.android-text-input", "host.harmony-text-input", "webview.form-input"]))
        #expect(!response.options.contains { $0.name == "--start-x" })
    }

    @Test func canonicalFingerprintAndPayloadBudget() throws {
        let dotted = try buildCompactSchemaResponse(command: "test.run")
        let spaced = try buildCompactSchemaResponse(command: " test   run ")
        #expect(dotted.fingerprint == spaced.fingerprint)
        #expect(dotted.fingerprint.count == 64)
        #expect(dotted.projectionVersion == 1)
        #expect(dotted.cliVersion == TritonKitBuildInfo.cliVersion)
        #expect(dotted.sideEffect == "runtime-execution-evidence-write")
        #expect(dotted.requiredOptions.contains("--evidence-dir"))
        #expect(dotted.argumentForms.contains { $0.name == "<path.tritontest.yaml>" })
        let full = try encodeJSON(buildSchemaResponse(command: "test.run"))
        let compact = try encodeJSON(dotted)
        #expect(compact.utf8.count * 2 < full.utf8.count)
    }

    @Test func parserAcceptsOptInAndLegacyRemainsFull() throws {
        let parsed = try TritonKitCLI.parseAsRoot(["schema", "--command", "act.type", "--compact", "--json"])
        #expect((parsed as? Schema)?.compact == true)
        let legacy = try buildSchemaResponse(command: "act.type")
        #expect(legacy.commands.first?.options.contains { $0.name == "--start-x" } == true)
    }

    @Test func invalidAndIncompleteSchemasFailClosed() throws {
        #expect(throws: CompactSchemaError.self) { try buildCompactSchemaResponse(command: nil) }
        #expect(throws: CompactSchemaError.self) { try buildCompactSchemaResponse(command: "act") }
        #expect(throws: SchemaCommandLookupError.self) { try buildCompactSchemaResponse(command: "act.nonexistent") }
        let child = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", requiredOptions: ["--missing"], outputSelectors: ["result"])
        #expect(throws: CompactSchemaError.self) { try buildCompactSchemaResponse(command: "fixture.leaf", commands: [fixture(child: child)]) }
        let selector = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", outputSelectors: ["missing"])
        #expect(throws: CompactSchemaError.self) { try buildCompactSchemaResponse(command: "fixture.leaf", commands: [fixture(child: selector)]) }
    }

    @Test func nestedOverridesAndSafetyAreInheritedConservatively() throws {
        let leaf = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", optionOverrides: [.init(name: "--count", type: "Int", defaultValue: "3", description: "leaf")], optionalOptions: ["--count"], outputSelectors: ["result"])
        let group = TKCommandSubcommandSchema(name: "group", summary: "fixture", requiresConfirmation: true, sideEffect: "write", optionOverrides: [.init(name: "--count", type: "Int", defaultValue: "2", description: "group")], subcommands: [leaf])
        let response = try buildCompactSchemaResponse(command: "fixture.group.leaf", commands: [fixture(child: group)])
        #expect(response.options.first { $0.name == "--count" }?.defaultValue == "3")
        #expect(response.sideEffect == "write")
        #expect(response.requiresConfirmation)
        #expect(response.requiresServer)
    }

    @Test func noSideEffectDeclarationDoesNotBecomeReadOnly() throws {
        let child = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", optionalOptions: ["--count"], outputSelectors: ["result"])
        let response = try buildCompactSchemaResponse(command: "fixture.leaf", commands: [fixture(child: child)])
        #expect(response.sideEffect == "unknown")
        #expect(response.outputSemantics?.contains("never be automatically replayed") == true)
    }

    @Test func fingerprintChangesWithEffectiveMetadata() throws {
        let child = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", optionalOptions: ["--count"], outputSelectors: ["result"])
        let changed = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", optionOverrides: [.init(name: "--count", type: "Int", defaultValue: "9", description: "changed")], optionalOptions: ["--count"], outputSelectors: ["result"])
        let first = try buildCompactSchemaResponse(command: "fixture.leaf", commands: [fixture(child: child)])
        let second = try buildCompactSchemaResponse(command: "fixture.leaf", commands: [fixture(child: changed)])
        #expect(first.fingerprint != second.fingerprint)
    }

    @Test func legacySelectorAlternativesAreNormalizedWithoutRequiringEverySingleton() throws {
        for (command, expected) in [
            ("app.launch", ["--bundle-id", "--package-name", "--bundle"]),
            ("app.install", ["--app", "--apk", "--hap"]),
            ("device.runner.tap", ["--identifier", "--label"]),
            ("device.runner.type", ["--identifier", "--label"]),
            ("act.type", ["<text>", "--text"]),
        ] {
            let response = try buildCompactSchemaResponse(command: command)
            #expect(response.selectorConstraints.last?.exactlyOneOf == expected)
        }
    }

    @Test func ancestorCompleteSetsRemainIndependentAndOverridesCoverArgumentsAndAliases() throws {
        let leaf = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", optionOverrides: [
            .init(name: "--count", type: "Int", required: true, defaultValue: "3", description: "required leaf"),
            .init(name: "<value>", type: "String", required: true, description: "required positional override"),
        ], oneOfRequiredOptionSets: [["--c"], ["--d"]], optionalOptions: ["--n", "<value>"], outputSelectors: ["result"])
        let group = TKCommandSubcommandSchema(name: "group", summary: "fixture", oneOfRequiredOptionSets: [["--a"], ["--b"]], subcommands: [leaf])
        let root = TKCommandSchema(name: "fixture", summary: "fixture", requiresServer: false, requiresTarget: false, outputFormats: ["json"], options: [
            .init(name: "--count/--n", type: "Int", defaultValue: "1", description: "count"),
        ] + ["--a", "--b", "--c", "--d"].map { .init(name: $0, type: "String", description: $0) }, argumentForms: [.init(name: "<value>", type: "String", description: "value")], examples: [], outputContracts: [.init(selector: "result", format: "json", kind: "object", fields: [])], subcommands: [group])
        let response = try buildCompactSchemaResponse(command: "fixture.group.leaf", commands: [root])
        #expect(response.selectorConstraints.count == 2)
        #expect(response.selectorConstraints[0].exactlyOneOptionSet == [["--a"], ["--b"]])
        #expect(response.selectorConstraints[1].exactlyOneOptionSet == [["--c"], ["--d"]])
        #expect(response.options.first { $0.name == "--n" }?.required == true)
        #expect(response.options.first { $0.name == "--n" }?.defaultValue == "3")
        #expect(!response.options.contains { $0.name.contains("--count") })
        #expect(response.argumentForms.first?.required == true)
        #expect(response.argumentForms.first?.description == "required positional override")
    }

    @Test func testRunVLMOptionsMatchParserWithoutExecutingModels() throws {
        let response = try buildCompactSchemaResponse(command: "test.run")
        #expect(response.options.contains { $0.name == "--vlm-model-path" })
        #expect(response.options.first { $0.name == "--vlm-allow-model-download" }?.defaultValue == "false")
        let parsed = try TritonKitCLI.parseAsRoot(["test", "run", "fixture.tritontest.yaml", "--evidence-dir", "fixture.tritonevidence", "--vlm-model-path", "fixture-model", "--vlm-allow-model-download", "--json"])
        let run = try #require(parsed as? TestRun)
        #expect(run.vlmModelPath == "fixture-model")
        #expect(run.vlmAllowModelDownload)
    }

    @Test func ambiguousLegacyConstraintsFailClosed() throws {
        let child = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", oneOfRequiredOptions: [["--count", "--other"], ["--third"]], outputSelectors: ["result"])
        #expect(throws: CompactSchemaError.self) { try buildCompactSchemaResponse(command: "fixture.leaf", commands: [fixture(child: child)]) }
    }

    @Test func requiredOverrideIsAReferenceWithoutRedundantLists() throws {
        let child = TKCommandSubcommandSchema(name: "leaf", summary: "fixture", optionOverrides: [.init(name: "--count", type: "Int", required: true, description: "required")], outputSelectors: ["result"])
        let response = try buildCompactSchemaResponse(command: "fixture.leaf", commands: [fixture(child: child)])
        #expect(response.requiredOptions == ["--count"])
        #expect(response.options.first?.name == "--count")
        #expect(response.options.first?.required == true)
        #expect(response.optionalOptions.isEmpty)
    }

    @Test func compactConstraintTypeGrammarAcceptsOnlyWellFormedNestedArrays() {
        for type in ["[[String]]", "[[String]]?", "[String]", "[[[Int]]]"] {
            #expect(isMachineReadableSchemaType(type))
        }
        for type in ["[[String]", "[[]]", "[[String] garbage]", "[[String]]!", "[[String]:]"] {
            #expect(!isMachineReadableSchemaType(type))
        }
    }

    private func fixture(child: TKCommandSubcommandSchema) -> TKCommandSchema {
        TKCommandSchema(name: "fixture", summary: "fixture", requiresServer: true, requiresTarget: false, outputFormats: ["json"], options: [.init(name: "--count", type: "Int", defaultValue: "1", description: "root")], examples: [], outputSemantics: "An unknown response must never be automatically replayed.", outputContracts: [.init(selector: "result", format: "json", kind: "object", fields: [])], subcommands: [child])
    }
}
