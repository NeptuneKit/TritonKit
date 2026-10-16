import Foundation
import TritonKitShared

let selectionFailureCodes = ["validation_failed", "selection_missing", "selection_stale", "selection_revision_mismatch", "selection_identity_unverifiable", "selection_unsupported"]
let selectionRequestFailureCodes = selectionFailureCodes + ["runtime_ui_busy", "runtime_ui_timeout", "runtime_ui_circuit_open"]

func selectionGuardSchemaOptions() -> [TKCommandSchemaOption] {
    [
        TKCommandSchemaOption(name: "--selection", type: "String", description: "Floating picker selection id; requires --selection-revision and --runtime-instance-id. Embedded input only; excludes other target selectors, host, WebView and fallback options"),
        TKCommandSchemaOption(name: "--selection-revision", type: "UInt64", description: "Positive selection revision from inspect selection; stale revisions reject without coordinate fallback"),
        TKCommandSchemaOption(name: "--runtime-instance-id", type: "String", description: "Exact process identity from inspect selection; required with --selection"),
    ]
}

func selectionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "inspect.selection", format: "json", kind: "floating-selection", model: "TKSelectionResponse", fields: schemaContractFields([
        ("ok", "Bool", true, "Whether the selection request succeeded"),
        ("schemaVersion", "Int", true, "Selection schema version, currently 1"),
        ("runtimeInstanceID", "String", true, "Process identity required for guarded input"),
        ("revision", "UInt64", true, "Selection store revision"),
        ("state", "String", true, "Selection state, or available/unsupported for capabilities"),
        ("selection", "TKSelectionSnapshot?", false, "Current selection, absent after clear or before a pick"),
        ("selection.id", "String?", false, "Opaque selection id"),
        ("selection.revision", "UInt64?", false, "Revision required by guarded input"),
        ("selection.selectedAt", "Double?", false, "Selection creation timestamp"),
        ("selection.expiresAt", "Double?", false, "Selection expiry timestamp"),
        ("selection.sceneID", "String?", false, "Scene identity"),
        ("selection.windowID", "UInt?", false, "Window identity"),
        ("selection.rawHitOID", "UInt?", false, "Original hit view identity"),
        ("selection.target", "TKAXNode?", false, "Selected control description"),
        ("selection.validity", "String?", false, "Current selection validity"),
        ("selection.invalidReason", "String?", false, "Reason when invalid"),
        ("selection.supportedActions", "[String]?", false, "Actions supported for this selection"),
        ("selection.resolutionReason", "String?", false, "How the hit became the selected target"),
        ("selection.coordinateSpace", "String?", false, "window-points; never an automatic fallback target"),
        ("outcome", "String?", false, "not_started or unknown for UI admission failures; unknown forbids automatic replay"),
        ("uiHealth", "TKRuntimeUIHealthSnapshot?", false, "UI request admission diagnostics"),
        ("error", "TKSelectionError?", false, "Typed selection failure"),
        ("error.code", "String?", false, "Stable error code"),
        ("error.message", "String?", false, "Human-readable error"),
    ]))
}

func selectionSubcommandSchemas() -> [TKCommandSubcommandSchema] {
    [
        ("selection", "Read and revalidate the current floating picker selection"),
        ("clear", "Clear the selection and advance its revision; does not tap controls"),
        ("capabilities", "Probe whether the explicitly enabled SDK floating picker is available"),
    ].map { name, summary in
        TKCommandSubcommandSchema(name: name, summary: summary, optionalOptions: ["--target", "--host", "--port", "--runtime-instance-id", "--format", "--json"], outputSelectors: ["inspect.selection"], failureCodes: selectionRequestFailureCodes + ["server_unavailable", "target_not_found", "ambiguous_target", "request_failed"])
    }
}
