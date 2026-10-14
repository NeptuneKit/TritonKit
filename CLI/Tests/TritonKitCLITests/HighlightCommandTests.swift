import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Optional independent highlight CLI")
struct HighlightCommandTests {
    private let spec = #"{"items":[{"markID":"primary","selector":{"oid":42}}]}"#

    @Test("root command selects the independent capability and action subcommands")
    func rootArguments() throws {
        #expect(try Highlight.parseAsRoot(["apply", "--spec", spec, "--json"]) is HighlightApply)
        #expect(try Highlight.parseAsRoot(["status", "--session", "s-a", "--json"]) is HighlightStatus)
        #expect(try Highlight.parseAsRoot(["clear", "--session", "s-a", "--mark", "a", "--json"]) is HighlightClear)
        #expect(try Highlight.parseAsRoot(["capabilities", "--json"]) is HighlightCapabilities)
    }

    @Test("apply argv preserves explicit operation and bounded lifetime")
    func applyArguments() throws {
        let command = try HighlightApply.parse(["--target", "app-a", "--spec", spec, "--ttl", "17", "--operation-id", "op-a", "--json"])
        #expect(command.options.target == "app-a")
        #expect(command.options.json)
        let request = try command.makeRequest()
        #expect(request.operationID == "op-a")
        #expect(request.ttlSeconds == 17)
        #expect(request.spec.items.first?.selector.oid == 42)
    }

    @Test("invalid ttl and malformed spec fail before transport")
    func invalidApplyInput() throws {
        let command = try HighlightApply.parse(["--spec", spec, "--ttl", "301"])
        #expect(throws: TKHighlightError.self) { try command.makeRequest() }
        #expect(throws: TKHighlightError.self) { try decodeHighlightSpec("{bad") }
        #expect(throws: TKHighlightError.self) { try decodeHighlightSpec(#"{"items":[],"unexpected":true}"#) }
    }

    @Test("status requires exactly one session or operation")
    func statusIdentity() throws {
        let command = try HighlightStatus.parse(["--session", "s-a", "--operation", "op-a"])
        #expect(throws: TKHighlightError.self) { try command.makeRequest() }
        #expect(throws: TKHighlightError.self) { try HighlightStatus.parse([]).makeRequest() }
        #expect(try HighlightStatus.parse(["--operation", "op-a"]).makeRequest().operationID == "op-a")
    }

    @Test("clear carries only explicitly requested mark subset")
    func clearSubset() throws {
        let command = try HighlightClear.parse(["--session", "s-a", "--mark", "a", "--mark", "b", "--json"])
        #expect(try command.makeRequest().markIDs == ["a", "b"])
        #expect(try HighlightClear.parse(["--session", "s-a"]).makeRequest().markIDs.isEmpty)
    }

    @Test("unsupported provider does not issue an apply or installation request")
    func unsupportedIsZeroWrite() async throws {
        let calls = HighlightRequestRecorder()
        let capability = TKHighlightCapabilitiesResponse(runtimeInstanceID: "r-a", capability: TKHighlightCapability(supported: false, reason: "no_writable_provider"))
        let data = try JSONEncoder().encode(capability)
        let request = try HighlightApply.parse(["--spec", spec]).makeRequest()
        do {
            _ = try await executeHighlightApply(request) { type, _ in
                await calls.append(type)
                if type == "runtimeManifest" { return try highlightSupportedManifestData() }
                return data
            }
            Issue.record("Expected unsupported provider")
        } catch let error as TKHighlightError {
            #expect(error.code == "highlight_unsupported")
        }
        #expect(await calls.values == ["runtimeManifest", "highlightCapabilities"])
    }

