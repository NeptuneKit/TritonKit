import TritonKitShared

func hostSimulatorPairsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.simulator-pairs", format: "json", kind: "host-action", model: "HostSimulatorPairsOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Bounded native Simulator JSON relationship snapshot accepted"),
        ("action", "String", true, "sim.pairs"),
        ("pairs", "[TKSimulatorPair]", true, "Native pair ID and watch/phone sim IDs; known active/connection state or unknown; no names"),
        ("verification", "String", true, "executed-simctl-json; no endpoint readiness/input or physical pairing claim"),
        ("sourceCommands", "[String]", true, "simctl list pairs --json, readonly"),
        ("actionsExecuted", "Bool", true, "Always false; no pair/unpair/lifecycle mutation"),
        ("pairingStateVerified", "Bool", true, "Always false; inventory metadata does not independently verify pairing connectivity"),
        ("limitations", "[String]", true, "Local acceptance budgets and relationship-only scope")
    ]))
}
