import ArgumentParser
import Foundation
import TritonKitShared

struct SimResource: AsyncParsableCommand { static let configuration=CommandConfiguration(commandName:"resource",abstract:"Manage simulator resources",subcommands:[SimResourceProfiles.self,SimResourceFeatures.self,SimResourceStatus.self,SimResourceMeasure.self,SimResourceDoctor.self,SimResourcePlan.self,SimResourceApply.self,SimResourceVerify.self,SimResourceRestore.self]) }
func resourceRun(_ req: SimulatorResourceRequest) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    switch req.action {
    case .profiles:
        let data = try encoder.encode(SimulatorResourceCatalog.categories)
        let body: [String: Any] = ["ok": true, "catalogCommit": SimulatorResourceCatalog.sourceCommit,
                                 "categories": try JSONSerialization.jsonObject(with: data)]
        print(String(decoding: try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), as: UTF8.self))
    case .features:
        let data = try encoder.encode(SimulatorResourceCatalog.features)
        let body: [String: Any] = ["ok": true, "features": try JSONSerialization.jsonObject(with: data)]
        print(String(decoding: try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), as: UTF8.self))
    case .status, .doctor:
        guard let udid = req.udid else { throw SimulatorResourceMutationError.missingUDID }
        let runtime = CLISimulatorResourceRuntime()
        let inspection = SimulatorResourceInspection(read: { try runtime.readOverrides(udid: $0) })
        let body = try req.action == .status
            ? inspection.status(udid: udid)
            : inspection.doctor(udid: udid, requires: req.requires)
        print(String(decoding: try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), as: UTF8.self))
        if body["ok"] as? Bool != true { throw ExitCode.failure }
    case .measure:
        guard let udid = req.udid else { throw SimulatorResourceMutationError.missingUDID }
        let measurement = try SimulatorPhysicalFootprint().measure(udid: udid)
        let body: [String: Any] = [
            "ok": !measurement.partial, "partial": measurement.partial,
            "action": "resource.measure", "simulatorUDID": udid,
            "metric": "phys_footprint", "unit": "bytes",
            "measurement": try JSONSerialization.jsonObject(with: encoder.encode(measurement)),
        ]
        print(String(decoding: try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), as: UTF8.self))
        if measurement.partial { throw ExitCode.failure }
    case .plan:
        guard let u=req.udid, let p=req.profile else { throw ValidationError("udid and profile are required") }
        let profile = TKSimulatorResourceProfile(id:p); try profile.validate()
        let d = try JSONSerialization.data(withJSONObject: ["ok":true, "udid":u, "profile": try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile))], options: [.sortedKeys]); print(String(decoding:d,as:UTF8.self))
    case .apply:
        guard let udid=req.udid, let profile=req.profile else { throw ValidationError("udid and profile are required") }
        let runtime = CLISimulatorResourceRuntime()
        let actual = try runtime.readOverrides(udid: udid)
        let previous = TKSimulatorResourceStatus(udid: udid, runtime: "unknown", enabled: !actual.overrides.isEmpty)
        let receipt = try runtime.apply(req, previous: previous)
        let data = try encoder.encode(receipt)
        print(String(decoding:data, as: UTF8.self))
    case .verify:
        guard let udid=req.udid, let profile=req.profile else { throw ValidationError("udid and profile are required") }
        try CLISimulatorResourceRuntime().verify(req)
        print("{\"ok\":true}")
    default:
        throw ValidationError("unsupported resource action")
    }
}
struct SimResourceProfiles: AsyncParsableCommand { static let configuration=CommandConfiguration(commandName:"profiles"); func run() async throws { try resourceRun(.init(action:.profiles)) } }
struct SimResourceFeatures: AsyncParsableCommand { static let configuration=CommandConfiguration(commandName:"features"); func run() async throws { try resourceRun(.init(action:.features)) } }
struct SimResourceStatus: AsyncParsableCommand { @Argument var simulator:String; @Flag(name: .long) var json=false; static let configuration=CommandConfiguration(commandName:"status"); func run() async throws { try resourceRun(.init(action:.status,udid:simulator)) } }
struct SimResourceMeasure: AsyncParsableCommand { @Argument var simulator:String; @Flag(name: .long) var json=false; static let configuration=CommandConfiguration(commandName:"measure"); func run() async throws { try resourceRun(.init(action:.measure,udid:simulator)) } }
struct SimResourceDoctor: AsyncParsableCommand { @Argument var simulator:String; @Option var requires:String?; static let configuration=CommandConfiguration(commandName:"doctor"); func run() async throws { try resourceRun(.init(action:.doctor,udid:simulator,requires:requires?.split(separator:",").map(String.init) ?? [])) } }
struct SimResourcePlan: AsyncParsableCommand { @Argument var simulator:String; @Option var profile:String="stock"; static let configuration=CommandConfiguration(commandName:"plan"); func run() async throws { try resourceRun(.init(action:.plan,udid:simulator,profile:profile)) } }
struct SimResourceApply: AsyncParsableCommand { @Argument var simulator:String; @Option var profile:String; @Flag var noReboot=false; @Flag(name: .long) var json=false; static let configuration=CommandConfiguration(commandName:"apply"); func run() async throws { try resourceRun(.init(action:.apply,udid:simulator,profile:profile,noReboot:noReboot)) } }
struct SimResourceVerify: AsyncParsableCommand { @Argument var simulator:String; @Option var profile:String; @Flag(name: .long) var json=false; static let configuration=CommandConfiguration(commandName:"verify"); func run() async throws { try resourceRun(.init(action:.verify,udid:simulator,profile:profile)) } }
struct SimResourceRestore: AsyncParsableCommand {
    @Argument var receipt:String
    @Flag(name: .long) var json=false
    static let configuration=CommandConfiguration(commandName:"restore")
    func run() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: receipt))
        let value = try JSONDecoder().decode(TKSimulatorResourceReceipt.self, from: data)
        try CLISimulatorResourceRuntime().restore(value)
        print("{\"ok\":true,\"receipt\":\"\(receipt)\"}")
    }
}
