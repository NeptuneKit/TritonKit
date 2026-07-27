import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

func commandSchemas() -> [TKCommandSchema] {
    let schemas = bootstrapCommandSchemas()
        + testCommandSchemas()
        + workspaceCommandSchemas()
        + testRecorderCommandSchemas()
        + updateCommandSchemas()
        + targetCommandSchemas()
        + xcodeCommandSchemas()
        + buildCommandSchemas()
        + mapCommandSchemas()
        + vlmCommandSchemas()
        + debugCommandSchemas()
        + runtimeCommandSchemas()
        + hostCommandSchemas()
        + observationCommandSchemas()
        + actionCommandSchemas()
    return schemas
        .filter { !retiredRootCommandNames.contains($0.name) }
        .map(schemaWithFailureFamilyRecovery)
        .map(schemaWithProductSurfaceMetadata)
}

private let retiredRootCommandNames: Set<String> = [
    "find", "tap", "type", "paste", "clear", "swipe", "press", "focus", "set-text", "select-segment", "set-switch", "input",
    "assert", "capture",
    "runtime", "state", "snapshot", "hierarchy", "nodes", "attrs", "object", "geometry", "ax", "hit", "ledger",
]

private let targetFailureRecoveryCommand = "triton target resolve <selector> --json"
private let xcodeRealDeviceTargetFailureRecoveryCommand = "triton target resolve <selector> --platform ios --scope real --ready --json"
private let projectFailureRecoveryCommand = "triton xcode discover --path . --json"
private let actionFailureRecoveryCommand = "triton act input --json --summary --strict"
private let destructivePolicyFailureRecoveryCommand = "triton plan --format json"
private let xcodeRealDevicePreflightActions: Set<String> = ["settings", "build", "test", "run"]

private let targetFailureCodesRequiringRecovery: Set<String> = [
    "ambiguous_target",
    "device_not_ready",
    "simulator_not_found",
    "target_not_found",
    "target_offline",
    "target_platform_mismatch",
    "target_unavailable",
]

private let projectFailureCodesRequiringRecovery: Set<String> = [
    "ambiguous_workspace",
    "invalid_workspace_path",
    "scheme_not_found",
    "workspace_not_found",
    "xcode_not_idle",
]

private let actionFailureCodesRequiringRecovery: Set<String> = [
    "action_failed",
    "step_failed",
]

private let destructivePolicyFailureCodesRequiringRecovery: Set<String> = [
    "confirmation_required",
    "destructive_action_requires_policy",
]

private let unsupportedFailureCodesRequiringRecovery: Set<String> = [
    "action_not_supported",
    "contract_quality_review_required",
    "ios_host_ax_unsupported_platform",
    "redaction_review_required",
    "unmapped_contract_feature",
    "unsupported_compiled_contract",
    "unsupported_host_action",
    "unsupported_import_platform",
    "unsupported_capability",
    "unsupported_runtime_scope",
    "webview_method_not_allowed",
    "webview_wait_unsupported",
]

private let runtimeTransportFailureCodesRequiringRecovery: Set<String> = [
    "request_failed",
    "request_timeout",
    "runtime_not_connected",
    "runtime_unavailable",
    "server_unavailable",
]

private let verificationFailureCodesRequiringRecovery: Set<String> = [
    "assertion_failed",
    "route_mismatch",
    "text_not_found",
    "timeout",
]