    @Test("legacy unsupported envelope maps to highlight unsupported without rewrapping")
    func legacyProvider() async throws {
        let data = Data(#"{"ok":false,"error":{"code":"unsupported_capability","message":"Unknown request type"}}"#.utf8)
        let request = try HighlightApply.parse(["--spec", spec]).makeRequest()
        do {
            _ = try await executeHighlightApply(request) { type, _ in
                if type == "runtimeManifest" { return try highlightSupportedManifestData() }
                return data
            }
            Issue.record("Expected unsupported provider")
        } catch let error as TKHighlightError {
            #expect(error.code == "highlight_unsupported")
        }
    }

    @Test("connection failure is not described as unsupported")
    func transportFailure() async throws {
        let request = try HighlightApply.parse(["--spec", spec]).makeRequest()
        await #expect(throws: URLError.self) {
            try await executeHighlightApply(request) { _, _ in throw URLError(.cannotConnectToHost) }
        }
    }

    @Test("legacy manifest missing highlight stops before new wire types")
    func missingManifestCapability() async throws {
        let calls = HighlightRequestRecorder()
        let manifest = try JSONEncoder().encode(TKRuntimeManifestResponse.debugDefault(sdkVersion: "legacy", capabilities: []))
        do {
            _ = try await executeHighlightApply(HighlightApply.parse(["--spec", spec]).makeRequest()) { type, _ in
                await calls.append(type)
                return manifest
            }
            Issue.record("Expected unsupported legacy runtime")
        } catch let error as TKHighlightError { #expect(error.code == "highlight_unsupported") }
        #expect(await calls.values == ["runtimeManifest"])
    }

    @Test("optional capability absence is a successful observation")
    func unsupportedCapabilityObservation() async throws {
        let manifest = try JSONEncoder().encode(TKRuntimeManifestResponse.debugDefault(sdkVersion: "legacy", capabilities: []))
        let data = try await executeHighlightCapabilities(TKHighlightCapabilitiesRequest()) { _, _ in manifest }
        let response = try JSONDecoder().decode(TKHighlightCapabilitiesResponse.self, from: data)
        #expect(response.ok)
        #expect(!response.capability.supported)
    }

    @Test("schema supports complete root argv for every independent highlight operation")
    func completeSchemaArguments() {
        let schemas = Dictionary(uniqueKeysWithValues: highlightCommandSchemas().map { ($0.name, $0) })
        var issues = SchemaBackedCommandIssues()
        for argv in [
            ["triton", "highlight", "apply", "--target", "app-a", "--spec", "highlights.json", "--ttl", "30", "--operation-id", "op-a", "--json"],
            ["triton", "highlight", "status", "--operation", "op-a", "--runtime-instance-id", "r-a", "--json"],
            ["triton", "highlight", "clear", "--session", "s-a", "--mark", "a", "--mark", "b", "--json"],
            ["triton", "highlight", "capabilities", "--host", "127.0.0.1", "--port", "19421", "--json"],
        ] { validateSchemaBackedArgv(argv, context: "highlight", schemas: schemas, issues: &issues) }
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("schema makes optional capability and recovery limitations explicit")
    func schema() throws {
        let commands = highlightCommandSchemas()
        let root = try #require(commands.first { $0.name == "highlight" })
        let apply = try #require(root.subcommands.first { $0.name == "apply" })
        let clear = try #require(root.subcommands.first { $0.name == "clear" })
        #expect(apply.requiredOptions.contains("--spec"))
        #expect(apply.failureCodes.contains("highlight_unsupported"))
        #expect(clear.failureCodes.contains("highlight_restore_conflict"))
        #expect(root.outputSemantics?.contains("optional") == true)
        #expect(root.outputSemantics?.contains("CLI exit") == true)
        #expect(root.outputSemantics?.contains("text/role") == true)
        #expect(root.outputSemantics?.contains("unsupported by this provider") == true)
    }
}

private actor HighlightRequestRecorder {
    var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

func highlightSupportedManifestData() throws -> Data {
    try JSONEncoder().encode(TKRuntimeManifestResponse.debugDefault(sdkVersion: "fixture", capabilities: [TKRuntimeCapabilityDetail(name: "highlight", supported: true, scope: "embedded", boundary: "app-process")]))
}
