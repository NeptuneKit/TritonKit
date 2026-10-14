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
        guard let udid = request.udid, UUID(uuidString: udid) != nil else { throw SimulatorResourceMutationError.missingUDID }
        guard let value = request.profile, !value.isEmpty else { throw SimulatorResourceMutationError.missingProfile }
        let profile = try Self.resolveProfile(value)
        let desired = Set(SimulatorResourceMutationPlanner.labels(for: profile))
        let actual: Set<String>
        if !request.noReboot, try !isBooted(udid: udid) {
            actual = Set(try SimulatorResourceOfflineStore.read(udid).filter(\.value).map(\.key))
            let delta = SimulatorResourceCatalog.delta(current: actual, desired: desired)
            try SimulatorResourceOfflineStore.merge(udid, disable: Set(delta.disable), enable: Set(delta.enable))
            try runChecked(SimulatorResourceMutationPlanner.bootCommands(udid: udid))
        } else {
            actual = Set(try readOverrides(udid: udid).overrides.filter(\.value).map(\.key))
            let delta = SimulatorResourceCatalog.delta(current: actual, desired: desired)
            // Required services are repaired before slimming other services.
            try runChecked(SimulatorResourceMutationPlanner.enableCommands(udid: udid, labels: delta.enable))
            try runChecked(SimulatorResourceMutationPlanner.disableCommands(udid: udid, labels: delta.disable))
            if !request.noReboot { try runChecked(SimulatorResourceMutationPlanner.rebootCommands(udid: udid)) }
        }
        let applied = Set(try readOverrides(udid: udid).overrides.filter(\.value).map(\.key))
        guard applied.intersection(SimulatorResourceCatalog.managedLabels) == desired else { throw SimulatorResourceMutationError.verificationFailed }
        let previousStatus = TKSimulatorResourceStatus(udid: udid, runtime: previous.runtime, profileID: previous.profileID, enabled: !actual.intersection(SimulatorResourceCatalog.managedLabels).isEmpty, disabledCategories: previous.disabledCategories)
        let appliedStatus = TKSimulatorResourceStatus(udid: udid, runtime: previous.runtime, profileID: profile.id, enabled: !desired.isEmpty, disabledCategories: profile.disabledCategories)
        return TKSimulatorResourceReceipt(udid: udid, profile: profile, previous: previousStatus, applied: appliedStatus, noReboot: request.noReboot,
            previousManagedDisabled: actual.intersection(SimulatorResourceCatalog.managedLabels), appliedManagedDisabled: applied.intersection(SimulatorResourceCatalog.managedLabels))
    }

    private func isBooted(udid: String) throws -> Bool {
        let result = try runner.run(TKSimctlCommand.listAvailableDevices())
        guard result.exitCode == 0, !result.stdoutTruncated else { throw SimulatorResourceMutationError.commandFailed }
        let devices = try TKSimctlDeviceListParser.parse(result.stdoutData)
        guard let device = devices.first(where: { $0.udid == udid }) else { throw SimulatorResourceMutationError.missingUDID }
        return device.isBooted
    }

    private func runChecked(_ commands: [TKHostCommand]) throws {
        for command in commands {
            guard try runner.run(command).exitCode == 0 else { throw SimulatorResourceMutationError.commandFailed }
        }
    }

    static func resolveProfile(_ value: String) throws -> TKSimulatorResourceProfile {
        let profile: TKSimulatorResourceProfile
        if value == "stock" { profile = TKSimulatorResourceProfile(id: "stock") }
        else if value == "ci" {
            profile = TKSimulatorResourceProfile(id: "ci", disabledCategories: Set(SimulatorResourceCatalog.categories.compactMap { TKSimulatorResourceCategory(rawValue: $0.id) }))
        } else {
            profile = try JSONDecoder().decode(TKSimulatorResourceProfile.self, from: SimulatorResourceReceiptReader.readData(value))
        }
        try profile.validate()
        let supported = Set(SimulatorResourceCatalog.categories.map(\.id))
        guard profile.disabledCategories.allSatisfy({ supported.contains($0.rawValue) }) else { throw TKSimulatorResourceProfile.ValidationError.invalidProfile }
        return profile
    }

    public func verify(_ request: SimulatorResourceRequest) throws {
        guard let udid = request.udid else { throw SimulatorResourceMutationError.missingUDID }
        guard let value = request.profile, !value.isEmpty else { throw SimulatorResourceMutationError.missingProfile }
        let profile = try Self.resolveProfile(value)
        let state = try readOverrides(udid: udid)
        let desired = Set(SimulatorResourceMutationPlanner.labels(for: profile))
        let actual = Set(state.overrides.filter(\.value).map(\.key))
        guard actual.intersection(SimulatorResourceCatalog.managedLabels) == desired else { throw SimulatorResourceMutationError.verificationFailed }
    }

    public func restore(_ receipt: TKSimulatorResourceReceipt) throws {
        try SimulatorResourceReceiptReader.validate(receipt)
        let state = try readOverrides(udid: receipt.udid)
        let current = Set(state.overrides.filter(\.value).map(\.key))
        let previous = receipt.previousManagedDisabled
        let applied = receipt.appliedManagedDisabled
        // Three-way comparison: revert only labels whose state still matches this receipt's applied state.
        let enable = applied.subtracting(previous).intersection(current)
        let disable = Set(previous.subtracting(applied).filter { state.overrides[$0] == false })
            .subtracting(SimulatorResourceCatalog.alwaysEnabledLabels)
        try runChecked(SimulatorResourceMutationPlanner.enableCommands(udid: receipt.udid, labels: enable.sorted()))
        try runChecked(SimulatorResourceMutationPlanner.disableCommands(udid: receipt.udid, labels: disable.sorted()))
        if !receipt.noReboot && (!enable.isEmpty || !disable.isEmpty) {
            try runChecked(SimulatorResourceMutationPlanner.rebootCommands(udid: receipt.udid))
        }
        let final = Set(try readOverrides(udid: receipt.udid).overrides.filter(\.value).map(\.key))
        guard enable.isDisjoint(with: final), disable.isSubset(of: final) else { throw SimulatorResourceMutationError.verificationFailed }
    }
}

struct SimulatorResourceMutationPlanner {
    static func labels(for profile: TKSimulatorResourceProfile) -> [String] {
        let except = Set(SimulatorResourceCatalog.categories.filter { category in
            !profile.disabledCategories.contains(where: { $0.rawValue == category.id })
        }.map(\.id))
        // Categories share dependencies; a kept category always wins.
        return (try? SimulatorResourceCatalog.desired(exceptCategories: except).sorted()) ?? []
    }
    static func disableCommands(udid: String, labels: [String]) -> [TKHostCommand] {
        labels.map { TKHostCommand(arguments: ["simctl", "spawn", udid, "launchctl", "disable", "system/\($0)"]) }
    }
    static func enableCommands(udid: String, labels: [String]) -> [TKHostCommand] {
        labels.map { TKHostCommand(arguments: ["simctl", "spawn", udid, "launchctl", "enable", "system/\($0)"]) }
    }
    static func rebootCommands(udid: String) -> [TKHostCommand] {
        [TKHostCommand(arguments:["simctl","shutdown",udid])] + bootCommands(udid: udid)
    }
    static func bootCommands(udid: String) -> [TKHostCommand] {
        [TKHostCommand(arguments:["simctl","boot",udid]), TKHostCommand(arguments:["simctl","bootstatus",udid,"-b"])]
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
