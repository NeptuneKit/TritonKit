import Foundation
import Darwin
import ArgumentParser
import Testing
@testable import TritonKitCLI

@Suite(.serialized)
struct JSONParserFailureTests {
    @Test("real parser exclusivity and custom validation stay safe")
    func validationKinds() throws {
        do {
            _ = try ExclusiveFixture.parseAsRoot(["--first", "--second", "--json"])
            Issue.record("Exclusive parser fixture unexpectedly accepted both selectors")
        } catch {
            let value = try #require(parserFailureEnvelope(error: error, arguments: ["--first", "--second", "--json"], root: ExclusiveFixture.self))
            #expect(value.error.code == "conflicting_arguments")
            #expect(value.error.details.argumentNames == ["--first", "--second"])
        }
        do {
            _ = try ValidationFixture.parseAsRoot(["--json"])
            Issue.record("Validation fixture unexpectedly accepted invalid input")
        } catch {
            let value = try #require(parserFailureEnvelope(error: error, arguments: ["--json"], root: ValidationFixture.self))
            #expect(value.error.code == "argument_validation_failed")
            #expect(!String(decoding: try JSONEncoder().encode(value), as: UTF8.self).contains("secret-validation-251"))
        }
        #expect(parserRequestsJSON(["--format", "--json"]))
        #expect(!parserRequestsJSON(["--", "--format=json"]))
        #expect(!parserRequestsJSON(["--format=json", "--format", "text"]))
        #expect(parserRequestsJSON(["--format=text", "--json"]))
    }

    @Test("schema documents the global parser failure contract and fallback")
    func schemaContract() throws {
        let schema = try #require(try buildSchemaResponse(command: "schema").commands.first)
        #expect(schema.outputContracts.contains { $0.selector == "cli.parse.failure" })
        let contract = try #require(schema.outputContracts.first { $0.selector == "cli.parse.failure" })
        #expect(contract.fields.contains { $0.name == "error.hint" && $0.type == "String?" && !$0.required })
        #expect(schema.outputSemantics?.contains("exit 64") == true)
        #expect(schema.outputSemantics?.contains("text fallback") == true)
    }

    @Test("parser process executable stays beside the exact test bundle on macOS and Linux")
    func executableLocation() {
        for path in ["/fixture/debug/Tests.xctest", "/fixture/debug/Tests.xctest/Contents/MacOS/Tests"] {
            #expect(parserTestExecutable(bundledAt: URL(fileURLWithPath: path))?.path == "/fixture/debug/triton")
        }
        #expect(parserTestExecutable(bundledAt: URL(fileURLWithPath: "/fixture/unrelated-runner")) == nil)
    }

    @Test("missing required arguments produce a safe machine envelope")
    func missing() throws {
        let result = try invoke(["sim", "boot", "--json"])
        let json = try envelope(result, code: "missing_argument")
        #expect(json["commandPath"] as? [String] == ["triton", "sim", "boot"])
        let error = try #require(json["error"] as? [String: Any])
        let details = try #require(error["details"] as? [String: Any])
        #expect((details["argumentNames"] as? [String])?.contains("<udid>") == true)
        #expect(error["nextAction"] != nil)
    }

    @Test("issue unexpected arguments and unknown names never echo values")
    func unexpected() throws {
        let secret = "secret-marker-251"
        let extra = try invoke(["wait", "text", secret, "--platform", "harmony", "--target", secret, "--timeout", "0.01", "--json"])
        _ = try envelope(extra, code: "unexpected_argument")
        #expect(!extra.stdout.contains(secret))
        // Supply the required positional: otherwise the real parser reports the
        // missing UDID before the unknown option. Do not override that precedence.
        let unknown = try invoke(["sim", "boot", "fixture-udid", "--" + secret, "--json"])
        _ = try envelope(unknown, code: "unknown_option")
        #expect(!unknown.stdout.contains(secret))
    }

    @Test("invalid scalar and missing option value are classified without values")
    func scalar() throws {
        let invalid = try invoke(["status", "--port", "secret-port-251", "--json"])
        _ = try envelope(invalid, code: "invalid_argument_value")
        #expect(!invalid.stdout.contains("secret-port-251"))
        _ = try envelope(try invoke(["status", "--json", "--port"]), code: "missing_argument_value")
    }

