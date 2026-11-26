import ArgumentParser
import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct PublicSkillCommandSchemaTests {
    @Test("public skill command snapshot matches the current CLI schema")
    func snapshotMatchesCurrentSchema() throws {
        let snapshotURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs-linhay/scripts/public-skill-command-schema.json")
        let snapshot = try JSONDecoder().decode(
            PublicSkillCommandSchemaSnapshot.self,
            from: Data(contentsOf: snapshotURL)
        )
        let current = Dictionary(uniqueKeysWithValues: commandSchemas().map { command in
            (command.name, command.subcommands.map(\.name).sorted())
        })

        #expect(snapshot.schemaVersion == 1)
        #expect(snapshot.commands.mapValues { $0.sorted() } == current)

        // The packaging linter's arity snapshot includes aliases, not just canonical names.
        for (name, rule) in snapshot.validatedCommandArguments {
            let path = name.split(separator: ".")
            let command = try #require(commandSchemas().first { $0.name == path[0] })
            let scoped: Set<String>?
            if path.count == 2 {
                let subcommand = try #require(command.subcommands.first { $0.name == path[1] })
                scoped = Set(subcommand.requiredOptions + subcommand.optionalOptions)
            } else {
                try #require(path.count == 1)
                scoped = nil
            }
            let options = Dictionary(uniqueKeysWithValues: command.options.flatMap { option in
                option.name.split(separator: "/").map(String.init).filter { scoped?.contains($0) ?? true }
                    .map { ($0, option.type == "Bool" ? 0 : 1) }
            })
            #expect(rule.options == options)
        }
    }

    @Test("bundled wait example parses for every platform and preserves both target aliases")
    func bundledWaitExampleParsesWithoutRunning() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let skill = try String(contentsOf: root.appendingPathComponent(
            "TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md"
        ), encoding: .utf8)
        let examples = skill.components(separatedBy: .newlines).filter { $0.hasPrefix("triton wait ") }
        #expect(examples.count == 1)
        // Tokenize the actual documented single-line example; do not reconstruct its argv.
        let tokenizer = try NSRegularExpression(pattern: #""[^"\\]*"|'[^'\\]*'|[^\s"']+"#)
        for example in examples {
            #expect(example.contains("--device <selector>"))
            for platform in ["ios", "android", "harmony"] {
                for alias in ["--device", "--target"] {
                    let commandLine = example
                        .replacingOccurrences(of: "<ios|android|harmony>", with: platform)
                        .replacingOccurrences(of: "<selector>", with: "__public_skill_parser_only__")
                        .replacingOccurrences(of: "--device", with: alias)
                    let nsLine = commandLine as NSString
                    let argv = tokenizer.matches(in: commandLine, range: NSRange(location: 0, length: nsLine.length)).map { match in
                        let token = nsLine.substring(with: match.range)
                        return token.hasPrefix("\"") || token.hasPrefix("'") ? String(token.dropFirst().dropLast()) : token
                    }
                    let wait = try #require(TritonKitCLI.parseAsRoot(Array(argv.dropFirst())) as? Wait)
                    #expect(wait.text == "成功")
                    #expect(wait.platform?.rawValue == platform)
                    #expect(wait.target == "__public_skill_parser_only__")
                    #expect(wait.json)
                }
            }
        }
    }

    @Test("public shared-cache build example parses without running")
    func bundledSharedCacheBuildExampleParses() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let workflow = try String(contentsOf: root.appendingPathComponent(
            "TritonKit.skills/tritonkit-real-project-regression/references/workflow.md"
        ), encoding: .utf8)
        let joined = workflow.replacingOccurrences(of: "\\\n", with: " ")
        let commandLine = try #require(joined.components(separatedBy: .newlines).first {
            $0.hasPrefix("triton xcode build ") && $0.contains("--compilation-cache")
        })
        let tokenizer = try NSRegularExpression(pattern: #""[^"\\]*"|'[^'\\]*'|[^\s"']+"#)
        let source = commandLine as NSString
        let tokens = tokenizer.matches(in: commandLine, range: NSRange(location: 0, length: source.length)).map { match in
            let token = source.substring(with: match.range)
            return token.hasPrefix("\"") || token.hasPrefix("'") ? String(token.dropFirst().dropLast()) : token
        }
        let build = try #require(TritonKitCLI.parseAsRoot(Array(tokens.dropFirst())) as? XcodeBuild)
        #expect(build.compilationCache == .shared)
        #expect(build.casPath == "$SHARED_CAS")
        #expect(build.derivedDataPath == "$CHECKOUT_DERIVED_DATA")
        #expect(build.destination == "generic/platform=iOS Simulator")
    }

    @Test("actual parser rejects positional and malformed wait examples without running")
    func malformedWaitExamplesFailParsing() {
        for arguments in [
            ["wait", "text", "成功", "--platform", "harmony", "--device", "placeholder", "--json"],
            ["wait", "--platform", "harmony", "text", "Ready", "--target", "placeholder", "--json"],
            ["wait", "--text-contains", "Ready", "--device", "placeholder", "--json"],
            ["wait", "--text", "--json"],
            ["wait", "--idle=true", "--json"],
        ] {
            #expect(throws: Error.self) { _ = try TritonKitCLI.parseAsRoot(arguments) }
        }
    }
}

private struct PublicSkillCommandSchemaSnapshot: Decodable {
    let schemaVersion: Int
    let commands: [String: [String]]
    let validatedCommandArguments: [String: ArgumentRule]

    struct ArgumentRule: Decodable {
        let options: [String: Int]
    }
}