private func schemaWithFailureFamilyRecovery(_ schema: TKCommandSchema) -> TKCommandSchema {
    let targetRecoveryOverride = schema.name == "xcode"
        ? xcodeRealDeviceTargetFailureRecoveryCommand
        : nil
    return TKCommandSchema(
        name: schema.name,
        summary: schema.summary,
        requiresServer: schema.requiresServer,
        requiresTarget: schema.requiresTarget,
        requiresHierarchy: schema.requiresHierarchy,
        runtimeScope: schema.runtimeScope,
        exitCodeOnFailure: schema.exitCodeOnFailure,
        outputFormats: schema.outputFormats,
        options: schema.options,
        usageForms: schema.usageForms,
        argumentForms: schema.argumentForms,
        examples: schema.examples,
        successShape: schema.successShape,
        failureShape: schema.failureShape,
        outputSemantics: schema.outputSemantics,
        requiredOptions: schema.requiredOptions,
        inheritsDefaultsFrom: schema.inheritsDefaultsFrom,
        jsonlEvents: schema.jsonlEvents,
        finalEventKind: schema.finalEventKind,
        artifacts: schema.artifacts,
        retryable: schema.retryable,
        nextCommands: nextCommandsWithFailureFamilyRecovery(
            schema.nextCommands,
            failureCodes: schema.failureCodes,
            targetRecoveryOverride: targetRecoveryOverride
        ),
        outputContracts: schema.outputContracts,
        failureCodes: schema.failureCodes,
        subcommands: schema.subcommands.map { subcommand in
            subcommandWithFailureFamilyRecovery(
                subcommand,
                targetRecoveryOverride: schema.name == "xcode" && xcodeRealDevicePreflightActions.contains(subcommand.name)
                    ? xcodeRealDeviceTargetFailureRecoveryCommand
                    : nil
            )
        },
        inputActions: schema.inputActions,
        providedCapabilities: schema.providedCapabilities,
        surfaceLayer: schema.surfaceLayer,
        deprecatedForMainPath: schema.deprecatedForMainPath,
        replacementCommand: schema.replacementCommand,
        rawDebugCommand: schema.rawDebugCommand,
        surfaceRationale: schema.surfaceRationale
    )
}

private struct CommandSurfaceMetadata {
    let layer: String
    let deprecatedForMainPath: Bool
    let replacementCommand: String?
    let rawDebugCommand: String?
    let rationale: String?
}

