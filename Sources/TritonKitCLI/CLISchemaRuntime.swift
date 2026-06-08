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
        + targetCommandSchemas()
        + xcodeCommandSchemas()
        + buildCommandSchemas()
        + runtimeCommandSchemas()
        + hostCommandSchemas()
        + observationCommandSchemas()
        + actionCommandSchemas()
    return schemas.map(schemaWithFailureFamilyRecovery)
}

private let targetFailureRecoveryCommand = "triton target resolve <selector> --json"
private let projectFailureRecoveryCommand = "triton xcode discover --path . --json"
private let actionFailureRecoveryCommand = "triton input --json --summary --strict"
private let destructivePolicyFailureRecoveryCommand = "triton plan --format json"

private let targetFailureCodesRequiringRecovery: Set<String> = [
    "ambiguous_target",
    "device_not_ready",
    "simulator_not_found",
    "target_not_found",
    "target_offline",
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
    "unsupported_host_action",
    "unsupported_capability",
    "unsupported_runtime_scope",
    "webview_method_not_allowed",
    "webview_wait_unsupported",
]

private func schemaWithFailureFamilyRecovery(_ schema: TKCommandSchema) -> TKCommandSchema {
    TKCommandSchema(
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
        nextCommands: nextCommandsWithFailureFamilyRecovery(schema.nextCommands, failureCodes: schema.failureCodes),
        outputContracts: schema.outputContracts,
        failureCodes: schema.failureCodes,
        subcommands: schema.subcommands.map(subcommandWithFailureFamilyRecovery),
        inputActions: schema.inputActions,
        providedCapabilities: schema.providedCapabilities
    )
}

private func subcommandWithFailureFamilyRecovery(_ subcommand: TKCommandSubcommandSchema) -> TKCommandSubcommandSchema {
    TKCommandSubcommandSchema(
        name: subcommand.name,
        summary: subcommand.summary,
        requiredOptions: subcommand.requiredOptions,
        oneOfRequiredOptions: subcommand.oneOfRequiredOptions,
        optionalOptions: subcommand.optionalOptions,
        defaultProviders: subcommand.defaultProviders,
        inheritsDefaultsFrom: subcommand.inheritsDefaultsFrom,
        jsonlEvents: subcommand.jsonlEvents,
        finalEventKind: subcommand.finalEventKind,
        artifacts: subcommand.artifacts,
        retryable: subcommand.retryable,
        nextCommands: nextCommandsWithFailureFamilyRecovery(subcommand.nextCommands, failureCodes: subcommand.failureCodes),
        outputSelectors: subcommand.outputSelectors,
        failureCodes: subcommand.failureCodes
    )
}

private func nextCommandsWithFailureFamilyRecovery(_ nextCommands: [String], failureCodes: [String]) -> [String] {
    let failureCodes = Set(failureCodes)
    var commands = nextCommands
    if !failureCodes.isDisjoint(with: targetFailureCodesRequiringRecovery) {
        commands = commands.appendingUnique(targetFailureRecoveryCommand)
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
