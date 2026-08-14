import Foundation
import TritonKitShared

func targetCommandSchemas() -> [TKCommandSchema] {
    let jsonText = schemaTextJSONFormats
    let jsonAlias = schemaJSONAliasOption
    let hostPort = schemaHostPortOptions

    return [
        TKCommandSchema(
            name: "target",
            summary: "Discover, resolve, track, and lease the current agent target",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "host-target",
            exitCodeOnFailure: 1,
            outputFormats: jsonText,
            options: hostPort + [
                TKCommandSchemaOption(name: "list", type: "Subcommand", description: "List iOS Simulator or Harmony HDC targets"),
                TKCommandSchemaOption(name: "use <selector>", type: "Subcommand", description: "Resolve a target selector and save it as the current agent target"),
                TKCommandSchemaOption(name: "current", type: "Subcommand", description: "Show the current agent target"),
                TKCommandSchemaOption(name: "resolve <selector>", type: "Subcommand", description: "Resolve a target selector without executing an action"),
                TKCommandSchemaOption(name: "wait-ready <selector>", type: "Subcommand", description: "Wait for a target to become ready"),
                TKCommandSchemaOption(name: "lease acquire --target <udid> --owner <label>", type: "Subcommand", description: "Acquire a bounded-TTL target lease; requires `triton serve`"),
                TKCommandSchemaOption(name: "lease status --target <udid>", type: "Subcommand", description: "Show held/expired/none lease state for a target"),
                TKCommandSchemaOption(name: "lease release --target <udid> --lease <id>", type: "Subcommand", description: "Release the held lease with the matching token"),
                TKCommandSchemaOption(name: "lease takeover --target <udid> --owner <label> --confirm", type: "Subcommand", description: "Explicitly take over a lease held by another owner"),
                TKCommandSchemaOption(name: "--platform", type: "ios|android|harmony", defaultValue: "harmony", description: "Host target platform"),
                TKCommandSchemaOption(name: "--target", type: "String", description: "Simulator target selector for lease subcommands: UDID, sim:<udid>, booted, or current"),
                TKCommandSchemaOption(name: "--scope", type: "simulator|emulator|real|all", description: "Host target scope filter for resolve"),
                TKCommandSchemaOption(name: "--name", type: "String", description: "Device name filter, for example iPhone 15"),
                TKCommandSchemaOption(name: "--runtime", type: "String", description: "Runtime filter, for example iOS 26.5"),
                TKCommandSchemaOption(name: "--state", type: "String", description: "Target state filter, for example booted or connected"),
                TKCommandSchemaOption(name: "--ready", type: "Bool", defaultValue: "false", description: "Only match ready targets"),
                TKCommandSchemaOption(name: "--hdc", type: "Path", defaultValue: "hdc", description: "HDC executable path"),
                TKCommandSchemaOption(name: "--adb", type: "Path", defaultValue: "adb", description: "ADB executable path"),
                TKCommandSchemaOption(name: "--timeout", type: "Double", defaultValue: "30", description: "Bounded wait timeout in seconds"),
                TKCommandSchemaOption(name: "--interval", type: "Double", defaultValue: "1", description: "Readiness poll interval in seconds"),
                TKCommandSchemaOption(name: "--owner", type: "String", description: "Opaque caller-provided owner label for lease acquire/takeover"),
                TKCommandSchemaOption(name: "--lease", type: "String", description: "Lease token for lease release or mutating command enforcement"),
                TKCommandSchemaOption(name: "--ttl", type: "Int", defaultValue: "300", description: "Lease TTL in seconds (30...86400)"),
                TKCommandSchemaOption(name: "--readonly-observation-allowed", type: "Bool", defaultValue: "true", description: "Whether read-only observation is permitted while the lease is held"),
                TKCommandSchemaOption(name: "--confirm", type: "Bool", defaultValue: "false", description: "Explicitly confirm lease takeover that displaces the current owner"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            argumentForms: [
                TKCommandArgumentForm(name: "<selector>", type: "String", required: true, description: "Target selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current"),
            ],
            examples: [
                "triton target list --platform ios --json",
                "triton target use booted --platform ios --json",
                "triton target current --json",
                "triton target resolve booted --platform ios --scope simulator --json",
                "triton target resolve --platform harmony --name 'Codex Test Phone' --ready --json",
                "triton target wait-ready harmony-a --platform harmony --json",
                "triton target lease acquire --target <udid> --owner agent-a --ttl 300 --json",
                "triton target lease status --target <udid> --json",
                "triton target lease release --target <udid> --lease <lease-id> --json",
                "triton target lease takeover --target <udid> --owner agent-b --ttl 300 --confirm --json",
            ],
            successShape: "{ ok, platform, targets[]?, defaultTarget?, target?, defaultsPath?, current?, selection?, path?, ready?, attempt?, sourceCommand? } or lease { ok, status: acquired|already_held|taken_over, target, lease:{ id,target,owner,acquiredAt,expiresAt,ttlSeconds,readonlyObservationAllowed,kind }, previousOwner? } or lease status { ok, status: held|expired|none, target, lease? } or lease release { ok, released, status: released|none, target, lease? }",
            failureShape: "{ ok:false, error:{ code: ambiguous_target|target_not_found|target_offline|target_platform_mismatch|device_not_ready|host_command_timeout|host_command_failed|target_lease_conflict, message, hint, leaseReason?, currentOwner?, currentLeaseID?, currentExpiresAt?, suggestedCommands? } }",
            outputSemantics: "Use target as the agent-facing target discovery, selection, and readiness fact source. It is the preferred entry before app, runtime, observe, action, assert, evidence, or replay flows. `target lease` is the opt-in, auditable reservation surface for parallel agent flows: acquire a bounded-TTL lease with an opaque --owner label, inspect held/expired/none state, release with the matching token, or explicitly take over another flow's lease with --confirm. Lease state lives in `triton serve`; mutating host/runtime commands accept `--lease <id>` and fail with the stable target_lease_conflict envelope when another flow holds the lease. Read-only observation commands are exempt and never conflict. Without `--lease`, behavior is unchanged.",
            nextCommands: [
                "triton target resolve <selector> --json",
                "triton target use <selector> --json",
                "triton target wait-ready <selector> --json",
                "triton target lease acquire --target <udid> --owner <label> --json",
                "triton app open-url <url> --device <selector> --lease <lease-id> --wait-ready --snapshot --json",
            ],
            outputContracts: [
                hostDeviceListOutputContract(),
                hostDeviceSelectionOutputContract(),
                hostDeviceReadyOutputContract(),
                targetLeaseOutputContract(),
            ],
            failureCodes: [
                "ambiguous_target",
                "target_not_found",
                "target_offline",
                "target_platform_mismatch",
                "device_not_ready",
                "host_command_timeout",
                "host_command_failed",
                "target_lease_conflict",
                "lease_ttl_out_of_range",
                "lease_owner_required",
                "lease_target_required",
                "server_unavailable",
                "invalid_payload",
                "request_failed",
                "validation_failed",
            ],
            subcommands: [
                TKCommandSubcommandSchema(
                    name: "list",
                    summary: "List iOS Simulator or Harmony HDC targets",
                    optionalOptions: ["--platform", "--hdc", "--adb", "--format", "--json"],
                    outputSelectors: ["host.device-list"],
                    failureCodes: ["host_command_failed", "target_not_found", "ambiguous_target", "validation_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "use",
                    summary: "Resolve a target selector and save it as the current agent target",
                    requiredOptions: ["<selector>"],
                    optionalOptions: ["--platform", "--scope", "--name", "--runtime", "--state", "--ready", "--hdc", "--adb", "--format", "--json"],
                    outputSelectors: ["host.device-selection"],
                    failureCodes: ["ambiguous_target", "target_not_found", "target_offline", "target_platform_mismatch", "device_not_ready", "validation_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "current",
                    summary: "Show the current agent target",
                    optionalOptions: ["--hdc", "--adb", "--format", "--json"],
                    outputSelectors: ["host.device-selection"],
                    failureCodes: ["target_not_found", "ambiguous_target", "validation_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "resolve",
                    summary: "Resolve a target selector without executing an action",
                    requiredOptions: ["<selector>"],
                    optionalOptions: ["--platform", "--scope", "--name", "--runtime", "--state", "--ready", "--hdc", "--adb", "--format", "--json"],
                    outputSelectors: ["host.device-selection"],
                    failureCodes: ["ambiguous_target", "target_not_found", "target_offline", "target_platform_mismatch", "device_not_ready", "validation_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "wait-ready",
                    summary: "Wait for a target to become ready",
                    requiredOptions: ["<selector>"],
                    optionalOptions: ["--platform", "--name", "--runtime", "--state", "--ready", "--hdc", "--adb", "--timeout", "--interval", "--format", "--json"],
                    outputSelectors: ["host.device-ready"],
                    failureCodes: ["ambiguous_target", "target_not_found", "target_offline", "device_not_ready", "host_command_timeout", "host_command_failed", "validation_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "lease",
                    summary: "Acquire, inspect, release, or take over an opt-in iOS Simulator target lease",
                    requiresServer: true,
                    requiresTarget: true,
                    requiresConfirmation: false,
                    sideEffect: "acquire creates a bounded-TTL lease; release removes the matching lease; takeover with --confirm displaces the current owner; status is read-only",
                    requiredOptions: ["--target"],
                    optionalOptions: ["--owner", "--lease", "--ttl", "--readonly-observation-allowed", "--confirm", "--host", "--port", "--format", "--json"],
                    nextCommands: [
                        "triton target lease status --target <udid> --json",
                        "triton target lease acquire --target <udid> --owner <label> --json",
                        "triton target lease release --target <udid> --lease <lease-id> --json",
                        "triton target lease takeover --target <udid> --owner <label> --confirm --json",
                    ],
                    outputSelectors: ["target.lease"],
                    failureCodes: [
                        "target_lease_conflict",
                        "lease_ttl_out_of_range",
                        "lease_owner_required",
                        "lease_target_required",
                        "server_unavailable",
                        "invalid_payload",
                        "request_failed",
                    ]
                ),
            ],
            providedCapabilities: ["target-list", "target-use", "target-current", "target-resolve", "target-wait-ready", "target-lease"]
        ),
    ]
}
