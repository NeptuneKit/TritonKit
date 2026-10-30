import Foundation
import TritonKitShared

let emulatorResourceFailureCodes = [
    "resource_busy",
    "resource_command_failed",
    "resource_confirmation_required",
    "resource_control_permission_unverified",
    "resource_failed",
    "resource_identity_mismatch",
    "resource_identity_unavailable",
    "resource_invalid_action",
    "resource_invalid_feature",
    "resource_invalid_identity",
    "resource_invalid_item",
    "resource_invalid_output",
    "resource_invalid_profile",
    "resource_invalid_receipt",
    "resource_invalid_state",
    "resource_invalid_target",
    "resource_lock_failed",
    "resource_memory_invalid_output",
    "resource_output_invalid",
    "resource_output_truncated",
    "resource_permission_denied",
    "resource_receipt_exists",
    "resource_receipt_write_failed",
    "resource_state_conflict",
    "resource_state_mismatch",
    "resource_state_unavailable",
    "resource_target_not_ready",
    "resource_unsupported_control",
    "resource_verification_failed",
    "resource_write_unconfirmed",
]

func emulatorResourceSubcommandSchema() -> TKCommandSubcommandSchema {
    let common = [
        TKCommandSchemaOption(name: "--platform", type: "android|harmony", required: true, description: "Local emulator platform; physical and remote devices are excluded"),
        TKCommandSchemaOption(name: "--adb", type: "Path", defaultValue: "adb", description: "ADB executable"),
        TKCommandSchemaOption(name: "--hdc", type: "Path", defaultValue: "hdc", description: "HDC executable"),
        TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --format json"),
        TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
    ]
    let target = TKCommandSchemaOption(name: "--device", type: "String", required: true, description: "Exact Android emulator serial or Harmony loopback endpoint; platform identity is also verified")
    let selection = [
        TKCommandSchemaOption(name: "--profile", type: "stock|ui-minimal|custom", defaultValue: "ui-minimal", description: "Base set of optional features to disable"),
        TKCommandSchemaOption(name: "--disable", type: "CommaSeparatedFeatureIDs", description: "Additional allowlisted features to disable"),
        TKCommandSchemaOption(name: "--keep", type: "CommaSeparatedFeatureIDs", description: "Features to preserve"),
    ]
    let receipt = TKCommandSchemaOption(name: "--receipt", type: "Path", required: true, description: "Private recovery receipt; apply creates a new file, verify/restore read an existing file")
    let confirm = TKCommandSchemaOption(name: "--confirm", type: "Bool", defaultValue: "false", description: "Explicit confirmation required before mutation")
    let actions = [
        ("profiles", "List available resource profiles"),
        ("features", "List feature switches, functional impact and profile membership"),
        ("status", "Read current feature states"),
        ("doctor", "Check target identity, supported controls and permission limits"),
        ("plan", "Preview disable operations without mutations"),
        ("apply", "Apply confirmed allowlisted operations with a durable recovery receipt"),
        ("verify", "Compare current feature states with a receipt; does not establish application correctness or host savings"),
        ("restore", "Restore receipt-owned states while preserving later user changes"),
        ("measure", "Measure candidate guest process PSS separately from host memory"),
    ]
    let children = actions.map { name, summary in
        let needsTarget = !["profiles", "features"].contains(name)
        let selects = ["plan", "apply"].contains(name)
        let needsReceipt = ["apply", "verify", "restore"].contains(name)
        let mutates = ["apply", "restore"].contains(name)
        return TKCommandSubcommandSchema(
            name: name, summary: summary, requiresTarget: needsTarget, requiresConfirmation: mutates,
            sideEffect: mutates ? "device-state-and-local-receipt" : "none",
            optionOverrides: common + (needsTarget ? [target] : []) + (selects ? selection : []) + (needsReceipt ? [receipt] : []) + (mutates ? [confirm] : []),
            requiredOptions: ["--platform"] + (needsTarget ? ["--device"] : []) + (needsReceipt ? ["--receipt"] : []),
            optionalOptions: ["--adb", "--hdc", "--json", "--format"] + (selects ? ["--profile", "--disable", "--keep"] : []) + (mutates ? ["--confirm"] : []),
            artifacts: mutates ? ["private resource recovery receipt"] : [],
            retryable: false, outputSelectors: ["device.resource"], failureCodes: emulatorResourceFailureCodes
        )
    }
    return TKCommandSubcommandSchema(name: "resource", summary: "Manage optional Android and Harmony emulator features with identity checks, preview and recovery", outputSelectors: ["device.resource"], failureCodes: emulatorResourceFailureCodes, subcommands: children)
}

func emulatorResourceOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "device.resource", format: "json", kind: "envelope", model: "EmulatorResourceOutput", fields: [
        TKCommandSchemaField(name: "ok", type: "Bool", required: true, description: "Whether the requested operation completed and verified"),
        TKCommandSchemaField(name: "action", type: "String", required: true, description: "Resource action"),
        TKCommandSchemaField(name: "platform", type: "android|harmony", required: true, description: "Local emulator platform"),
        TKCommandSchemaField(name: "identity", type: "EmulatorResourceIdentity", required: false, description: "Verified target, instance, image and boot identity"),
        TKCommandSchemaField(name: "features", type: "[EmulatorResourceFeature]", required: false, description: "Allowlisted optional features and their effects"),
        TKCommandSchemaField(name: "profiles", type: "[String]", required: false, description: "Available profile IDs"),
        TKCommandSchemaField(name: "states", type: "[EmulatorResourceState]", required: false, description: "Observed states with availability and failure reasons"),
        TKCommandSchemaField(name: "receipt", type: "EmulatorResourceReceipt", required: false, description: "Durable ownership and recovery record"),
        TKCommandSchemaField(name: "partial", type: "Bool", required: true, description: "Incomplete observation, mutation or restoration"),
        TKCommandSchemaField(name: "error", type: "EmulatorResourceFailure", required: false, description: "Stable resource failure code and explanation"),
        TKCommandSchemaField(name: "memory", type: "EmulatorResourceGuestMemory", required: false, description: "Guest process PSS in bytes; not a host memory saving claim"),
        TKCommandSchemaField(name: "hostMemory", type: "EmulatorResourceHostMemory", required: false, description: "Verified VM main-process physical footprint only, excluding child processes; pid and physicalFootprintBytes may be absent when partial=true, with reason explaining the limit"),
        TKCommandSchemaField(name: "businessVerified", type: "Bool", required: true, description: "Always false: feature-state checks do not verify application behavior"),
        TKCommandSchemaField(name: "hostSavingsVerified", type: "Bool", required: true, description: "Always false: guest memory observations do not establish host savings"),
    ])
}
