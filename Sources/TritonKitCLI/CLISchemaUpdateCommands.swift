import Foundation
import TritonKitShared

func updateCommandSchemas() -> [TKCommandSchema] {
    [
        TKCommandSchema(
            name: "update",
            summary: "Check or update the TritonKit CLI from GitHub Release/Homebrew",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "host",
            outputFormats: schemaTextJSONFormats,
            options: [
                TKCommandSchemaOption(name: "--check", type: "Bool", defaultValue: "false", description: "Only check and print the update plan; never mutate local files"),
                TKCommandSchemaOption(name: "--dry-run", type: "Bool", defaultValue: "false", description: "Print the update plan without executing mutating actions"),
                TKCommandSchemaOption(name: "--yes", type: "Bool", defaultValue: "false", description: "Confirm mutating update actions"),
                TKCommandSchemaOption(name: "--version", type: "String", description: "Target release tag or version, for example v0.1.24"),
                TKCommandSchemaOption(name: "--include-skills", type: "Bool", defaultValue: "false", description: "Also update the public TritonKit.skills bundle from the same release"),
                TKCommandSchemaOption(name: "--skills-dir", type: "String", description: "Agent skills root directory used with --include-skills"),
                TKCommandSchemaOption(name: "--repository", type: "String", defaultValue: "NeptuneKit/TritonKit", description: "GitHub repository, owner/name"),
                schemaFormatTextJSONOption,
                schemaJSONAliasOption,
            ],
            usageForms: [
                TKCommandUsageForm(form: "check", kind: "Task", description: "Check for a target or latest release and print the machine-readable plan"),
                TKCommandUsageForm(form: "homebrew-update", kind: "Task", description: "Update a Homebrew-managed triton binary through brew update/upgrade"),
                TKCommandUsageForm(form: "manual-update", kind: "Task", description: "Download, checksum, extract, and replace a manually installed triton binary"),
                TKCommandUsageForm(form: "skills-update", kind: "Task", description: "Update public TritonKit.skills from the same release"),
            ],
            examples: [
                "triton update --check --json",
                "triton update --version v0.1.24 --dry-run --json",
                "triton update --version v0.1.24 --yes --json",
                "triton update --include-skills --skills-dir ~/.codex/skills --yes --json",
            ],
            successShape: "{ ok, currentVersion, targetVersion, installSource, updateAvailable, actions[], updated, skillsUpdated }",
            failureShape: "{ ok:false, error:{ code,message,hint? } }",
            outputSemantics: "Agent-readable self-update plan and execution result; mutating updates require --yes.",
            nextCommands: [
                "triton update --check --json",
                "triton version --json",
                "triton web --print-command --json",
            ],
            outputContracts: [
                updatePlanOutputContract(),
            ],
            failureCodes: [
                "release_resolution_failed",
                "download_failed",
                "invalid_checksum_manifest",
                "checksum_missing",
                "checksum_mismatch",
                "confirmation_required",
                "source_checkout_update_unsupported",
                "skills_dir_required",
                "host_command_failed",
                "extract_failed",
                "update_failed",
            ],
            subcommands: [
                TKCommandSubcommandSchema(
                    name: "check",
                    summary: "Equivalent to triton update --check --json",
                    optionalOptions: ["--version", "--repository"],
                    outputSelectors: ["update.plan"],
                    failureCodes: ["release_resolution_failed", "update_failed"]
                )
            ],
            providedCapabilities: ["cli-update"]
        )
    ]
}
