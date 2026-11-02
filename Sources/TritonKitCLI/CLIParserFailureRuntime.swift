import ArgumentParser
import Foundation

/// Recognize only explicit, exact output tokens before the positional terminator.
/// An invalid --format alone has no JSON intent and keeps the library's text fallback.
func parserRequestsJSON(_ arguments: [String]) -> Bool {
    let tokens = Array(arguments.prefix { $0 != "--" })
    var index = 0
    var jsonFlag = false
    var format: String?
    while index < tokens.count {
        let token = tokens[index]
        if token == "--json" { jsonFlag = true }
        if token.hasPrefix("--format=") { format = String(token.dropFirst("--format=".count)) }
        if token == "--format" {
            // ArgumentParser does not consume a following option as a scalar value.
            // In particular --format --json is missing a value AND explicitly JSON.
            if index + 1 < tokens.count, !tokens[index + 1].hasPrefix("-") {
                format = tokens[index + 1]
                index += 1
            } else {
                format = nil
            }
        }
        index += 1
    }
    return jsonFlag || format == "json"
}

/// Called only around parseAsRoot, never around a command's run method.
func parserFailureEnvelope(
    error: Error,
    arguments: [String],
    root: ParsableCommand.Type = TritonKitCLI.self
) -> CLIParserFailureEnvelope? {
    guard parserRequestsJSON(arguments), root.exitCode(for: error) == .validationFailure else { return nil }

    // ParserError is internal to ArgumentParser. Public diagnostics are inspected only
    // for fixed category markers; the diagnostic itself is never returned to a client.
    let message = root.message(for: error)
    let context = parserCommandContext(arguments, root: root)
    let knownNames = parserDeclaredNames(context.command)
    var code = "argument_validation_failed"
    var kind = "validation"
    var summary = "Command arguments failed validation. Correct the arguments before retrying."
    var names: [String] = []
    var count: Int?

    if message.hasPrefix("Missing expected argument '") || message.hasPrefix("Missing one of: '") {
        code = "missing_argument"; kind = "missing"
        summary = "A required argument is missing."
        names = knownNames.filter { message.contains($0) }.sorted()
    } else if message.hasPrefix("Missing value for '") {
        code = "missing_argument_value"; kind = "missing-value"
        summary = "An option requires a value."
        names = knownNames.filter { message.contains($0) }.sorted()
    } else if message == "Missing required subcommand." {
        code = "missing_subcommand"; kind = "missing-command"
        summary = "A subcommand is required."
    } else if message.hasPrefix("Unknown option '") || message.hasPrefix("Invalid option:") {
        code = "unknown_option"; kind = "unknown-option"; count = 1
        summary = "An option is not recognized. Its spelling and value are omitted."
    } else if message.hasPrefix("Unexpected argument '") || message.range(of: #"^\d+ unexpected arguments:"#, options: .regularExpression) != nil {
        code = "unexpected_argument"; kind = "unexpected"
        summary = "Unexpected positional arguments were supplied. Values are omitted."
        count = message.hasPrefix("Unexpected argument '") ? 1 : Int(message.prefix { $0.isNumber })
    } else if message.hasPrefix("The value '") && message.contains("' is invalid") {
        code = "invalid_argument_value"; kind = "invalid-value"
        summary = "An argument value is invalid. The value is omitted."
        // Split at the final marker so an adversarial value cannot forge a field name.
        if let range = message.range(of: "' is invalid for '", options: .backwards) {
            let suffix = String(message[range.upperBound...].prefix { $0 != "'" })
            names = knownNames.filter { suffix.contains($0) }.sorted()
        }
    } else if message.hasPrefix("Value to be set with ") && message.contains(" had already been set with ") {
        code = "conflicting_arguments"; kind = "conflict"
        summary = "Mutually exclusive arguments were supplied together."
        names = knownNames.filter { $0.hasPrefix("-") && message.contains("'\($0)'") }.sorted()
    } else if message.hasPrefix("The option '") && message.contains("' does not take any value") {
        code = "unexpected_argument_value"; kind = "unexpected-value"
        summary = "A flag was supplied a value it does not accept."
        let prefix = message.components(separatedBy: "' does not take any value")[0]
        names = knownNames.filter { $0.hasPrefix("-") && prefix.contains("'\($0)'") }.sorted()
    }

    let path = context.path
    let schemaArgs = path.count > 1 ? ["--command", path.dropFirst().joined(separator: " "), "--json"] : ["--json"]
    return CLIParserFailureEnvelope(commandPath: path, error: .init(
        code: code, message: summary,
        details: .init(kind: kind, argumentNames: names, count: count),
        nextAction: .init(command: "schema", args: schemaArgs),
        help: .init(command: "help", args: Array(path.dropFirst()))
    ))
}

/// A conservative recognized prefix: stop at the first non-command token rather
/// than treating an option value, secret positional, or unknown spelling as a path.
private func parserCommandContext(_ arguments: [String], root: ParsableCommand.Type) -> (command: ParsableCommand.Type, path: [String]) {
    var command = root
    var path = [root._commandName]
    for token in arguments {
        guard let child = command.configuration.subcommands.first(where: { $0._commandName == token }) else { break }
        command = child
        path.append(child._commandName)
    }
    return (command, path)
}

/// Only static declaration names may appear in the error; never extract names
/// from argv/diagnostics. Help is generated locally from registered Swift types.
private func parserDeclaredNames(_ command: ParsableCommand.Type) -> Set<String> {
    let help = command.helpMessage(includeHidden: true, columns: 10000)
        .split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.hasPrefix("-") || $0.hasPrefix("<") }
        .map { $0.components(separatedBy: "  ")[0] }
        .joined(separator: "\n")
    let expression = try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9_-])--?[A-Za-z][A-Za-z0-9-]*|<[A-Za-z][A-Za-z0-9-]*>"#)
    let range = NSRange(help.startIndex..<help.endIndex, in: help)
    return Set(expression.matches(in: help, range: range).compactMap { match in
        Range(match.range, in: help).map { String(help[$0]) }
    })
}

func runCLIWithParserFailures(_ arguments: [String]) async {
    var command: ParsableCommand
    do {
        command = try TritonKitCLI.parseAsRoot(arguments)
    } catch {
        if let envelope = parserFailureEnvelope(error: error, arguments: arguments) {
            // These fixed Codable fields cannot fail encoding under JSONEncoder.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            do {
                let data = try encoder.encode(envelope)
                FileHandle.standardOutput.write(data + Data([0x0a]))
                Foundation.exit(ExitCode.validationFailure.rawValue)
            } catch {
                // Never expose the original parser error on the machine path.
                FileHandle.standardOutput.write(Data("{\"ok\":false,\"action\":\"cli.parse\",\"error\":{\"code\":\"argument_validation_failed\",\"message\":\"Unable to encode parser failure.\",\"retryable\":false}}\n".utf8))
                Foundation.exit(ExitCode.validationFailure.rawValue)
            }
        }
        TritonKitCLI.exit(withError: error)
    }
    do {
        if var asyncCommand = command as? AsyncParsableCommand { try await asyncCommand.run() }
        else { try command.run() }
    } catch {
        // Preserve existing runtime envelopes and deliberate ExitCode failures.
        TritonKitCLI.exit(withError: error)
    }
}
