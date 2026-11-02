import CryptoKit
import Foundation
import TritonKitShared

func buildCompactSchemaResponse(
    command: String?, commands: [TKCommandSchema] = commandSchemas()
) throws -> CLICompactSchemaResponse {
    let parts = (command ?? "").split { $0.isWhitespace || $0 == "." }.map(String.init)
    guard let name = parts.first else {
        throw CompactSchemaError(code: "compact_schema_requires_leaf", command: nil, description: "--compact requires --command naming a leaf command.")
    }
    let canonical = parts.joined(separator: ".")
    guard let root = commands.first(where: { $0.name == name }) else {
        throw SchemaCommandLookupError(command: canonical)
    }
    var children = root.subcommands
    var ancestry: [TKCommandSubcommandSchema] = []
    for part in parts.dropFirst() {
        guard let child = children.first(where: { $0.name == part }) else {
            throw SchemaCommandLookupError(command: canonical)
        }
        ancestry.append(child)
        children = child.subcommands
    }
    guard children.isEmpty else {
        throw CompactSchemaError(code: "compact_schema_requires_leaf", command: canonical, description: "Compact schema requires a leaf, not the \(canonical) command group.")
    }
    func incomplete(_ message: String) -> CompactSchemaError {
        CompactSchemaError(code: "compact_schema_incomplete", command: canonical, description: message)
    }
    let leaf = ancestry.last
    var required = compactUnique(root.requiredOptions + ancestry.flatMap(\.requiredOptions))
    let optional = compactUnique(ancestry.flatMap(\.optionalOptions))
    let allOneOf = ancestry.flatMap(\.oneOfRequiredOptions)
    let allOneOfSets = ancestry.flatMap(\.oneOfRequiredOptionSets)
    let references = compactUnique(required + optional + allOneOf.flatMap { $0 } + allOneOfSets.flatMap { $0 })
    var constraints: [CLICompactSelectorConstraint] = []
    for (index, node) in ancestry.enumerated() {
        let legacy = node.oneOfRequiredOptions
        guard !legacy.contains(where: \.isEmpty),
              !node.oneOfRequiredOptionSets.contains(where: \.isEmpty),
              legacy.count <= 1 || legacy.allSatisfy({ $0.count == 1 }) else {
            throw incomplete("Ambiguous legacy selector groups for \(node.name); inspect the full schema and runtime validation.")
        }
        if !legacy.isEmpty || !node.oneOfRequiredOptionSets.isEmpty {
            constraints.append(CLICompactSelectorConstraint(
                source: parts.prefix(index + 2).joined(separator: "."),
                exactlyOneOf: compactUnique(legacy.flatMap { $0 }),
                exactlyOneOptionSet: node.oneOfRequiredOptionSets
            ))
        }
    }
    let overrides = ancestry.flatMap(\.optionOverrides)
    var definitions = root.options + root.argumentForms.map {
        TKCommandSchemaOption(name: $0.name, type: $0.type, required: $0.required, description: $0.description)
    }
    for override in overrides {
        let keys = Set(compactOptionAliases(override.name))
        let index = definitions.firstIndex { !keys.isDisjoint(with: compactOptionAliases($0.name)) }
        if let index {
            // An override of either alias changes the same underlying option.
            let old = definitions[index]
            let aliases = compactUnique(compactOptionAliases(old.name) + compactOptionAliases(override.name))
            definitions[index] = TKCommandSchemaOption(name: aliases.joined(separator: "/"), type: override.type, required: override.required, defaultValue: override.defaultValue, description: override.description)
        } else {
            definitions.append(override)
        }
    }
    var selectedOptions: [TKCommandSchemaOption] = []
    var selectedArguments: [TKCommandArgumentForm] = []
    var selectedReferences = Set(references.flatMap(compactOptionAliases))
    let overriddenAliases = Set(overrides.flatMap { compactOptionAliases($0.name) })
    // A required override is itself an authoritative requirement, even if its
    // name was not redundantly repeated in requiredOptions. Do not import
    // unrelated required declarations from a shared root option catalog.
    for definition in definitions where definition.required {
        let aliases = compactOptionAliases(definition.name)
        guard !overriddenAliases.isDisjoint(with: aliases) else { continue }
        if let reference = aliases.first(where: selectedReferences.contains) ?? aliases.first {
            selectedReferences.insert(reference)
        }
    }
    // Only an effective declaration contributes its required bit: an inner
    // override can replace an outer declaration, including required/default.
    required = compactUnique(required + definitions.filter(\.required).compactMap {
        compactOptionAliases($0.name).first { leaf == nil || selectedReferences.contains($0) }
    })
    let requiredReferences = Set(required.flatMap(compactOptionAliases))
    for definition in definitions {
        let aliases = compactOptionAliases(definition.name)
        let selected = aliases.filter { leaf == nil || selectedReferences.contains($0) }
        guard !selected.isEmpty else { continue }
        let isRequired = !requiredReferences.isDisjoint(with: selected)
        if definition.name.hasPrefix("-") {
            selectedOptions.append(TKCommandSchemaOption(name: selected.joined(separator: "/"), type: definition.type, required: isRequired, defaultValue: definition.defaultValue, description: definition.description))
        } else {
            selectedArguments.append(TKCommandArgumentForm(name: definition.name, type: definition.type, required: isRequired, description: definition.description))
        }
    }
    let effectiveRequiredAliases = Set(selectedOptions.filter(\.required).flatMap { compactOptionAliases($0.name) } + selectedArguments.filter(\.required).map(\.name))
    let effectiveOptional = leaf == nil
        ? selectedOptions.filter { !$0.required }.flatMap { compactOptionAliases($0.name) } + selectedArguments.filter { !$0.required }.map(\.name)
        : optional.filter { !effectiveRequiredAliases.contains($0) }
    let resolved = Set(selectedOptions.flatMap { compactOptionAliases($0.name) } + selectedArguments.map(\.name))
    let missing = selectedReferences.subtracting(resolved).sorted()
    guard missing.isEmpty else { throw incomplete("Unresolved argument references: \(missing.joined(separator: ", ")).") }
    let selectors = leaf?.outputSelectors ?? root.outputContracts.map(\.selector)
    guard !selectors.isEmpty else { throw incomplete("No output selectors are declared for \(canonical).") }
    var contracts: [TKCommandOutputContract] = []
    for selector in compactUnique(selectors) {
        let matching = root.outputContracts.filter { $0.selector == selector }
        guard !matching.isEmpty else { throw incomplete("Unresolved output selector: \(selector).") }
        contracts.append(contentsOf: matching)
    }
    let effects = ancestry.map(\.sideEffect).filter { $0 != "none" && $0 != "unknown" && !$0.isEmpty }
    var response = CLICompactSchemaResponse(
        command: canonical, summary: leaf?.summary ?? root.summary,
        options: selectedOptions, argumentForms: selectedArguments,
        requiredOptions: required, optionalOptions: effectiveOptional,
        oneOfRequiredOptions: leaf?.oneOfRequiredOptions ?? [], oneOfRequiredOptionSets: leaf?.oneOfRequiredOptionSets ?? [],
        selectorConstraints: constraints,
        outputContracts: contracts, outputSemantics: root.outputSemantics,
        failureShape: root.failureShape,
        failureCodes: compactUnique(root.failureCodes + ancestry.flatMap(\.failureCodes)),
        requiresServer: root.requiresServer || ancestry.contains(where: \.requiresServer),
        requiresTarget: root.requiresTarget || ancestry.contains(where: \.requiresTarget),
        requiresHierarchy: root.requiresHierarchy,
        requiresConfirmation: ancestry.contains(where: \.requiresConfirmation),
        sideEffect: effects.isEmpty ? (leaf?.sideEffect == "none" ? "none" : "unknown") : compactUnique(effects).joined(separator: "; "),
        sideEffectCases: compactUnique(ancestry.flatMap(\.sideEffectCases)),
        runtimeScope: root.runtimeScope, exitCodeOnFailure: root.exitCodeOnFailure,
        outputFormats: root.outputFormats,
        inheritsDefaultsFrom: compactUnique(root.inheritsDefaultsFrom + ancestry.flatMap(\.inheritsDefaultsFrom)),
        defaultProviders: compactUnique(ancestry.flatMap(\.defaultProviders)),
        jsonlEvents: compactUnique(root.jsonlEvents + ancestry.flatMap(\.jsonlEvents)),
        finalEventKind: ancestry.reversed().compactMap(\.finalEventKind).first ?? root.finalEventKind,
        artifacts: compactUnique(root.artifacts + ancestry.flatMap(\.artifacts)),
        retryable: leaf?.retryable ?? root.retryable,
        nextCommands: compactUnique(root.nextCommands + ancestry.flatMap(\.nextCommands)),
        recoveryCommands: compactUnique(root.recoveryCommands + ancestry.flatMap(\.recoveryCommands)),
        inputActions: (leaf == nil || leaf?.name == "input") ? root.inputActions : nil,
        surfaceLayer: root.surfaceLayer, deprecatedForMainPath: root.deprecatedForMainPath,
        replacementCommand: root.replacementCommand, rawDebugCommand: root.rawDebugCommand,
        surfaceRationale: root.surfaceRationale,
        fullSchemaCommand: ["triton", "schema", "--command", canonical, "--json"]
    )
    let encoded = try JSONEncoder().encode(response)
    guard var payload = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
        throw incomplete("Compact projection could not be encoded as an object.")
    }
    payload.removeValue(forKey: "fingerprint")
    let canonicalBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
    response.fingerprint = SHA256.hash(data: canonicalBytes).map { String(format: "%02x", $0) }.joined()
    return response
}

private func compactOptionAliases(_ name: String) -> [String] {
    // Positional paths may contain slashes; only option declarations use alias separators.
    name.hasPrefix("-") ? name.split(separator: "/").map(String.init) : [name]
}

private func compactUnique<T: Equatable>(_ values: [T]) -> [T] {
    values.reduce(into: []) { result, value in if !result.contains(value) { result.append(value) } }
}
