import TritonKitShared

func hostApplePlatformControlOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.apple-platform-control", format: "json", kind: "host-action", model: "HostApplePlatformControlOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "The control contract was evaluated; true does not mean an input event was delivered"),
        ("action", "String", true, "device.platform-control"),
        ("platform", "HostApplePlatformControlPlatform", true, "watchOS, tvOS, visionOS or macOS family selector"),
        ("control", "HostApplePlatformControlAction", true, "Narrow public XCTest vocabulary or explicit unsupported action"),
        ("crownDelta", "Double?", false, "Finite non-zero watchOS Crown delta; omitted for other controls"),
        ("capabilityState", "String", true, "fixture-only for public XCTest vocabulary; unsupported when no verified backend exists"),
        ("executable", "Bool", true, "Always false until a Triton runner and target binding are integrated"),
        ("actionsExecuted", "Bool", true, "Always false; this command never reads or changes a device"),
        ("backend", "String?", false, "Public XCTest fixture label only; no raw command or target identity"),
        ("backendKind", "String", true, "public-xctest-api or none"),
        ("sourceAPI", "String?", false, "Public symbol recorded as a contract hint, not proof of execution"),
        ("verification", "String", true, "Fixture-only or unsupported boundary"),
        ("limitations", "[String]", true, "No runner, target binding, event delivery, focus proof or business completion claim")
    ]))
}
