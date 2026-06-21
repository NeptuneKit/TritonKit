import Foundation
import TritonKitShared

func debugCommandSchemas() -> [TKCommandSchema] {
    let jsonText = schemaTextJSONFormats
    let hostPort = schemaHostPortOptions
    let target = schemaTargetDeviceAliasOption
    let runtimeBaseURLOption = schemaRuntimeBaseURLOption
    let jsonAlias = schemaJSONAliasOption
    let languageOption = schemaLanguageOption

    return [
        TKCommandSchema(
            name: "debug",
            summary: "Explicit raw engine and runtime inspection surface for low-level diagnostics",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded|host-adapter",
            outputFormats: jsonText + ["jsonl"],
            options: hostPort + [
                target,
                runtimeBaseURLOption,
                TKCommandSchemaOption(name: "--platform", type: "ios|android|harmony", description: "Platform selector for delegated raw inspection commands"),
                TKCommandSchemaOption(name: "--include", type: "CSV", description: "Snapshot sections when delegated to debug snapshot"),
                TKCommandSchemaOption(name: "--max-ax-nodes", type: "Int", description: "AX node limit when delegated to debug snapshot"),
                TKCommandSchemaOption(name: "--limit", type: "Int", description: "Ledger entry limit when delegated to debug ledger"),
                TKCommandSchemaOption(name: "--jsonl", type: "Bool", defaultValue: "false", description: "Emit JSON Lines when delegated to debug ledger"),
                TKCommandSchemaOption(name: "--oid", type: "UInt", description: "Runtime object identifier for node, attrs, object, geometry, or ax lookup"),
                TKCommandSchemaOption(name: "--id", type: "UInt", description: "Alias for --oid on object-level inspection commands"),
                TKCommandSchemaOption(name: "--bounds", type: "Bool", defaultValue: "false", description: "Include bounds when delegated to debug hierarchy"),
                TKCommandSchemaOption(name: "--all", type: "Bool", defaultValue: "false", description: "Include all matching candidates where supported"),
                TKCommandSchemaOption(name: "--x", type: "Double", description: "Window x coordinate for hit-test"),
                TKCommandSchemaOption(name: "--y", type: "Double", description: "Window y coordinate for hit-test"),
                TKCommandSchemaOption(name: "--width", type: "Double", description: "Optional window width for hit-test"),
                TKCommandSchemaOption(name: "--height", type: "Double", description: "Optional window height for hit-test"),
                TKCommandSchemaOption(name: "--duration", type: "Double", description: "Optional hit-test interaction duration"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                languageOption,
            ],
            usageForms: [
                TKCommandUsageForm(form: "runtime manifest --json", kind: "Subcommand", description: "Read embedded runtime manifest through the explicit debug surface"),
                TKCommandUsageForm(form: "hierarchy --json", kind: "Subcommand", description: "Read raw hierarchy through the explicit debug surface"),
                TKCommandUsageForm(form: "ledger --limit 50 --json", kind: "Subcommand", description: "Read raw runtime ledger through the explicit debug surface"),
            ],
            examples: [
                "triton debug runtime manifest --json",
                "triton debug hierarchy --json",
                "triton debug ledger --limit 50 --json",
            ],
            successShape: "Delegates to the selected raw engine or runtime inspection command output contract",
            failureShape: "{ ok:false, error:{ code: validation_failed|server_unavailable|target_unavailable|runtime_unavailable|request_failed|hierarchy_unavailable|node_not_found, message, endpoint?, hint?, nextAction?{ command,args,category,requiresLongRunningProcess?,readyEvents,finalEvents,terminationSignals } } }",
            outputSemantics: "Use debug only when workflow commands such as observe, act, verify, or evidence are too high-level. Retired raw root commands are available through this explicit debug surface.",
            nextCommands: [
                "triton observe current --json",
                "triton schema --command debug --json",
                "triton doctor --json",
            ],
            outputContracts: [
                runtimeManifestOutputContract(),
                runtimeStateOutputContract(),
                runtimeSnapshotOutputContract(),
                hierarchyInfoOutputContract(),
                hierarchySceneOutputContract(),
                hierarchyNodesOutputContract(),
                hierarchyNodeOutputContract(),
                nodeResolveOutputContract(),
                nodeAttributesOutputContract(),
                nodeObjectOutputContract(),
                geometryCurrentOutputContract(),
                hitResultOutputContract(),
                axOutputContract(),
                runtimeLedgerOutputContract(),
                runtimeLedgerEntryOutputContract(),
            ],
            failureCodes: [
                "validation_failed",
                "server_unavailable",
                "target_unavailable",
                "runtime_unavailable",
                "runtime_ui_interrupted",
                "request_timeout",
                "invalid_payload",
                "request_failed",
                "hierarchy_unavailable",
                "node_not_found",
            ],
            subcommands: [
                TKCommandSubcommandSchema(name: "runtime", summary: "Read embedded runtime manifest", optionalOptions: ["--target", "--device", "--host", "--port", "--runtime-base-url", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "runtime_unavailable", "request_failed"]),
                TKCommandSubcommandSchema(name: "state", summary: "Read raw app, scene, route, or responder state", optionalOptions: ["--target", "--device", "--host", "--port", "--runtime-base-url", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "runtime_unavailable", "request_failed"]),
                TKCommandSubcommandSchema(name: "snapshot", summary: "Read raw aggregated runtime snapshot", optionalOptions: ["--target", "--device", "--host", "--port", "--runtime-base-url", "--include", "--max-ax-nodes", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "runtime_unavailable", "request_failed", "validation_failed"]),
                TKCommandSubcommandSchema(name: "hierarchy", summary: "Read raw hierarchy tree", optionalOptions: ["--target", "--device", "--host", "--port", "--bounds", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "hierarchy_unavailable", "request_failed"]),
                TKCommandSubcommandSchema(name: "nodes", summary: "Read raw hierarchy nodes", optionalOptions: ["--target", "--device", "--host", "--port", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "hierarchy_unavailable", "request_failed"]),
                TKCommandSubcommandSchema(name: "node", summary: "Read one raw hierarchy node", optionalOptions: ["--target", "--device", "--host", "--port", "--oid", "--id", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "node_not_found", "request_failed", "validation_failed"]),
                TKCommandSubcommandSchema(name: "attrs", summary: "Read raw object attributes", optionalOptions: ["--target", "--device", "--host", "--port", "--oid", "--id", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "node_not_found", "request_failed", "validation_failed"]),
                TKCommandSubcommandSchema(name: "object", summary: "Read raw object metadata", optionalOptions: ["--target", "--device", "--host", "--port", "--oid", "--id", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "node_not_found", "request_failed", "validation_failed"]),
                TKCommandSubcommandSchema(name: "geometry", summary: "Read raw runtime geometry facts", optionalOptions: ["--target", "--device", "--host", "--port", "--runtime-base-url", "--oid", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "runtime_unavailable", "request_failed", "validation_failed"]),
                TKCommandSubcommandSchema(name: "ax", summary: "Read raw accessibility tree facts", optionalOptions: ["--target", "--device", "--host", "--port", "--runtime-base-url", "--oid", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "runtime_unavailable", "request_failed", "validation_failed"]),
                TKCommandSubcommandSchema(name: "hit", summary: "Hit-test one raw window coordinate", optionalOptions: ["--target", "--device", "--host", "--port", "--x", "--y", "--width", "--height", "--duration", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "request_failed", "validation_failed"]),
                TKCommandSubcommandSchema(name: "ledger", summary: "Read raw runtime request and action ledger", optionalOptions: ["--target", "--device", "--host", "--port", "--runtime-base-url", "--limit", "--jsonl", "--format", "--json", "--language", "--lang"], failureCodes: ["server_unavailable", "target_unavailable", "runtime_unavailable", "request_failed", "validation_failed"]),
            ]
        ),
    ]
}
