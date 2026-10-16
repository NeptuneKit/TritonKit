import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("SP-201 floating selection CLI")
struct FloatingSelectionCommandTests {
    private let guardArgs = ["--selection", "mark-1", "--selection-revision", "7", "--runtime-instance-id", "runtime-1"]

    @Test("selection tap encodes only guarded embedded input")
    func guardedInput() throws {
        let command = try Tap.parse(guardArgs)
        let candidate = try command.makeSelectionInputRequest()
        let request = try #require(candidate)
        #expect(request.type == .tap)
        #expect(request.selection == TKSelectionGuard(runtimeInstanceID: "runtime-1", selectionID: "mark-1", revision: 7))
        #expect(request.targetOID == nil)
        #expect(request.x == nil && request.y == nil)
    }

    @Test("partial, empty and zero guards fail before runtime resolution")
    func invalidGuards() throws {
        let cases = [
            ["--selection", "mark-1"],
            ["--selection-revision", "1"],
            ["--runtime-instance-id", "runtime-1"],
            ["--selection", "", "--selection-revision", "1", "--runtime-instance-id", "runtime-1"],
            ["--selection", "mark-1", "--selection-revision", "0", "--runtime-instance-id", "runtime-1"],
            ["--selection", "mark-1", "--selection-revision", "1", "--runtime-instance-id", " "],
        ]
        for args in cases {
            let command = try Tap.parse(args)
            #expect(throws: TKSelectionError.self) { try command.makeSelectionInputRequest() }
        }
    }

    @Test("guard cannot mix with selectors, host, WebView or fallback options")
    func conflictingRoutes() throws {
        for extra in [["Save"], ["--text", "Save"], ["--oid", "1"], ["--ax-oid", "1"], ["--ax-label", "Save"], ["--x", "1", "--y", "2"], ["--at", "1,2"], ["--platform", "ios"], ["--webview-aware"], ["--selector", "#save"], ["--allow-host-hid-fallback"], ["--strategy", "ancestor"], ["--index", "1"], ["--width", "100"], ["--adb", "/custom/adb"], ["--hdc", "/custom/hdc"], ["--timeout", "5"]] {
            let command = try Tap.parse(guardArgs + extra)
            #expect(throws: TKSelectionError.self) { try command.makeSelectionInputRequest() }
        }
        #expect(try Tap.parse(["Save"]).makeSelectionInputRequest() == nil)
    }

    @Test("inspect keeps summary and registers three selection subcommands")
    func inspectParsing() throws {
        #expect(try TritonKitCLI.parseAsRoot(["inspect", "--json"]) is InspectSummary)
        #expect(try TritonKitCLI.parseAsRoot(["inspect", "selection", "--json"]) is InspectSelection)
        #expect(try TritonKitCLI.parseAsRoot(["inspect", "clear", "--json"]) is InspectSelectionClear)
        #expect(try TritonKitCLI.parseAsRoot(["inspect", "capabilities", "--json"]) is InspectSelectionCapabilities)
    }

    @Test("full root argv retains selection connection and identity options")
    func inspectConnectionOptions() throws {
        let arguments = ["--host", "localhost", "--port", "19422", "--target", "runtime-target", "--runtime-instance-id", "runtime-1", "--format", "text", "--json"]
        let parsedSelection = try TritonKitCLI.parseAsRoot(["inspect", "selection"] + arguments)
        let selection = try #require(parsedSelection as? InspectSelection)
        let parsedClear = try TritonKitCLI.parseAsRoot(["inspect", "clear"] + arguments)
        let clear = try #require(parsedClear as? InspectSelectionClear)
        let parsedCapabilities = try TritonKitCLI.parseAsRoot(["inspect", "capabilities"] + arguments)
        let capabilities = try #require(parsedCapabilities as? InspectSelectionCapabilities)
        for options in [selection.options, clear.options, capabilities.options] {
            #expect(options.host == "localhost")
            #expect(options.port == 19422)
            #expect(options.target == "runtime-target")
            #expect(options.runtimeInstanceID == "runtime-1")
            #expect(options.format == .text)
            #expect(options.json)
        }
        let parsedSummary = try TritonKitCLI.parseAsRoot(["inspect", "--host", "localhost", "--port", "19422", "--target", "runtime-target", "--json"])
        let summary = try #require(parsedSummary as? InspectSummary)
        #expect(summary.host == "localhost")
        #expect(summary.port == 19422)
        #expect(summary.target == "runtime-target")
        #expect(summary.json)
    }

    @Test("selection transport forwards exact type and runtime guard")
    func selectionTransport() async throws {
        for type in ["selectionStatus", "selectionClear", "selectionCapabilities"] {
            let response = try await executeSelectionRequest(type: type, request: TKSelectionRequest(runtimeInstanceID: "runtime-1")) { actualType, payload in
                #expect(actualType == type)
                #expect(try JSONDecoder().decode(TKSelectionRequest.self, from: payload).runtimeInstanceID == "runtime-1")
                return try JSONEncoder().encode(TKSelectionResponse(runtimeInstanceID: "runtime-1", revision: 8, state: "none"))
            }
            #expect(response.revision == 8)
            #expect(response.state == "none")
        }
    }


    @Test("invalid runtime guard sends no request; unsupported response retains typed error")
    func selectionFailureTransport() async throws {
        var sendCount = 0
        do {
            _ = try await executeSelectionRequest(type: "selectionClear", request: TKSelectionRequest(runtimeInstanceID: " ")) { _, _ in
                sendCount += 1
                return Data()
            }
            Issue.record("Expected validation failure")
        } catch let error as TKSelectionError {
            #expect(error.code == "validation_failed")
        }
        #expect(sendCount == 0)
        let failure = TKSelectionResponse(ok: false, runtimeInstanceID: "runtime-1", state: "unsupported", error: TKSelectionError(code: "selection_unsupported", message: "Picker is disabled"))
        let decoded = try await executeSelectionRequest(type: "selectionCapabilities", request: TKSelectionRequest()) { _, _ in
            try JSONEncoder().encode(failure)
        }
        #expect(decoded == failure)
    }

    @Test("schemas expose selection fields, guard options and input result")
    func schema() throws {
        let inspect = try #require(observationCommandSchemas().first { $0.name == "inspect" })
        #expect(Set(inspect.subcommands.map(\.name)) == Set(["selection", "clear", "capabilities"]))
        let contract = try #require(inspect.outputContracts.first { $0.selector == "inspect.selection" })
        #expect(contract.fields.contains { $0.name == "runtimeInstanceID" })
        #expect(contract.fields.contains { $0.name == "selection.revision" })
        #expect(inspect.usageForms.count == 3)
        for code in selectionFailureCodes where code != "validation_failed" {
            #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: code) == ["diagnose", "observe", "plan"])
            #expect(recoveryCategories(forFailureCode: code) == Set(["diagnose", "observe", "plan"]))
        }
        let input = try #require(inputActionSchemas().first { $0.type == "tap" })
        #expect(input.oneOfRequired.contains(["selection"]))
        #expect(input.fields.contains { $0.name == "selection" })
        for name in ["tap", "act"] {
            let schema = try #require(actionCommandSchemas().first { $0.name == name })
            for flag in ["--selection", "--selection-revision", "--runtime-instance-id"] {
                #expect(schema.options.contains { $0.name == flag })
            }
            #expect(schema.outputContracts.contains { $0.selector == "input.result" })
        }
    }
}
