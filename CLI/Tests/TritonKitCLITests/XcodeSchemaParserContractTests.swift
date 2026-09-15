import Foundation
import TritonKitShared
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

        func visit(_ subcommand: TKCommandSubcommandSchema, path: [String]) throws {
            var declared = subcommand.requiredOptions + subcommand.optionalOptions
            for set in subcommand.oneOfRequiredOptions { declared.append(contentsOf: set) }
            for set in subcommand.oneOfRequiredOptionSets { declared.append(contentsOf: set) }
            for name in declared {
                let leaf = path.last ?? subcommand.name
                let argv = ["xcode"] + path + Self.requiredArguments(for: leaf, excluding: name) + Self.argv(for: name, type: optionTypes[name])
                _ = try TritonKitCLI.parseAsRoot(argv)
            }
            for child in subcommand.subcommands { try visit(child, path: path + [child.name]) }
        }
        for subcommand in xcode.subcommands { try visit(subcommand, path: [subcommand.name]) }
    }

    @Test("every parent xcode option is accepted by at least one subcommand parser")
    func parentOptionsAreAcceptedSomewhere() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })

            func collect(_ command: TKCommandSubcommandSchema, path: [String]) -> [([String], TKCommandSubcommandSchema)] {
                [(path, command)] + command.subcommands.flatMap { collect($0, path: path + [$0.name]) }
            }
            let all = xcode.subcommands.flatMap { collect($0, path: [$0.name]) }
            for option in xcode.options where option.type != "Subcommand" && !["--json", "--format"].contains(option.name) {
                let accepting = all.filter { item in
                    let s = item.1
                    return (s.requiredOptions + s.optionalOptions).contains(option.name)
                }
                #expect(!accepting.isEmpty, "parent option \(option.name) must have a declared subcommand scope")
                for (path, subcommand) in accepting {
                    let leaf = path.last ?? subcommand.name
                    let argv = ["xcode"] + path + Self.requiredArguments(for: leaf, excluding: option.name) + Self.argv(for: option.name, type: option.type)
                    _ = try TritonKitCLI.parseAsRoot(argv)
                }
            }
    }

    @Test("progress flag scope stays limited to build, test, archive, and export")
    func progressFlagScopeMatchesParsers() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        for action in ["build", "test", "archive", "export"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == action })
            #expect(subcommand.optionalOptions.contains("--progress"))
            _ = try TritonKitCLI.parseAsRoot(["xcode", action] + Self.requiredArguments(for: action) + ["--progress", "compact"])
        }
        for action in ["discover", "use", "schemes", "status", "wait-idle", "settings", "run"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == action })
            #expect(!subcommand.optionalOptions.contains("--progress"))
            #expect(throws: Error.self) {
                _ = try TritonKitCLI.parseAsRoot(["xcode", action, "--progress", "compact"])
            }
        }
    }

    private static func requiredArguments(for command: String, excluding: String? = nil) -> [String] {
        let required: [(String, String)]
        switch command {
        case "use": required = [("--scheme", "App")]
        case "archive": required = [("--archive-path", "App.xcarchive")]
        case "export": required = [("--archive-path", "App.xcarchive"), ("--export-options-plist", "ExportOptions.plist"), ("--export-path", "export")]
        default: required = []
        }
        return required.filter { $0.0 != excluding }.flatMap { [$0.0, $0.1] }
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
