import Foundation
import TritonKitShared

/// A resolved, opt-in view. The full TKCommandSchema remains the fact source.
struct CLICompactSchemaResponse: Encodable {
    let projectionVersion = 1
    let schemaVersion = 1
    let cliVersion = TritonKitBuildInfo.cliVersion
    var fingerprint = ""
    let fingerprintAlgorithm = "sha256-sorted-json-without-fingerprint"
    let command: String
    let summary: String
    let options: [TKCommandSchemaOption]
    let argumentForms: [TKCommandArgumentForm]
    let requiredOptions: [String]
    let optionalOptions: [String]
    let oneOfRequiredOptions: [[String]]
    let oneOfRequiredOptionSets: [[String]]
    let selectorConstraints: [CLICompactSelectorConstraint]
    let outputContracts: [TKCommandOutputContract]
    let outputSemantics: String?
    let failureShape: String?
    let failureCodes: [String]
    let requiresServer: Bool
    let requiresTarget: Bool
    let requiresHierarchy: Bool
    let requiresConfirmation: Bool
    let sideEffect: String
    let requirementsResolution = "conservative-root-and-ancestor-union"
    let safetyPolicy = "False/none defaults in the full schema do not prove absence of an inherited requirement or side effect. Unknown outcomes must not be automatically replayed; inspect the result and verify the business postcondition before recovery. Output semantics are inherited verbatim and may include sibling context."
    let runtimeScope: String
    let exitCodeOnFailure: Int
    let outputFormats: [String]
    let inheritsDefaultsFrom: [String]
    let defaultProviders: [String]
    let jsonlEvents: [String]
    let finalEventKind: String?
    let artifacts: [String]
    let retryable: Bool
    let nextCommands: [String]
    let recoveryCommands: [TKCommandRecoveryCommand]
    let inputActions: [TKInputActionSchema]?
    let surfaceLayer: String
    let deprecatedForMainPath: Bool
    let replacementCommand: String?
    let rawDebugCommand: String?
    let surfaceRationale: String?
    let fullSchemaCommand: [String]
}

struct CompactSchemaError: Error, CustomStringConvertible {
    let code: String
    let command: String?
    let description: String

    var response: TKCLIErrorResponse {
        let args = command.map { ["--command", $0, "--json"] } ?? ["--json"]
        return TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: code,
            message: description,
            hint: "Inspect the full schema without --compact; incomplete metadata is not permission to execute or replay an action.",
            nextAction: TKCLINextAction(command: "schema", args: args)
        ))
    }
}

/// Each source contributes an independent constraint. Legacy oneOf shapes are
/// normalized only when they unambiguously express one reference from a list.
struct CLICompactSelectorConstraint: Encodable {
    let source: String
    let exactlyOneOf: [String]
    let exactlyOneOptionSet: [[String]]
}
