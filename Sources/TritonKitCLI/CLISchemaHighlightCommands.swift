import Foundation
import TritonKitShared

func highlightCommandSchemas() -> [TKCommandSchema] {
    let common = schemaHostPortOptions + [
        schemaTargetOption,
        TKCommandSchemaOption(name: "--runtime-instance-id", type: "String", description: "Optional expected runtime instance; stale instances are rejected"),
        TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
        schemaJSONAliasOption,
    ]
    let failures = Array(Set(schemaRuntimeTargetFailureCodes + [
        "validation_failed", "highlight_unsupported", "highlight_target_ambiguous", "highlight_target_not_found",
        "highlight_identity_unverifiable", "highlight_identity_changed", "highlight_stale_runtime",
        "highlight_busy", "highlight_operation_conflict", "highlight_capacity_exceeded", "highlight_receipt_expired",
        "highlight_render_timeout", "highlight_restore_conflict", "highlight_restore_failed",
    ])).sorted()
    let semantics = "Highlight is optional and requires a writable provider in the target App. No SDK is required for ordinary inspection or screenshots, and this command never installs a provider. CLI exit does not clear a session; clear or App-side TTL cleanup owns restoration. Request ok, session state, cleanupComplete, restorationVerified, residualState and renderObservation describe separate facts. A render opportunity is not proof of a visible frame."
    let contract = TKCommandOutputContract(selector: "highlight.receipt", format: "json", kind: "envelope", model: "TKHighlightReceipt", fields: [
        TKCommandSchemaField(name: "ok", type: "Bool", required: true, description: "Request result; status ok does not mean restored"),
        TKCommandSchemaField(name: "runtimeInstanceID", type: "String", required: true, description: "App lifetime identity"),
        TKCommandSchemaField(name: "operationID", type: "String?", required: false, description: "Apply idempotency key"),
        TKCommandSchemaField(name: "sessionID", type: "String?", required: false, description: "Owned highlight session"),
        TKCommandSchemaField(name: "state", type: "active|partially_active|restoring|closed|needs_attention?", required: false, description: "Session lifecycle, independent of request ok"),
        TKCommandSchemaField(name: "marks", type: "[TKHighlightMarkReceipt]", required: true, description: "Per mark identity, attribute group, outcome and restoration receipt; original values stay in the provider"),
        TKCommandSchemaField(name: "cleanupComplete", type: "Bool", required: true, description: "Provider has finished its cleanup obligations"),
        TKCommandSchemaField(name: "restorationVerified", type: "Bool", required: true, description: "Original restoration was verified by readback"),
        TKCommandSchemaField(name: "residualState", type: "none|possible|unknown", required: true, description: "Potential highlight residue"),
        TKCommandSchemaField(name: "ownershipAssurance", type: "value_guarded|versioned", required: true, description: "Strength of ownership checks"),
        TKCommandSchemaField(name: "restorationMode", type: "snapshot_compare_restore|managed_override", required: true, description: "Provider restoration semantics"),
        TKCommandSchemaField(name: "renderObservation", type: "String", required: true, description: "Render observation level; does not establish screenshot visibility"),
        TKCommandSchemaField(name: "error", type: "TKHighlightError?", required: false, description: "Stable failure code and reason"),
    ])
    let shape = "{ ok, runtimeInstanceID, operationID?, sessionID?, state?, marks[], cleanupComplete, restorationVerified, residualState, ownershipAssurance, restorationMode, renderObservation, expiresAt?, remainingMs?, error?, errors[] }"
    let failureShape = "One TKHighlightReceipt or { ok:false, error:{ code, message, endpoint? } }; partial cleanup evidence is preserved, never wrapped a second time"
    let capabilityContract = TKCommandOutputContract(selector: "highlight.capabilities", format: "json", kind: "envelope", model: "TKHighlightCapabilitiesResponse", fields: [
        TKCommandSchemaField(name: "ok", type: "Bool", required: true, description: "Capability observation result"),
        TKCommandSchemaField(name: "runtimeInstanceID", type: "String", required: true, description: "App lifetime identity, or unavailable for a legacy unsupported manifest"),
        TKCommandSchemaField(name: "capability", type: "TKHighlightCapability", required: true, description: "Actual target provider support, reason, properties and bounds"),
    ])
    let optionalCommon = common.map(\.name)
    return [TKCommandSchema(
        name: "highlight", summary: "Independent optional App property highlighting",
        requiresServer: true, requiresTarget: true, runtimeScope: "optional writable App provider", exitCodeOnFailure: 1,
        outputFormats: schemaTextJSONFormats,
        options: common + [
            TKCommandSchemaOption(name: "apply", type: "Subcommand", description: "Locate nodes, save typed original properties, apply an outline"),
            TKCommandSchemaOption(name: "status", type: "Subcommand", description: "Read session or operation receipt without renewing TTL"),
            TKCommandSchemaOption(name: "clear", type: "Subcommand", description: "Conditionally restore all or selected marks owned by one session"),
            TKCommandSchemaOption(name: "capabilities", type: "Subcommand", description: "Read optional target provider support, limits and runtime identity"),
            TKCommandSchemaOption(name: "--spec", type: "JSON|Path|@Path", description: "Apply spec {schemaVersion:1,preset:outline,color:#RRGGBB,width,items:[{markID,label?,selector:{oid|identifier,withinOID?}}]}; 1–10 unique markIDs, maximum 65536 bytes; omitted style fields use defaults. P0 UIKit supports oid or identifier with optional withinOID; text and role are reserved shared fields and this provider returns highlight_unsupported"),
            TKCommandSchemaOption(name: "--ttl", type: "Int", defaultValue: "30", description: "App-side lifetime in seconds, 1–300; no permanent session or automatic renewal"),
            TKCommandSchemaOption(name: "--operation-id", type: "String", description: "Optional apply idempotency key; generated if omitted; reuse only with the same runtime and payload"),
            TKCommandSchemaOption(name: "--session", type: "String", description: "Explicit session id for clear, or status instead of --operation"),
            TKCommandSchemaOption(name: "--operation", type: "String", description: "Status apply operation id instead of --session; useful when an apply response was lost"),
            TKCommandSchemaOption(name: "--mark", type: "String", description: "Repeat for clear to select a mark subset; omitted means all marks in this session"),
        ],
        usageForms: [
            TKCommandUsageForm(form: "triton highlight apply --target <target> --spec highlights.json --ttl 30 --operation-id <operation-id> --json", kind: "Subcommand", description: "Independently apply a bounded optional highlight"),
            TKCommandUsageForm(form: "triton highlight status --session <session-id> --json", kind: "Subcommand", description: "Observe an existing session without renewing TTL"),
            TKCommandUsageForm(form: "triton highlight status --operation <operation-id> --json", kind: "Subcommand", description: "Recover the original apply receipt"),
            TKCommandUsageForm(form: "triton highlight clear --session <session-id> --mark <mark-id> --json", kind: "Subcommand", description: "Conditionally restore selected owned attributes"),
            TKCommandUsageForm(form: "triton highlight capabilities --target <target> --json", kind: "Subcommand", description: "Read target-specific optional support without writing properties"),
        ],
        examples: [
            "triton highlight apply --target <target> --spec @highlights.json --ttl 30 --operation-id op-123 --json",
            "triton highlight status --operation op-123 --json",
            "triton highlight clear --session <session-id> --mark primary --mark secondary --json",
            "triton highlight capabilities --target <target> --json",
        ],
        successShape: shape + "; capabilities emits {ok,runtimeInstanceID,capability:{supported,reason?,provider?,presets[],restorationModes[],nodeKinds[],limits,renderObservation},error?}",
        failureShape: failureShape,
        outputSemantics: semantics + " Apply first reads the existing runtime manifest to detect legacy unsupported providers, then binds the runtime instance before writing. Same physical layer is deduplicated. No force restore or nested session. P0 UIKit selectors support only oid or identifier with optional withinOID; shared text/role fields are reserved and unsupported by this provider. Status can observe needs_attention with ok=true. Clear stays available when new highlights are disabled. Business property changes are preserved and reported as highlight_restore_conflict with nonzero exit. Node disappearance is not verified restoration. Capabilities observation with supported=false has exit code zero.",
        outputContracts: [contract, capabilityContract], failureCodes: failures,
        subcommands: [
            TKCommandSubcommandSchema(name: "apply", summary: "Save originals and apply a bounded outline", requiresServer: true, requiresTarget: true, sideEffect: "temporary_app_attributes", requiredOptions: ["--spec"], optionalOptions: optionalCommon + ["--ttl", "--operation-id"], nextCommands: ["triton highlight status --operation <operation-id> --json", "triton highlight clear --session <session-id> --json"], outputSelectors: ["highlight.receipt"], failureCodes: failures),
            TKCommandSubcommandSchema(name: "status", summary: "Read a session or operation receipt without renewing TTL", requiresServer: true, requiresTarget: true, oneOfRequiredOptions: [["--session", "--operation"]], optionalOptions: optionalCommon, outputSelectors: ["highlight.receipt"], failureCodes: failures),
            TKCommandSubcommandSchema(name: "clear", summary: "Conditionally restore owned attributes; conflicts exit nonzero", requiresServer: true, requiresTarget: true, sideEffect: "restore_owned_app_attributes", requiredOptions: ["--session"], optionalOptions: optionalCommon + ["--mark"], outputSelectors: ["highlight.receipt"], failureCodes: failures),
            TKCommandSubcommandSchema(name: "capabilities", summary: "Probe optional provider support and limits", requiresServer: true, requiresTarget: true, optionalOptions: optionalCommon, outputSelectors: ["highlight.capabilities"], failureCodes: failures),
        ], providedCapabilities: ["highlight"]
    )]
}
