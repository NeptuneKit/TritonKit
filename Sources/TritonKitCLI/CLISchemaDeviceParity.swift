import TritonKitShared

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
        ("observed", "[String:String]?", false, "Bounded after state"),
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