private let commandSurfaceMetadata: [String: CommandSurfaceMetadata] = {
    var metadata: [String: CommandSurfaceMetadata] = [:]

    func workflow(_ name: String, rationale: String) {
        metadata[name] = CommandSurfaceMetadata(layer: "workflow", deprecatedForMainPath: false, replacementCommand: nil, rawDebugCommand: nil, rationale: rationale)
    }

    func diagnostic(_ name: String, rationale: String) {
        metadata[name] = CommandSurfaceMetadata(layer: "diagnostic", deprecatedForMainPath: false, replacementCommand: nil, rawDebugCommand: nil, rationale: rationale)
    }

    func hostAdapter(_ name: String, rationale: String) {
        metadata[name] = CommandSurfaceMetadata(layer: "host-adapter", deprecatedForMainPath: false, replacementCommand: nil, rawDebugCommand: nil, rationale: rationale)
    }

    func agentSupport(_ name: String, rationale: String) {
        metadata[name] = CommandSurfaceMetadata(layer: "agent-support", deprecatedForMainPath: false, replacementCommand: nil, rawDebugCommand: nil, rationale: rationale)
    }

    func compatibility(_ name: String, replacement: String, rationale: String) {
        metadata[name] = CommandSurfaceMetadata(layer: "compatibility", deprecatedForMainPath: true, replacementCommand: replacement, rawDebugCommand: nil, rationale: rationale)
    }

    func rawEngine(_ name: String, replacement: String?, debug: String, rationale: String) {
        metadata[name] = CommandSurfaceMetadata(layer: "raw-engine", deprecatedForMainPath: true, replacementCommand: replacement, rawDebugCommand: debug, rationale: rationale)
    }

    metadata["debug"] = CommandSurfaceMetadata(
        layer: "raw-engine",
        deprecatedForMainPath: false,
        replacementCommand: nil,
        rawDebugCommand: nil,
        rationale: "Explicit P23 raw/debug surface for low-level engine inspection"
    )

    for name in ["doctor", "schema", "capabilities", "plan", "workspace", "target", "app", "observe", "node", "act", "verify", "evidence", "test", "testrec", "update", "xcode", "build", "wait", "screenshot"] {
        workflow(name, rationale: "P23 workflow surface")
    }
    for name in ["status", "serve"] {
        diagnostic(name, rationale: "Diagnostic and local service control surface")
    }
    for name in ["device", "sim", "web", "webview", "route"] {
        hostAdapter(name, rationale: "Host adapter or provider-specific surface retained outside the first P23 workflow cut")
    }
    for name in ["map", "vlm", "action"] {
        agentSupport(name, rationale: "Agent support surface retained outside the first P23 workflow cut")
    }

    compatibility("find", replacement: "triton act find <text> --json", rationale: "Target resolution is an action preparation workflow")
    compatibility("tap", replacement: "triton act tap --text <text> --json", rationale: "tap is an action primitive under act")
    compatibility("type", replacement: "triton act type <text> --json", rationale: "type is an action primitive under act")
    compatibility("paste", replacement: "triton act paste <text> --json", rationale: "paste is an action primitive under act")
    compatibility("clear", replacement: "triton act clear --json", rationale: "clear is an action primitive under act")
    compatibility("swipe", replacement: "triton act swipe --start-x <x1> --start-y <y1> --end-x <x2> --end-y <y2> --json", rationale: "swipe is an action primitive under act")
    compatibility("press", replacement: "triton act press <button> --json", rationale: "press is an action primitive under act")
    compatibility("focus", replacement: "triton act focus <selector> --json", rationale: "focus is an action primitive under act")
    compatibility("set-text", replacement: "triton act set-text <selector> <text> --json", rationale: "set-text is an action primitive under act")
    compatibility("select-segment", replacement: "triton act select-segment <selector> <value> --json", rationale: "select-segment is an action primitive under act")
    compatibility("set-switch", replacement: "triton act set-switch <selector> <value> --json", rationale: "set-switch is an action primitive under act")
    compatibility("input", replacement: "triton act input --json --summary --strict", rationale: "input batches belong to the action workflow surface")
    compatibility("assert", replacement: "triton verify text-exists <text> --json", rationale: "assertion implementation remains available; verify is the product workflow language")
    compatibility("capture", replacement: "triton evidence capture --case <case> --output <dir.tritonevidence> --json", rationale: "capture is evidence collection under the Prove workflow")

    rawEngine("runtime", replacement: nil, debug: "triton debug runtime manifest", rationale: "runtime API details are raw engine facts")
    rawEngine("state", replacement: "triton observe current --json", debug: "triton debug state app", rationale: "state is raw runtime state; observe is the workflow entry")
    rawEngine("snapshot", replacement: "triton observe current --json", debug: "triton debug snapshot", rationale: "snapshot is a raw runtime aggregate; observe is the workflow entry")
    rawEngine("hierarchy", replacement: "triton observe tree --json", debug: "triton debug hierarchy", rationale: "hierarchy is an engine tree fact source")
    rawEngine("nodes", replacement: "triton observe tree --json", debug: "triton debug nodes", rationale: "nodes are raw tree enumeration")
    rawEngine("attrs", replacement: nil, debug: "triton debug attrs", rationale: "attrs are raw object attributes")
    rawEngine("object", replacement: nil, debug: "triton debug object", rationale: "object metadata is raw runtime inspection")
    rawEngine("geometry", replacement: "triton observe current --json", debug: "triton debug geometry", rationale: "geometry is a low-level observation fact")
    rawEngine("ax", replacement: "triton observe tree --json", debug: "triton debug ax", rationale: "AX is a raw accessibility fact source")
    rawEngine("ledger", replacement: "triton evidence capture --case <case> --output <dir.tritonevidence> --json", debug: "triton debug ledger", rationale: "ledger is audit/debug state, not the user workflow entry")

    return metadata
}()

