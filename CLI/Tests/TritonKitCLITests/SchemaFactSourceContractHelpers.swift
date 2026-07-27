import Testing
import TritonKitShared
@testable import TritonKitCLI

func expectContract(
    _ schema: TKCommandSchema,
    selector: String,
    fields expectedFields: [String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let contract = schema.outputContracts.first { $0.selector == selector }
    #expect(contract != nil, sourceLocation: sourceLocation)
    let fieldNames = contract?.fields.map(\.name) ?? []
    for expectedField in expectedFields {
        #expect(fieldNames.contains(expectedField), "Missing \(selector).\(expectedField)", sourceLocation: sourceLocation)
    }
}

struct SchemaBackedCommandIssues {
    var unknownCommands: [String] = []
    var unknownSubcommands: [String] = []
    var unknownFlags: [String] = []
}

struct CommandStringFixture {
    let context: String
    let command: String
    let argv: [String]
    let isSubcommand: Bool

    init(context: String, command: String, argv: [String], isSubcommand: Bool = false) {
        self.context = context
        self.command = command
        self.argv = argv
        self.isSubcommand = isSubcommand
    }
}

func commandSchemaMap() -> [String: TKCommandSchema] {
    Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
}

func collectRecoveryCommandListIssues(
    _ commands: [String],
    context: String,
    blank: inout [String],
    duplicate: inout [String]
) {
    for command in commands where command.allSatisfy(\.isWhitespace) {
        blank.append(context)
    }

    let duplicates = Set(commands)
        .filter { command in commands.filter { $0 == command }.count > 1 }
        .sorted()
    duplicate.append(contentsOf: duplicates.map { "\(context):\($0)" })
}

func validateRecoveryCommands(
    _ recoveryCommands: [TKCommandRecoveryCommand],
    nextCommands: [String],
    context: String,
    mismatchedCommandLists: inout [String],
    invalidCategories: inout [String]
) {
    if recoveryCommands.map(\.command) != nextCommands {
        mismatchedCommandLists.append(context)
    }

    for recoveryCommand in recoveryCommands {
        guard let root = TKCommandRecoveryCommand.rootCommand(in: recoveryCommand.command),
              let expectedCategory = TKCommandRecoveryCommand.category(forRootCommand: root) else {
            invalidCategories.append("\(context):\(recoveryCommand.command)")
            continue
        }
        if recoveryCommand.category != expectedCategory {
            invalidCategories.append("\(context):\(recoveryCommand.command):\(recoveryCommand.category)")
        }
    }
}

func validateFailureCodes(
    _ failureCodes: [String],
    context: String,
    unmappedFailureCodes: inout [String],
    invalidRecoveryCategories: inout [String]
) {
    for failureCode in failureCodes {
        guard let expectedCategories = recoveryCategories(forFailureCode: failureCode) else {
            unmappedFailureCodes.append("\(context):\(failureCode)")
            continue
        }
        invalidRecoveryCategories.append(
            contentsOf: expectedCategories
                .filter { !TKCommandRecoveryCommand.categoryTaxonomy.contains($0) }
                .sorted()
                .map { "\(context):\(failureCode):\($0)" }
        )
    }
}

func validateArtifactFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forArtifactFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forArtifactFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "artifact_output_rejected", "artifact_write_failed", "file_write_failed", "overwrite_refused", "xcresult_output_too_large":
        return ["archive"]
    default:
        return nil
    }
}

func validateAssertionFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forAssertionFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forAssertionFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "assertion_failed", "route_mismatch", "text_not_found":
        return ["verify"]
    default:
        return nil
    }
}

func validateRuntimeTransportFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forRuntimeTransportFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forRuntimeTransportFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "server_unavailable", "request_failed", "request_timeout", "runtime_unavailable", "runtime_not_connected":
        return ["diagnose"]
    default:
        return nil
    }
}

func validateTargetFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forTargetFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forTargetFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "ambiguous_target", "device_not_ready", "simulator_not_found", "target_not_found", "target_offline", "target_platform_mismatch", "target_unavailable":
        return ["prepare-target"]
    default:
        return nil
    }
}

func validateProjectFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forProjectFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forProjectFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "ambiguous_workspace", "invalid_workspace_path", "scheme_not_found", "workspace_not_found", "xcode_not_idle":
        return ["project"]
    default:
        return nil
    }
}

func validateActionFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forActionFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forActionFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "action_failed", "step_failed":
        return ["act"]
    default:
        return nil
    }
}

func validateDestructivePolicyFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forDestructivePolicyFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forDestructivePolicyFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "confirmation_required", "destructive_action_requires_policy":
        return ["plan"]
    default:
        return nil
    }
}

func validateUnsupportedFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forUnsupportedFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

func requiredRecoveryCategories(forUnsupportedFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "action_not_supported", "ios_host_ax_unsupported_platform", "unsupported_capability", "unsupported_runtime_scope", "webview_method_not_allowed", "webview_wait_unsupported":
        return ["plan"]
    default:
        return nil
    }
}

func expectNoSchemaBackedCommandIssues(
    _ issues: SchemaBackedCommandIssues,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(issues.unknownCommands == [], sourceLocation: sourceLocation)
    #expect(issues.unknownSubcommands == [], sourceLocation: sourceLocation)
    #expect(issues.unknownFlags == [], sourceLocation: sourceLocation)
}

func isMachineReadableSchemaType(_ type: String) -> Bool {
    guard !type.isEmpty, !type.contains(where: \.isWhitespace) else {
        return false
    }

    let nonOptional = type.hasSuffix("?") ? String(type.dropLast()) : type
    if nonOptional.contains("|") {
        return nonOptional
            .split(separator: "|", omittingEmptySubsequences: false)
            .allSatisfy { isMachineReadableSchemaType(String($0)) }
    }
    if nonOptional.hasPrefix("[") || nonOptional.hasSuffix("]") {
        guard nonOptional.hasPrefix("["), nonOptional.hasSuffix("]") else {
            return false
        }
        let inner = String(nonOptional.dropFirst().dropLast())
        if inner.contains(":") {
            let keyValue = inner.split(separator: ":", omittingEmptySubsequences: false)
            return keyValue.count == 2 && keyValue.allSatisfy { isSchemaTypeUnion(String($0)) }
        }
        return isSchemaTypeUnion(inner)
    }
    return isSchemaTypeUnion(nonOptional)
}

func isSchemaTypeUnion(_ type: String) -> Bool {
    let parts = type.split(separator: "|", omittingEmptySubsequences: false)
    guard !parts.isEmpty else {
        return false
    }
    return parts.allSatisfy { part in
        guard let first = part.first, first.isLetter else {
            return false
        }
        return part.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_"
        }
    }
}

func isAgentSelectorKey(_ key: String) -> Bool {
    let parts = key.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty else {
        return false
    }
    return parts.allSatisfy { isKebabCaseKey(String($0)) }
}

func isAgentEventKey(_ key: String, allowingPlaceholders: Bool) -> Bool {
    let parts = key.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count >= 2 else {
        return false
    }
    return parts.allSatisfy { part in
        let value = String(part)
        return isKebabCaseKey(value) || (allowingPlaceholders && isCompletePlaceholderToken(value))
    }
}

func isPlanMetadataKey(_ key: String) -> Bool {
    let parts = key.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty else {
        return false
    }
    return parts.allSatisfy { isKebabCaseKey(String($0)) }
}

func isKebabCaseKey(_ key: String) -> Bool {
    guard let first = key.first, first.isLowercase else {
        return false
    }
    return key.allSatisfy { character in
        character.isLowercase || character.isNumber || character == "-"
    }
}

func isSnakeCaseKey(_ key: String) -> Bool {
    guard let first = key.first, first.isLowercase else {
        return false
    }
    return key.allSatisfy { character in
        character.isLowercase || character.isNumber || character == "_"
    }
}

func isLongOptionKeyExpression(_ key: String) -> Bool {
    let aliases = key.split(separator: "/", omittingEmptySubsequences: false)
    guard !aliases.isEmpty else {
        return false
    }
    return aliases.allSatisfy { alias in
        alias.hasPrefix("--") && isKebabCaseKey(String(alias.dropFirst(2)))
    }
}

func validateSchemaBackedCommandExpression(
    _ commandString: String,
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    guard let argv = extractSingleTritonInvocationArgv(from: commandString) else {
        issues.unknownCommands.append("\(context): \(commandString)")
        return
    }
    validateSchemaBackedArgv(argv, context: context, schemas: schemas, issues: &issues)
}

func validateSchemaBackedArgv(
    _ argv: [String],
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    guard argv.first == "triton", argv.count >= 2 else {
        issues.unknownCommands.append("\(context): \(argv.joined(separator: " "))")
        return
    }
    validateSchemaBackedCommand(
        commandName: argv[1],
        args: Array(argv.dropFirst(2)),
        context: context,
        schemas: schemas,
        issues: &issues
    )
}

