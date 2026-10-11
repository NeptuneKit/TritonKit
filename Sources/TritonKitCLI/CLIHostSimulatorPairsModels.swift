import TritonKitShared

struct HostSimulatorPairsOutput: Encodable {
    let ok = true
    let action = "sim.pairs"
    let runtimeScope = "host-simulator"
    let riskLevel = "readonly"
    let pairs: [TKSimulatorPair]
    let sourceCommands: [String]
    let verification = "executed-simctl-json"
    let actionsExecuted = false
    let pairingStateVerified = false
    let limitations = ["Native Simulator relationship snapshot only; not physical watch pairing, endpoint availability, input support or business readiness", "Unknown native state stays unknown; no lifecycle or pair/unpair action", "JSON byte/record limits are local acceptance budgets, not native collection limits"]
}
struct HostSimulatorPairsFailure: Error, CustomStringConvertible {
    let detail: TKCLIErrorDetail
    init(_ error: Error) {
        let timeout: Bool
        if case HostCommandRunError.timeout = error { timeout = true } else { timeout = false }
        detail = TKCLIErrorDetail(code: timeout ? "host_command_timeout" : "sim_pairs_query_failed", message: "Readonly Simulator pair metadata query failed.", hint: "Inspect private host evidence; no pairing or lifecycle action was performed. Native output is accepted only as bounded JSON.")
    }
    var description: String { detail.message }
}