private func schemaWithProductSurfaceMetadata(_ schema: TKCommandSchema) -> TKCommandSchema {
    let metadata = commandSurfaceMetadata[schema.name]
    return TKCommandSchema(
        name: schema.name,
        summary: schema.summary,
        requiresServer: schema.requiresServer,
        requiresTarget: schema.requiresTarget,
        requiresHierarchy: schema.requiresHierarchy,
        runtimeScope: schema.runtimeScope,
        exitCodeOnFailure: schema.exitCodeOnFailure,
        outputFormats: schema.outputFormats,
        options: schema.options,
        usageForms: schema.usageForms,
        argumentForms: schema.argumentForms,
        examples: schema.examples,
        successShape: schema.successShape,
        failureShape: schema.failureShape,
        outputSemantics: schema.outputSemantics,
        requiredOptions: schema.requiredOptions,
        inheritsDefaultsFrom: schema.inheritsDefaultsFrom,
        jsonlEvents: schema.jsonlEvents,
        finalEventKind: schema.finalEventKind,
        artifacts: schema.artifacts,
        retryable: schema.retryable,
        nextCommands: schema.nextCommands,
        recoveryCommands: schema.recoveryCommands,
        outputContracts: schema.outputContracts,
        failureCodes: schema.failureCodes,
        subcommands: schema.subcommands,
        inputActions: schema.inputActions,
        providedCapabilities: schema.providedCapabilities,
        surfaceLayer: metadata?.layer ?? schema.surfaceLayer,
        deprecatedForMainPath: metadata?.deprecatedForMainPath ?? schema.deprecatedForMainPath,
        replacementCommand: metadata?.replacementCommand ?? schema.replacementCommand,
        rawDebugCommand: metadata?.rawDebugCommand ?? schema.rawDebugCommand,
        surfaceRationale: metadata?.rationale ?? schema.surfaceRationale
    )
}

private func subcommandWithFailureFamilyRecovery(
    _ subcommand: TKCommandSubcommandSchema,
    targetRecoveryOverride: String? = nil
) -> TKCommandSubcommandSchema {
    let nextCommands = nextCommandsWithFailureFamilyRecovery(
        subcommand.nextCommands,
        failureCodes: subcommand.failureCodes,
        targetRecoveryOverride: targetRecoveryOverride
    )
    let recoveryCommands = nextCommands
        .compactMap(TKCommandRecoveryCommand.init(commandString:))
        .reduce(into: subcommand.recoveryCommands) { commands, command in
            guard !commands.contains(where: { $0.command == command.command }) else { return }
            commands.append(command)
        }

    return TKCommandSubcommandSchema(
        name: subcommand.name,
        summary: subcommand.summary,
        requiresServer: subcommand.requiresServer,
        requiresTarget: subcommand.requiresTarget,
        requiresConfirmation: subcommand.requiresConfirmation,
        sideEffect: subcommand.sideEffect,
        optionOverrides: subcommand.optionOverrides,
        requiredOptions: subcommand.requiredOptions,
        oneOfRequiredOptions: subcommand.oneOfRequiredOptions,
        optionalOptions: subcommand.optionalOptions,
        defaultProviders: subcommand.defaultProviders,
        inheritsDefaultsFrom: subcommand.inheritsDefaultsFrom,
        jsonlEvents: subcommand.jsonlEvents,
        finalEventKind: subcommand.finalEventKind,
        artifacts: subcommand.artifacts,
        retryable: subcommand.retryable,
        nextCommands: nextCommands,
        recoveryCommands: recoveryCommands,
        outputSelectors: subcommand.outputSelectors,
        failureCodes: subcommand.failureCodes
    )
}

private func nextCommandsWithFailureFamilyRecovery(
    _ nextCommands: [String],
    failureCodes: [String],
    targetRecoveryOverride: String? = nil
) -> [String] {
    let failureCodes = Set(failureCodes)
    var commands = nextCommands
    if !failureCodes.isDisjoint(with: targetFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique(targetRecoveryOverride ?? targetFailureRecoveryCommand)
    }
    if !failureCodes.isDisjoint(with: runtimeTransportFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique("triton doctor --json")
    }
    if !failureCodes.isDisjoint(with: verificationFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique("triton verify text-exists <text> --json")
        commands = commands.appendingUnique("triton observe current --json")
        commands = commands.appendingUnique("triton evidence capture --case <case> --output <dir.tritonevidence> --json")
    }
    if !failureCodes.isDisjoint(with: projectFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique(projectFailureRecoveryCommand)
    }
    if !failureCodes.isDisjoint(with: actionFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique(actionFailureRecoveryCommand)
    }
    if !failureCodes.isDisjoint(with: destructivePolicyFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique(destructivePolicyFailureRecoveryCommand)
    }
    if !failureCodes.isDisjoint(with: unsupportedFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique(destructivePolicyFailureRecoveryCommand)
    }
    return commands
}

private extension Array where Element == String {
    func appendingUnique(_ value: String) -> [String] {
        contains(value) ? self : self + [value]
    }
}
