import Foundation
import TritonKitShared

struct AppleHostCommandSpecification {
    let name: String
    let helpArguments: [String]
    let requiredOptions: [String]
    let requiredForDiscovery: Bool

    static func forScope(_ scope: HostDeviceScope) -> [Self] {
        var specifications: [Self] = []
        if scope != .real {
            specifications += [
                Self(name: "simctl.list", helpArguments: ["simctl", "help", "list"], requiredOptions: ["--json"], requiredForDiscovery: true),
                Self(name: "simctl.bootstatus", helpArguments: ["simctl", "help", "bootstatus"], requiredOptions: ["-b"], requiredForDiscovery: false),
            ]
        }
        if scope == .real || scope == .all {
            let outputOptions = ["--json-output", "--log-output"]
            specifications += [
                Self(name: "devicectl.list-devices", helpArguments: ["devicectl", "list", "devices", "--help"], requiredOptions: outputOptions, requiredForDiscovery: true),
                Self(name: "devicectl.info-details", helpArguments: ["devicectl", "device", "info", "details", "--help"], requiredOptions: ["--device"] + outputOptions, requiredForDiscovery: false),
                Self(name: "devicectl.launch", helpArguments: ["devicectl", "device", "process", "launch", "--help"], requiredOptions: ["--device"] + outputOptions, requiredForDiscovery: false),
                Self(name: "devicectl.launch-environment", helpArguments: ["devicectl", "device", "process", "launch", "--help"], requiredOptions: ["--environment-variables"], requiredForDiscovery: false),
            ]
        }
        return specifications
    }
}

struct HostAppleCommandSupport: Encodable {
    let name: String
    let supported: Bool
    let requiredOptions: [String]
    let missingOptions: [String]
    let sourceCommand: String
    let error: String?
    let verification = "help-advertised-only"
}

func probeAppleHostCommand(
    _ specification: AppleHostCommandSpecification,
    help: ([String]) throws -> String = { arguments in
        let result = try runHostCommand(TKHostCommand(arguments: arguments, defaultTimeoutSeconds: 10))
        return result.stdout + "\n" + result.stderr
    }
) -> HostAppleCommandSupport {
    let command = TKHostCommand(arguments: specification.helpArguments)
    do {
        let text = try help(specification.helpArguments)
        let missing = specification.requiredOptions.filter { option in
            let escaped = NSRegularExpression.escapedPattern(for: option)
            return text.range(of: "(?<![A-Za-z0-9_-])" + escaped + "(?![A-Za-z0-9_-])", options: .regularExpression) == nil
        }
        return HostAppleCommandSupport(name: specification.name, supported: missing.isEmpty, requiredOptions: specification.requiredOptions, missingOptions: missing, sourceCommand: hostSourceCommand(command), error: missing.isEmpty ? nil : "command_options_unsupported")
    } catch {
        return HostAppleCommandSupport(name: specification.name, supported: false, requiredOptions: specification.requiredOptions, missingOptions: specification.requiredOptions, sourceCommand: hostSourceCommand(command), error: "command_help_unavailable")
    }
}
