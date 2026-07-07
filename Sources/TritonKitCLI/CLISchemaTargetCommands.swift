import Foundation
import TritonKitShared

func targetCommandSchemas() -> [TKCommandSchema] {
    let jsonText = schemaTextJSONFormats
    let jsonAlias = schemaJSONAliasOption
    let hostPort = schemaHostPortOptions

    return [
        TKCommandSchema(
            name: "target",
            summary: "Discover, resolve, and track the current agent target",
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
                TKCommandSchemaOption(name: "--platform", type: "ios|android|harmony", defaultValue: "harmony", description: "Host target platform"),
                TKCommandSchemaOption(name: "--scope", type: "simulator|emulator|real|all", description: "Host target scope filter for resolve"),
                TKCommandSchemaOption(name: "--name", type: "String", description: "Device name filter, for example iPhone 15"),
                TKCommandSchemaOption(name: "--runtime", type: "String", description: "Runtime filter, for example iOS 26.5"),
                TKCommandSchemaOption(name: "--state", type: "String", description: "Target state filter, for example booted or connected"),
                TKCommandSchemaOption(name: "--ready", type: "Bool", defaultValue: "false", description: "Only match ready targets"),
                TKCommandSchemaOption(name: "--hdc", type: "Path", defaultValue: "hdc", description: "HDC executable path"),
                TKCommandSchemaOption(name: "--adb", type: "Path", defaultValue: "adb", description: "ADB executable path"),
                TKCommandSchemaOption(name: "--timeout", type: "Double", defaultValue: "30", description: "Bounded wait timeout in seconds"),
                TKCommandSchemaOption(name: "--interval", type: "Double", defaultValue: "1", description: "Readiness poll interval in seconds"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton target list --platform ios --json",
                "triton target use booted --platform ios --json",
                "triton target current --json",
                "triton target resolve booted --platform ios --scope simulator --json",
                "triton target resolve --platform harmony --name 'Codex Test Phone' --ready --json",
                "triton target wait-ready harmony-a --platform harmony --json",
            ],
            successShape: "{ ok, platform, targets[]?, defaultTarget?, target?, defaultsPath?, current?, selection?, path?, ready?, attempt?, sourceCommand? }",
            failureShape: "{ ok:false, error:{ code: ambiguous_target|target_not_found|target_offline|target_platform_mismatch|device_not_ready|host_command_timeout|host_command_failed, message, hint } }",
            outputSemantics: "Use target as the agent-facing target discovery, selection, and readiness fact source. It is the preferred entry before app, runtime, observe, action, assert, evidence, or replay flows.",
            nextCommands: [
                "triton target resolve <selector> --json",
                "triton target use <selector> --json",
                "triton target wait-ready <selector> --json",
                "triton app open-url <url> --device <selector> --wait-ready --snapshot --json",
            ],
            outputContracts: [
                hostDeviceListOutputContract(),
                hostDeviceSelectionOutputContract(),
                hostDeviceReadyOutputContract(),
            ],
            failureCodes: [
                "ambiguous_target",
                "target_not_found",
                "target_offline",
                "target_platform_mismatch",
                "device_not_ready",
                "host_command_timeout",
                "host_command_failed",
                "validation_failed",
            ],
            providedCapabilities: ["target-list", "target-use", "target-current", "target-resolve", "target-wait-ready"]
        ),
    ]
}
