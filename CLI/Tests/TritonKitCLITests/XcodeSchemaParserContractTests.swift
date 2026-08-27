import Foundation
import Testing
@testable import TritonKitCLI

/// Contract tests keeping the xcode schema inventory executable: every option the schema
/// advertises for a subcommand must be accepted by that subcommand's real ArgumentParser,
/// and every parent-level option must be accepted by at least one subcommand.
/// Regression coverage for issue #210 (schema advertised `--progress` for `xcode run`,
/// whose parser rejected it).
@Suite
struct XcodeSchemaParserContractTests {
    @Test("every advertised xcode subcommand option is accepted by its parser")
    func subcommandOptionsAreAcceptedByParsers() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let optionTypes = Dictionary(uniqueKeysWithValues: xcode.options.map { ($0.name, $0.type) })

        for subcommand in xcode.subcommands {
            var declared = subcommand.requiredOptions + subcommand.optionalOptions
            for set in subcommand.oneOfRequiredOptions { declared.append(contentsOf: set) }
            for set in subcommand.oneOfRequiredOptionSets { declared.append(contentsOf: set) }
            for name in declared {
                let argv = ["xcode", subcommand.name] + Self.argv(for: name, type: optionTypes[name])
                do {
                    _ = try TritonKitCLI.parseAsRoot(argv)
                } catch {
                    let description = String(describing: error)
                    #expect(
                        !description.contains("Unknown option"),
                        "schema advertises \(name) for xcode \(subcommand.name) but the parser rejects it: \(description)"
                    )
                }
            }
        }
    }

    @Test("every parent xcode option is accepted by at least one subcommand parser")
    func parentOptionsAreAcceptedSomewhere() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })

        for option in xcode.options where option.type != "Subcommand" {
            var rejectionCount = 0
            var lastDescription = ""
            for subcommand in xcode.subcommands {
                let argv = ["xcode", subcommand.name] + Self.argv(for: option.name, type: option.type)
                do {
                    _ = try TritonKitCLI.parseAsRoot(argv)
                } catch {
                    let description = String(describing: error)
                    if description.contains("Unknown option") {
                        rejectionCount += 1
                        lastDescription = description
                    }
                }
            }
            #expect(
                rejectionCount < xcode.subcommands.count,
                "parent option \(option.name) is rejected by every xcode subcommand parser; last error: \(lastDescription)"
            )
        }
    }

    @Test("progress flag scope stays limited to build, test, archive, and export")
    func progressFlagScopeMatchesParsers() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        for action in ["build", "test", "archive", "export"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == action })
            #expect(subcommand.optionalOptions.contains("--progress"))
            do {
                _ = try TritonKitCLI.parseAsRoot(["xcode", action, "--progress", "compact"])
            } catch {
                #expect(String(describing: error).contains("Unknown option") == false)
            }
        }
        for action in ["discover", "use", "schemes", "status", "wait-idle", "settings", "run"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == action })
            #expect(!subcommand.optionalOptions.contains("--progress"))
            #expect(throws: Error.self) {
                _ = try TritonKitCLI.parseAsRoot(["xcode", action, "--progress", "compact"])
            }
        }
    }

    private static func argv(for name: String, type: String?) -> [String] {
        guard let type, !type.isEmpty else { return [name] }
        if type.hasPrefix("Bool") { return [name] }
        if type.contains("|") {
            let firstChoice = type.split(separator: "|").first.map(String.init) ?? "compact"
            return [name, firstChoice]
        }
        if type == "Double" { return [name, "1.5"] }
        if type == "Int" { return [name, "2"] }
        if type.hasPrefix("KEY=VALUE") { return [name, "A=B"] }
        return [name, "dummy"]
    }
}
