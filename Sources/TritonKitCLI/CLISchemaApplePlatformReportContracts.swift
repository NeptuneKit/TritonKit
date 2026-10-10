import TritonKitShared

func hostApplePlatformReportOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.apple-platform-report", format: "json", kind: "host-action", model: "HostApplePlatformReport", fields: schemaContractFields([
        ("ok", "Bool", true, "Catalog/optional readonly metadata report produced, not host SDK/action/business support"),
        ("action", "String", true, "device.platforms"),
        ("runtimeScope", "String", true, "host-device; standalone no server/Run"),
        ("riskLevel", "String", true, "readonly; default zero host queries; opt-in metadata service/cache effects possible"),
        ("profiles", "[HostApplePlatformProfile]", true, "Six known Apple catalog families or one filtered profile; integrationState/legacyDeviceNamespace/entrypoints/gaps/catalog verification; actionsAuthorized and platformSpecificControlAccepted always false, not host action support denial or proof"),
        ("inventoryObserved", "Bool", true, "True only after one opt-in available Simulator metadata query accepted; not physical or business inventory"),
        ("simulatorCounts", "[HostAppleSimulatorPlatformCount]", true, "Empty when not queried; otherwise global counts for known families/unknown. Strict native runtime ASCII numeric version classifier; iOS runtime not iPhone/iPad/iPadOS distinction, no Mac Simulator assumed. Filter only affects catalog. Zero not unavailable proof"),
        ("sourceCommands", "[String]", true, "Empty default; opt-in actual metadata query descriptor only, never raw backend strings or control commands"),
        ("physicalInventoryObserved", "Bool", true, "Always false; no CoreDevice physical inventory query here"),
        ("actionsExecuted", "Bool", true, "Always false; no lifecycle/control/pair/diagnostic collection"),
        ("inventoryScope", "String", true, "Available Simulator metadata only, no IDs/names/raw runtime echo"),
        ("classification", "String", true, "Runtime identifier shape only, not hardware inference, authenticity or authorization"),
        ("limitations", "[String]", true, "Catalog not current SDK/control/business acceptance; legacy namespaces stable; missing data unknown; no automatic controls or server")
    ]))
}