func validateSchemaBackedNextAction(
    _ commandName: String,
    args: [String],
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    validateSchemaBackedArgv(["triton", commandName] + args, context: context, schemas: schemas, issues: &issues)
}

func tritonRootCommand(in commandString: String) -> String? {
    let tokens = commandString.split(separator: " ").map(String.init)
    guard let tritonIndex = tokens.firstIndex(of: "triton"), tokens.count > tritonIndex + 1 else {
        return nil
    }
    return tokens[tritonIndex + 1]
}

func tritonRootCommand(in argv: [String]) -> String? {
    guard argv.first == "triton", argv.count >= 2 else {
        return nil
    }
    return argv[1]
}

func tritonInvocationCount(in commandString: String) -> Int {
    commandString.split(separator: " ").filter { $0 == "triton" }.count
}

func validateSchemaBackedCommand(
    commandName: String,
    args: [String],
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    guard let schema = schemas[commandName] else {
        issues.unknownCommands.append("\(context): \(commandName)")
        return
    }

    if let subcommand = args.first, !subcommand.hasPrefix("-"), !schema.subcommands.isEmpty {
        if !schema.subcommands.contains(where: { $0.name == subcommand }) {
            issues.unknownSubcommands.append("\(context): \(commandName) \(subcommand)")
        }
    }

    let knownFlags = schemaKnownFlags(schema)
    for flag in args where flag.hasPrefix("--") {
        if !knownFlags.contains(flag) {
            issues.unknownFlags.append("\(context): \(commandName) \(flag)")
        }
    }
}

func schemaKnownFlags(_ schema: TKCommandSchema) -> Set<String> {
    var flags = Set<String>()
    for option in schema.options {
        flags.formUnion(flagNames(from: option.name))
    }
    for subcommand in schema.subcommands {
        for option in subcommand.requiredOptions {
            flags.formUnion(flagNames(from: option))
        }
        for option in subcommand.optionalOptions {
            flags.formUnion(flagNames(from: option))
        }
        for options in subcommand.oneOfRequiredOptions {
            for option in options {
                flags.formUnion(flagNames(from: option))
            }
        }
    }
    return flags
}

func schemaKnownParameterKeys(_ schema: TKCommandSchema) -> Set<String> {
    var keys = Set<String>()
    for option in schema.options {
        keys.formUnion(flagNames(from: option.name))
    }
    for argument in schema.argumentForms {
        keys.insert(argument.name)
    }
    return keys
}

func flagNames(from optionName: String) -> [String] {
    optionName
        .split(separator: "|")
        .flatMap { $0.split(separator: "/") }
        .compactMap { token in
            let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.hasPrefix("--") ? value : nil
        }
}

func isCompletePlaceholderToken(_ arg: String) -> Bool {
    arg.hasPrefix("<") && arg.hasSuffix(">") && !arg.dropFirst().dropLast().contains("<") && !arg.dropFirst().dropLast().contains(">")
}

func malformedPlaceholderTokens(in commandString: String, context: String) -> [String] {
    commandString
        .split(separator: " ")
        .map(String.init)
        .filter { $0.contains("<") || $0.contains(">") }
        .filter { !isCompletePlaceholderToken($0) }
        .map { "\(context):\($0)" }
}

func malformedPlaceholderTokens(in argv: [String], context: String) -> [String] {
    argv
        .filter { $0.contains("<") || $0.contains(">") }
        .filter { !isCompletePlaceholderToken($0) }
        .map { "\(context):\($0)" }
}

func isSingleTritonInvocation(_ commandString: String) -> Bool {
    let tokens = commandString.split(separator: " ").map(String.init)
    guard tokens.first == "triton" else {
        return false
    }

    let forbiddenTokens: Set<String> = ["|", "&&", "||", ";", "<", ">", ">>", "2>", "2>>"]
    return !tokens.contains(where: { forbiddenTokens.contains($0) || $0.hasPrefix("$(") || $0.hasPrefix("`") })
}

func extractSingleTritonInvocationArgv(from commandString: String) -> [String]? {
    let tokens = commandString.split(separator: " ").map(String.init)
    guard let tritonIndex = tokens.firstIndex(of: "triton") else {
        return nil
    }

    let stopTokens: Set<String> = ["|", "&&", "||", ";", "<", ">", ">>", "2>", "2>>"]
    var argv: [String] = []
    for token in tokens[tritonIndex...] {
        if stopTokens.contains(token) || token.hasPrefix("$(") || token.hasPrefix("`") {
            break
        }
        argv.append(token)
    }
    return argv.count >= 2 ? argv : nil
}
