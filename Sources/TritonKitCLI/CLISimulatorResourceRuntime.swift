import Foundation
import TritonKitShared

public enum SimulatorResourceAction: String, Codable, Sendable { case profiles, features, status, measure, doctor, plan }

public struct SimulatorResourceRequest: Codable, Equatable, Sendable {
    public let action: SimulatorResourceAction
    public let udid: String?
    public let profile: String?
    public let requires: [String]
    public init(action: SimulatorResourceAction, udid: String? = nil, profile: String? = nil, requires: [String] = []) { self.action = action; self.udid = udid; self.profile = profile; self.requires = requires }
}

public protocol SimulatorResourceCommandRunning { func run(_ command: TKHostCommand) throws -> HostProcessResult }
public struct LiveSimulatorResourceCommandRunner: SimulatorResourceCommandRunning { public init() {} ; public func run(_ command: TKHostCommand) throws -> HostProcessResult { try runHostCommand(command) } }

public struct CLISimulatorResourceRuntime {
    public let runner: any SimulatorResourceCommandRunning
    public init(runner: any SimulatorResourceCommandRunning = LiveSimulatorResourceCommandRunner()) { self.runner = runner }
    public func command(for request: SimulatorResourceRequest) -> TKHostCommand {
        var args = ["sim", "resource", request.action.rawValue]
        if let udid = request.udid { args += ["--udid", udid] }
        if let profile = request.profile { args += ["--profile", profile] }
        if !request.requires.isEmpty { args += ["--requires", request.requires.joined(separator: ",")] }
        return TKHostCommand(arguments: args)
    }
    public func execute(_ request: SimulatorResourceRequest) throws -> HostProcessResult { try runner.run(command(for: request)) }
}
