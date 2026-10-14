import Foundation
import TritonKitShared

func deviceDiagnosticsSubcommandSchemas() -> [TKCommandSubcommandSchema] {
    let options = [
        TKCommandSchemaOption(name: "--device", type: "String", description: "Exact target selector"),
        TKCommandSchemaOption(name: "--platform", type: "ios|android|harmony", description: "Platform adapter"),
        TKCommandSchemaOption(name: "--scope", type: "simulator|emulator|real", description: "Target scope"),
        TKCommandSchemaOption(name: "--timeout", type: "Double", defaultValue: "10", description: "Bounded query timeout seconds"),
        TKCommandSchemaOption(name: "--maximum-bytes", type: "Int", defaultValue: "1048576", description: "Local accepted body budget, not remote transport hard limit"),
        TKCommandSchemaOption(name: "--maximum-entries", type: "Int", defaultValue: "1000", description: "Reject instead of truncating report metadata"),
    ]
    return [
        TKCommandSubcommandSchema(name: "logs", summary: "Bounded readonly system log sample; source and partial are explicit", optionOverrides: options + [TKCommandSchemaOption(name: "--last-seconds", type: "Int", defaultValue: "60", description: "Simulator unified-log window"), TKCommandSchemaOption(name: "--idevicesyslog", type: "Path", defaultValue: "idevicesyslog", description: "Optional libimobiledevice source for physical iOS live logs")], artifacts: ["owner-only private device.log"], outputSelectors: ["source", "sourceCommands", "bytes", "partial", "limitations", "artifacts"], failureCodes: ["device_diagnostics_invalid_request", "device_diagnostics_unavailable", "device_diagnostics_timeout", "device_diagnostics_artifact_unsafe"]),
        TKCommandSubcommandSchema(name: "crashes", summary: "Target-bound crash list/get with metadata/body distinction", failureCodes: ["device_diagnostics_invalid_request", "device_crash_list_failed"], subcommands: [
            TKCommandSubcommandSchema(name: "list", summary: "List metadata only", optionOverrides: options, artifacts: ["private CoreDevice JSON or no artifact"], outputSelectors: ["entries", "partial", "source"], failureCodes: ["device_crash_list_failed", "device_crash_partial", "device_diagnostics_invalid_request"]),
            TKCommandSubcommandSchema(name: "get", summary: "Fetch one body after fresh target-bound list", optionOverrides: options + [TKCommandSchemaOption(name: "<name>", type: "Argument", description: "Exact listed report name")], artifacts: ["owner-only private crash.txt"], outputSelectors: ["content", "bytes", "partial", "artifacts"], failureCodes: ["device_crash_not_found", "device_crash_receipt_invalid", "device_diagnostics_artifact_unsafe"]),
        ]),
    ]
}

func deviceDiagnosticsOutputContracts() -> [TKCommandOutputContract] {
    [TKCommandOutputContract(selector: "device.diagnostics", format: "json", kind: "envelope", model: "DeviceDiagnosticsOutput", fields: [
        TKCommandSchemaField(name: "ok", type: "Bool", required: true, description: "Whether the bounded query completed"),
        TKCommandSchemaField(name: "action", type: "String", required: true, description: "logs or crashes operation"),
        TKCommandSchemaField(name: "target", type: "HostDeviceTarget", required: true, description: "Resolved target identity"),
        TKCommandSchemaField(name: "source", type: "String", required: true, description: "Native source adapter"),
        TKCommandSchemaField(name: "sourceCommands", type: "[String]", required: true, description: "Redacted source command ledger"),
        TKCommandSchemaField(name: "artifacts", type: "[String]", required: true, description: "Private owner-only artifact paths"),
        TKCommandSchemaField(name: "bytes", type: "Int", required: true, description: "Accepted artifact bytes"),
        TKCommandSchemaField(name: "partial", type: "Bool", required: true, description: "Whether the source was partial"),
        TKCommandSchemaField(name: "limitations", type: "[String]", required: true, description: "Explicit source limits")
    ])]
}
func deviceDiagnosticsFailureCodes() -> [String] { ["device_diagnostics_invalid_request", "device_diagnostics_unavailable", "device_diagnostics_timeout", "device_diagnostics_artifact_unsafe", "device_crash_list_failed", "device_crash_not_found", "device_crash_receipt_invalid", "app_archive_unsafe", "app_archive_budget_exceeded", "app_archive_extraction_failed", "app_archive_ambiguous", "app_archive_platform_mismatch"] }
