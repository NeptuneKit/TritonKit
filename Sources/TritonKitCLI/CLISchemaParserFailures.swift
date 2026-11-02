import TritonKitShared

let parserFailureOutputSemantics = "Before command execution, explicit --json, --format json or --format=json requests receive cli.parse failures as one stdout JSON envelope with empty stderr and exit 64. error.retryable is false until arguments are corrected. Codes: missing_argument, missing_argument_value, missing_subcommand, unknown_option, unexpected_argument, invalid_argument_value, conflicting_arguments, unexpected_argument_value, argument_validation_failed. commandPath is the recognized registered command prefix; argumentNames contain only trusted declaration names; unknown names and all supplied values are omitted. Details may be empty for custom validation. Help/version retain conventional successful output. No valid explicit JSON request (including an invalid --format alone) keeps the traditional text fallback; tokens after -- do not request JSON. Existing command execution errors retain their own envelopes and exit codes."

func parserFailureOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "cli.parse.failure", format: "json", kind: "envelope", model: "CLIParserFailureEnvelope", fields: schemaContractFields([
        ("ok", "Bool", true, "Always false; parser rejected arguments before command execution"),
        ("action", "String", true, "Always cli.parse"),
        ("commandPath", "[String]", true, "Recognized prefix from the registered command tree, beginning with triton; never raw argv"),
        ("error", "CLIParserFailureDetail", true, "Pre-execution validation failure; distinct from runtime/domain errors"),
        ("error.code", "String", true, "Stable parser category; custom/unknown validation falls back to argument_validation_failed"),
        ("error.message", "String", true, "Static safe summary; original parser messages and values are never returned"),
        ("error.hint", "String?", false, "Static migration guidance for recognized retired roots; never supplied argument values"),
        ("error.retryable", "Bool", true, "Always false until arguments are corrected"),
        ("error.details", "CLIParserFailureArguments", true, "Safe argument diagnostics without raw argv"),
        ("error.details.kind", "String", true, "missing|missing-value|missing-command|unknown-option|unexpected|invalid-value|conflict|unexpected-value|validation"),
        ("error.details.argumentNames", "[String]", true, "Known declaration names only, empty when unknown; unknown flag spellings are redacted"),
        ("error.details.count", "Int?", false, "Number of unexpected arguments or unknown options when available"),
        ("error.details.valuesRedacted", "Bool", true, "Always true"),
        ("error.nextAction", "TKCLINextAction?", true, "Safe schema recovery, command=schema; no user values"),
        ("error.help", "TKCLINextAction?", true, "Safe conventional help recovery, command=help; no user values"),
    ]))
}
