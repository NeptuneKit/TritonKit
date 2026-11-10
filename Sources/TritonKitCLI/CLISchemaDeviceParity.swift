import TritonKitShared

func hostDeviceStopOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-stop", format: "json", kind: "host-action", model: "HostDeviceStopOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Whether the stop command sequence completed; target absence/offline still needs a separate check"),
        ("action", "String", true, "device.stop"),
        ("platform", "String", true, "android or harmony"),
        ("target", "String?", false, "Resolved Android emulator target id; omitted for Harmony HVD stop"),
        ("adb", "String?", false, "Android ADB executable; omitted for Harmony"),
        ("hvd", "String?", false, "Harmony HVD name; omitted for Android"),
        ("deployedPath", "String?", false, "Harmony deployed emulator path; omitted for Android"),
        ("emulator", "String?", false, "Harmony Emulator executable; omitted for Android"),
        ("launchdLabel", "String?", false, "Harmony launchd job label; omitted for Android or --skip-launchd"),
        ("launchdDomain", "String?", false, "Harmony launchd domain; omitted for Android or --skip-launchd"),
        ("sourceCommands", "[String]", true, "Host command ledger; may include skipped bootout when the launchd job was absent"),
        ("warnings", "[String]", true, "Stop warnings, including an absent Harmony launchd job"),
        ("note", "String", true, "Completion note and independent target-state verification reminder"),
    ]))
}

func deviceEnvironmentOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "device.environment", format: "json", kind: "host-action", model: "DeviceEnvironmentOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Whether the host environment operation completed"),
        ("action", "String", true, "device orientation, fold, location, clipboard, or foreground action"),
        ("target", "HostDeviceTarget", true, "Exact target bound before execution"),
        ("source", "String", true, "simctl, adb, or hdc"),
        ("supported", "Bool", true, "Whether the selected platform exposes this operation"),
        ("executed", "Bool", true, "Whether a mutation was submitted"),
        ("verified", "Bool", true, "Whether the requested host state was read back"),
        ("previous", "[String:String]?", false, "Bounded before state"),
        ("requested", "[String:String]?", false, "Requested state"),
        ("observed", "[String:String]?", false, "Bounded after state; Android foreground uses resumed-activity identity, never window-focus fallback"),
        ("observed.bundleIdentifier", "String?", false, "Foreground bundle identity, or unknown when no trustworthy resumed ActivityRecord exists"),
        ("observed.identityState", "String?", false, "current or unknown for Android foreground; does not establish business readiness"),
        ("observed.scope", "String?", false, "Android foreground identity source: resumed-activity"),
        ("observed.activity", "String?", false, "Android foreground activity class from a trustworthy resumed ActivityRecord; omitted when unknown"),
        ("observed.component", "String?", false, "Android foreground package/activity component from a trustworthy resumed ActivityRecord; omitted when unknown"),
        ("sourceCommands", "[String]", true, "Redacted host command ledger"),
        ("businessReadinessVerified", "Bool", true, "Always false for environment controls"),
    ]))
}

func deviceActionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "device.action", format: "json", kind: "host-action", model: "DeviceActionOutput", fields: schemaContractFields([
        ("action", "String", true, "tap, double-tap, swipe, press, or type"),
        ("ok", "Bool", true, "Whether the host action command was accepted"),
        ("target", "String", true, "Exact target identity"),
        ("sourceCommand", "String", true, "Redacted argv-bound host command"),
        ("postconditionVerified", "Bool", true, "Business postcondition is never inferred from host input"),
    ]))
}
