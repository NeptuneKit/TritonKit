import Foundation
import TritonKitShared

public enum SimulatorResourceAction: String, Codable, Sendable { case profiles, features, status, measure, doctor, plan, apply, verify, restore }

public struct SimulatorResourceRequest: Codable, Equatable, Sendable {
    public let action: SimulatorResourceAction
    public let udid: String?
    public let profile: String?
    public let requires: [String]
    public let noReboot: Bool
    public init(action: SimulatorResourceAction, udid: String? = nil, profile: String? = nil, requires: [String] = [], noReboot: Bool = false) { self.action = action; self.udid = udid; self.profile = profile; self.requires = requires; self.noReboot = noReboot }
}

protocol SimulatorResourceCommandRunning { func run(_ command: TKHostCommand) throws -> HostProcessResult }
struct LiveSimulatorResourceCommandRunner: SimulatorResourceCommandRunning { init() {} ; func run(_ command: TKHostCommand) throws -> HostProcessResult { try runHostCommand(command) } }

public struct CLISimulatorResourceRuntime {
    let runner: any SimulatorResourceCommandRunning
    init(runner: any SimulatorResourceCommandRunning = LiveSimulatorResourceCommandRunner()) { self.runner = runner }
    public func command(for request: SimulatorResourceRequest) -> TKHostCommand {
        var args = ["sim", "resource", request.action.rawValue]
        if let udid = request.udid { args += ["--udid", udid] }
        if let profile = request.profile { args += ["--profile", profile] }
        if !request.requires.isEmpty { args += ["--requires", request.requires.joined(separator: ",")] }
        if request.noReboot { args += ["--no-reboot"] }
        return TKHostCommand(arguments: args)
    }
    func execute(_ request: SimulatorResourceRequest) throws -> HostProcessResult { try runner.run(command(for: request)) }
}

public enum SimulatorResourceMutationError: Error, Equatable { case missingUDID, missingProfile, invalidReceipt, commandFailed, verificationFailed }