    @Test("format aliases and malformed format fallback remain explicit")
    func formats() throws {
        for suffix in [["--format", "json"], ["--format=json"]] {
            _ = try envelope(try invoke(["sim", "boot"] + suffix), code: "missing_argument")
        }
        let invalid = try invoke(["status", "--format", "secret-format-251", "--json"])
        _ = try envelope(invalid, code: "invalid_argument_value")
        #expect(!invalid.stdout.contains("secret-format-251"))
        for args in [["status", "--format", "--json"], ["status", "--format=json", "--format", "--json"]] {
            _ = try envelope(try invoke(args), code: "missing_argument_value")
        }
        let fallback = try invoke(["status", "--format", "unsupported-format"])
        #expect(fallback.status == 64)
        #expect(fallback.stdout.isEmpty)
        #expect(!fallback.stderr.isEmpty)
        let literal = try invoke(["version", "--", "--json"])
        #expect(literal.status == 64)
        #expect(literal.stdout.isEmpty)
    }

    @Test("help and runtime errors are not recast as parser failures")
    func existingBehavior() throws {
        let help = try invoke(["sim", "boot", "--json", "--help"])
        #expect(help.status == 0)
        #expect(help.stdout.contains("USAGE:") || help.stdout.contains("用法"))
        let runtime = try invoke(["schema", "--command", "__audit_unknown_command__", "--json"])
        #expect(runtime.status == 1)
        let json = try #require(try JSONSerialization.jsonObject(with: Data(runtime.stdout.utf8)) as? [String: Any])
        #expect((json["error"] as? [String: Any])?["code"] as? String == "unknown_command_schema")
    }

    private func envelope(_ result: Result, code: String) throws -> [String: Any] {
        #expect(result.status == 64)
        #expect(result.stderr.isEmpty)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any])
        #expect(object["ok"] as? Bool == false)
        #expect(object["action"] as? String == "cli.parse")
        let error = try #require(object["error"] as? [String: Any])
        #expect(error["code"] as? String == code)
        #expect(error["retryable"] as? Bool == false)
        return object
    }

    private struct Result { let status: Int32; let stdout: String; let stderr: String }

    private func invoke(_ arguments: [String]) throws -> Result {
        // Bind executable to this exact SwiftPM test product; never pick a PATH release.
        let args = CommandLine.arguments
        let bundle: URL
        if let i = args.firstIndex(of: "--test-bundle-path"), args.indices.contains(i + 1) {
            bundle = URL(fileURLWithPath: args[i + 1])
        } else {
            bundle = Bundle(for: BundleMarker.self).bundleURL
        }
        let binary = try #require(parserTestExecutable(bundledAt: bundle), "Current test product must have an .xctest ancestor; no PATH fallback")
        #expect(FileManager.default.isExecutableFile(atPath: binary.path))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("parser251-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let out = root.appendingPathComponent("stdout"), err = root.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: out.path, contents: nil)
        FileManager.default.createFile(atPath: err.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: out), stderr = try FileHandle(forWritingTo: err)
        defer { try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let deadline = Date().addingTimeInterval(15)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        if process.isRunning {
            process.terminate()
            let grace = Date().addingTimeInterval(1)
            while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.02) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw NSError(domain: "JSONParserFailureTests.Timeout", code: 1)
        }
        process.waitUntilExit()
        return Result(status: process.terminationStatus, stdout: try String(contentsOf: out, encoding: .utf8), stderr: try String(contentsOf: err, encoding: .utf8))
    }
}

private final class BundleMarker: NSObject {}

private func parserTestExecutable(bundledAt location: URL) -> URL? {
    var candidate = location
    while candidate.path != "/" {
        // macOS: bundle directory or Contents/MacOS executable. Linux: .xctest file.
        if candidate.pathExtension == "xctest" {
            return candidate.deletingLastPathComponent().appendingPathComponent("triton")
        }
        candidate.deleteLastPathComponent()
    }
    return nil
}

private struct ExclusiveFixture: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "fixture")
    enum Selector: String, EnumerableFlag { case first, second }
    @Flag(exclusivity: .exclusive) var selector: Selector?
    @Flag var json = false
}

private struct ValidationFixture: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "fixture")
    @Flag var json = false
    mutating func validate() throws { throw ValidationError("secret-validation-251") }
}
