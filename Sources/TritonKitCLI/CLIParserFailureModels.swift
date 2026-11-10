import Foundation
import TritonKitShared

/// CLI-only pre-execution contract. No raw argv or library diagnostic is encoded.
struct CLIParserFailureEnvelope: Encodable, Equatable {
    let ok = false
    let action = "cli.parse"
    let commandPath: [String]
    let error: CLIParserFailureDetail
}

struct CLIParserFailureDetail: Encodable, Equatable {
    let code: String
    let message: String
    let hint: String?
    let retryable = false
    let details: CLIParserFailureArguments
    let nextAction: TKCLINextAction
    let help: TKCLINextAction
}

struct CLIParserFailureArguments: Encodable, Equatable {
    let kind: String
    let argumentNames: [String]
    let count: Int?
    let valuesRedacted = true
}