extension CLISimulatorResourceRuntime {
    public func apply(_ request: SimulatorResourceRequest, previous: TKSimulatorResourceStatus) throws -> TKSimulatorResourceReceipt {
        guard let udid=request.udid else { throw SimulatorResourceMutationError.missingUDID }
        guard let p=request.profile, !p.isEmpty else { throw SimulatorResourceMutationError.missingProfile }
        let profile = try Self.resolveProfile(p)
        let observed = try readOverrides(udid: udid)
        let desired = Set(SimulatorResourceMutationPlanner.labels(for: profile))
        let actual = Set(observed.overrides.compactMap { $0.value ? $0.key : nil })
        let toDisable = desired.subtracting(actual)
        for command in SimulatorResourceMutationPlanner.disableCommands(udid: udid, labels: Array(toDisable).sorted()) {
            let result = try runner.run(command); guard result.exitCode == 0 else { throw SimulatorResourceMutationError.commandFailed }
        }
        if !request.noReboot { for command in SimulatorResourceMutationPlanner.rebootCommands(udid: udid) { let result = try runner.run(command); guard result.exitCode == 0 else { throw SimulatorResourceMutationError.commandFailed } } }
        let after = try readOverrides(udid: udid)
        let appliedLabels = Set(after.overrides.compactMap { $0.value ? $0.key : nil })
        guard desired.isSubset(of: appliedLabels) else { throw SimulatorResourceMutationError.verificationFailed }
        let previousStatus = TKSimulatorResourceStatus(udid: udid, runtime: previous.runtime, profileID: previous.profileID, enabled: !actual.isEmpty, disabledCategories: previous.disabledCategories)
        let appliedStatus = TKSimulatorResourceStatus(udid: udid, runtime: previous.runtime, profileID: profile.id, enabled: true, disabledCategories: profile.disabledCategories)
        return TKSimulatorResourceReceipt(udid: udid, profile: profile, previous: previousStatus, applied: appliedStatus, noReboot: request.noReboot, previousManagedDisabled: actual.intersection(desired), appliedManagedDisabled: appliedLabels.intersection(desired))
    }
    static func resolveProfile(_ value: String) throws -> TKSimulatorResourceProfile {
        if value == "stock" { return TKSimulatorResourceProfile(id: "stock") }
        if value == "ci" { return TKSimulatorResourceProfile(id: "ci", disabledCategories: Set(TKSimulatorResourceCategory.allCases).subtracting([.core])) }
        let data = try Data(contentsOf: URL(fileURLWithPath: value))
        return try JSONDecoder().decode(TKSimulatorResourceProfile.self, from: data)
    }
    public func verify(_ request: SimulatorResourceRequest) throws {
        guard let udid = request.udid else { throw SimulatorResourceMutationError.missingUDID }
        guard let p = request.profile, !p.isEmpty else { throw SimulatorResourceMutationError.missingProfile }
        let profile = try Self.resolveProfile(p)
        let state = try readOverrides(udid: udid)
        let desired = Set(SimulatorResourceMutationPlanner.labels(for: profile))
        let actual = Set(state.overrides.compactMap { $0.value ? $0.key : nil })
        guard desired.isSubset(of: actual) else { throw SimulatorResourceMutationError.verificationFailed }
    }
    public func restore(_ receipt: TKSimulatorResourceReceipt) throws {
        guard !receipt.udid.isEmpty else { throw SimulatorResourceMutationError.invalidReceipt }
        let current = try readOverrides(udid: receipt.udid)
        let previous = receipt.previousManagedDisabled
        let applied = receipt.appliedManagedDisabled
        for label in applied.subtracting(previous) { _ = try runner.run(SimulatorResourceMutationPlanner.enableCommands(udid: receipt.udid, labels: [label]).first!) }
        for label in previous.subtracting(applied) { _ = try runner.run(SimulatorResourceMutationPlanner.disableCommands(udid: receipt.udid, labels: [label]).first!) }
        _ = current
        if !receipt.noReboot {
            for command in SimulatorResourceMutationPlanner.rebootCommands(udid: receipt.udid) {
                let result = try runner.run(command)
                guard result.exitCode == 0 else { throw SimulatorResourceMutationError.commandFailed }
            }
        }
        let final = try readOverrides(udid: receipt.udid)
        let actual = Set(final.overrides.compactMap { $0.value ? $0.key : nil })
        guard previous.isSubset(of: actual) else { throw SimulatorResourceMutationError.verificationFailed }
    }
}

struct SimulatorResourceMutationPlanner {
    static func labels(for profile: TKSimulatorResourceProfile) -> [String] {
        let cats = SimulatorResourceCatalog.categories.filter { catalogCategory in profile.disabledCategories.contains(where: { category in category.rawValue == catalogCategory.id }) }
        return Array(Set(cats.flatMap { $0.labels }.filter { !SimulatorResourceCatalog.alwaysEnabledLabels.contains($0) })).sorted()
    }
    static func disableCommands(udid: String, labels: [String]) -> [TKHostCommand] {
        labels.map { TKHostCommand(arguments: ["simctl", "spawn", udid, "launchctl", "disable", "system/\($0)"]) }
    }
    static func enableCommands(udid: String, labels: [String]) -> [TKHostCommand] {
        labels.map { TKHostCommand(arguments: ["simctl", "spawn", udid, "launchctl", "enable", "system/\($0)"]) }
    }
    static func rebootCommands(udid: String) -> [TKHostCommand] {
        [TKHostCommand(arguments:["simctl","shutdown",udid]), TKHostCommand(arguments:["simctl","boot",udid])]
    }
}

extension CLISimulatorResourceRuntime {
 public func measurementCommand(udid: String) -> TKHostCommand {
  TKHostCommand(arguments:["simctl","spawn",udid,"ps","-axo","pid,rss"])
 }
 public func measure(udid:String) throws -> TKSimulatorResourceMeasurement {
  let r=try runner.run(measurementCommand(udid: udid)); guard r.exitCode == 0 else { throw SimulatorResourceMutationError.commandFailed }
  let output=String(data:r.stdoutData,encoding:.utf8) ?? ""
  return try TKSimulatorMeasurementParser.measurement(udid:udid, psOutput:output)
 }
}
