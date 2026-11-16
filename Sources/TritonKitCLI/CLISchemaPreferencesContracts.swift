import Foundation
import TritonKitShared

func hostPreferenceRemoveOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.app-prefs-remove", format: "json", kind: "host-action", model: "HostPreferencesRemoveOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Disk removal verified and requested relaunch completed"),
        ("action", "String", true, "app.prefs.remove"),
        ("simulatorUDID", "String", true, "Resolved simulator UUID"),
        ("bundleID", "String", true, "Explicit bundle app-data domain"),
        ("key", "String", true, "One literal preference key"),
        ("existed", "Bool", true, "Whether the key existed before this operation"),
        ("removed", "Bool", true, "Whether an existing key was removed"),
        ("present", "Bool", true, "Always false after verified disk removal"),
        ("diskWriteVerified", "Bool", true, "Disk absence and preservation of unrelated values verified; absent key/file is no-write"),
        ("preferenceDomainVerified", "Bool", true, "Selected Simulator app-container preferences domain reports the key absent"),
        ("runtimeConsumptionVerified", "Bool", true, "Always false; launch is not business consumption proof"),
        ("relaunch", "HostPreferencesRelaunchReceipt", true, "Independent requested/status/runtimeConsumptionVerified facts"),
        ("error", "HostPreferencesDeliveryError?", false, "Relaunch failure preserves disk postcondition facts"),
    ]))
}
