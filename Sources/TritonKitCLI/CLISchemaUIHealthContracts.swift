import Foundation
import TritonKitShared

func runtimeUIHealthOutputContract() -> TKCommandOutputContract {
    .init(selector: "debug.ui-health", format: "json", kind: "runtime-ui-health", model: "RuntimeUIHealthOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Whether ping responded; not UI readiness or business success"),
        ("action", "String", true, "debug.ui-health"),
        ("target", "String", true, "Resolved runtime identity"),
        ("pong", "Bool", true, "Runtime process response"),
        ("timestamp", "TimeInterval", true, "Runtime ping timestamp"),
        ("uiState", "String", true, "ready, busy, timed_out, circuit_open; unknown when legacy runtime omits health"),
        ("allowsUIRequests", "Bool?", false, "Admission only; absent for legacy runtime"),
        ("uiHealth", "TKRuntimeUIHealthSnapshot?", false, "Inflight timeout and circuit facts independent of UI thread"),
        ("businessVerified", "Bool", true, "Always false"),
    ]))
}
