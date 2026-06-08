import Foundation

public enum TKDevicectlCommand {
    private static func command(
        _ arguments: [String],
        riskLevel: TKHostRiskLevel = .readonly,
        requiredConfig: Set<TKHostRequiredConfig> = [.timeout],
        defaultTimeoutSeconds: Double = 30,
        capturesArtifacts: Bool = true,
        sensitiveOutput: Bool = true
    ) -> TKHostCommand {
        TKHostCommand(
            arguments: arguments,
            riskLevel: riskLevel,
            requiredConfig: requiredConfig,
            defaultTimeoutSeconds: defaultTimeoutSeconds,
            capturesArtifacts: capturesArtifacts,
            sensitiveOutput: sensitiveOutput
        )
    }

    private static func artifactArguments(jsonOutput: String, logOutput: String) -> [String] {
        ["--json-output", jsonOutput, "--log-output", logOutput]
    }

    public static func listDevices(jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(["devicectl", "list", "devices"] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput))
    }

    public static func deviceInfoDetails(identifier: String, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(["devicectl", "device", "info", "details", "--device", identifier] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput))
    }

    public static func deviceInfoApps(identifier: String, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(["devicectl", "device", "info", "apps", "--device", identifier] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput))
    }

    public static func installApp(identifier: String, appPath: String, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(
            ["devicectl", "device", "install", "app", "--device", identifier, appPath] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput),
            riskLevel: .automation,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: 120
        )
    }

    public static func launchApp(
        identifier: String,
        bundleID: String,
        payloadURL: String? = nil,
        terminateExisting: Bool = false,
        startStopped: Bool = false,
        jsonOutput: String,
        logOutput: String
    ) -> TKHostCommand {
        var arguments = ["devicectl", "device", "process", "launch", "--device", identifier]
        if terminateExisting {
            arguments.append("--terminate-existing")
        }
        if startStopped {
            arguments.append("--start-stopped")
        }
        if let payloadURL {
            arguments += ["--payload-url", payloadURL]
        }
        arguments.append(bundleID)
        arguments += artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput)
        return command(
            arguments,
            riskLevel: .automation,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: 60
        )
    }

    public static func terminateApp(identifier: String, bundleID: String, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(
            ["devicectl", "device", "process", "terminate", "--device", identifier, bundleID] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput),
            riskLevel: .automation,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: 60
        )
    }

    public static func uninstallApp(identifier: String, bundleID: String, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(
            ["devicectl", "device", "uninstall", "app", "--device", identifier, bundleID] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput),
            riskLevel: .automation,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: 120
        )
    }
}

public struct TKDevicectlDeviceTarget: Codable, Equatable {
    public let identifier: String
    public let name: String?
    public let runtime: String?
    public let state: String
    public let ready: Bool
    public let transport: String?
    public let blockedReasons: [String]
    public let source: String
    public let platform: String
    public let scope: String
    public let kind: String
    public let id: String
    public let redactedTarget: String

    public init(
        identifier: String,
        name: String? = nil,
        runtime: String? = nil,
        state: String,
        ready: Bool,
        transport: String? = nil,
        blockedReasons: [String],
        source: String = "devicectl"
    ) {
        self.identifier = identifier
        self.name = name
        self.runtime = runtime
        self.state = state
        self.ready = ready
        self.transport = transport
        self.blockedReasons = blockedReasons
        self.source = source
        self.platform = "ios"
        self.scope = "real"
        self.kind = "real-device"
        self.id = "ios-real:\(TKDevicectlDeviceTarget.stableHash(identifier))"
        self.redactedTarget = self.id
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%012llx", hash & 0x0000ffffffffffff)
    }
}

public enum TKDevicectlParserError: Error, Equatable {
    case malformedJSON(String)
    case missingDevices
}

public enum TKDevicectlDeviceListParser {
    public static func parse(_ data: Data) throws -> [TKDevicectlDeviceTarget] {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TKDevicectlParserError.malformedJSON(error.localizedDescription)
        }
        guard
            let dictionary = root as? [String: Any],
            let result = dictionary["result"] as? [String: Any],
            let devices = result["devices"] as? [[String: Any]]
        else {
            throw TKDevicectlParserError.missingDevices
        }

        return devices.compactMap(parseDevice(_:))
    }

    private static func parseDevice(_ record: [String: Any]) -> TKDevicectlDeviceTarget? {
        guard let identifier = string(record["identifier"] ?? record["deviceIdentifier"]) else {
            return nil
        }
        let deviceProperties = dictionary(record["deviceProperties"])
        let connectionProperties = dictionary(record["connectionProperties"])
        let name = string(deviceProperties["name"] ?? deviceProperties["deviceName"])
        let runtime = runtimeName(from: string(deviceProperties["osVersionNumber"] ?? deviceProperties["osVersion"] ?? deviceProperties["productVersion"]))
        let transport = string(connectionProperties["transportType"] ?? connectionProperties["transport"] ?? connectionProperties["connectionType"])
        let blockedReasons = blockedReasons(record: record, deviceProperties: deviceProperties, connectionProperties: connectionProperties)
        let state = blockedReasons.contains("offline") ? "offline" : (blockedReasons.isEmpty ? "connected" : "blocked")
        return TKDevicectlDeviceTarget(
            identifier: identifier,
            name: name,
            runtime: runtime,
            state: state,
            ready: blockedReasons.isEmpty,
            transport: transport,
            blockedReasons: blockedReasons
        )
    }

    private static func blockedReasons(record: [String: Any], deviceProperties: [String: Any], connectionProperties: [String: Any]) -> [String] {
        var reasons: [String] = []
        let visibility = normalized(string(record["visibilityClass"]))
        let tunnelState = normalized(string(connectionProperties["tunnelState"] ?? connectionProperties["connectionState"]))
        let pairingState = normalized(string(connectionProperties["pairingState"] ?? connectionProperties["pairingStatus"]))
        let developerMode = normalized(string(deviceProperties["developerModeStatus"] ?? deviceProperties["developerMode"]))
        let lockState = normalized(string(deviceProperties["lockState"] ?? deviceProperties["activationState"]))
        let ddiState = normalized(string(deviceProperties["ddiStatus"] ?? deviceProperties["developerDiskImageStatus"]))

        if visibility == "offline" || visibility == "unavailable" || tunnelState == "disconnected" || tunnelState == "offline" || tunnelState == "unavailable" {
            reasons.append("offline")
        }
        if pairingState == "untrusted" || pairingState == "nottrusted" || pairingState == "not-trusted" || pairingState == "not trusted" || pairingState == "unpaired" || bool(connectionProperties["trusted"]) == false {
            reasons.append("not-trusted")
        }
        if (developerMode.isEmpty == false && !["enabled", "on", "true", "available"].contains(developerMode)) || bool(deviceProperties["developerModeEnabled"]) == false {
            reasons.append("developer-mode-required")
        }
        if lockState == "locked" || lockState == "passcodelocked" || lockState == "passcode-locked" || bool(deviceProperties["isLocked"]) == true {
            reasons.append("locked")
        }
        if bool(deviceProperties["ddiServicesAvailable"]) == false || bool(deviceProperties["developerDiskImageMounted"]) == false || ddiState == "missing" || ddiState == "unavailable" || ddiState == "notavailable" || deviceProperties["developerDiskImageError"] != nil {
            reasons.append("ddi-missing")
        }
        return Array(NSOrderedSet(array: reasons)) as? [String] ?? reasons
    }

    private static func runtimeName(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.lowercased().hasPrefix("ios") ? value : "iOS \(value)"
    }

    private static func dictionary(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return value.boolValue ? "true" : "false"
            }
            return value.stringValue
        default:
            return nil
        }
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            switch normalized(value) {
            case "true", "yes", "enabled", "1":
                return true
            case "false", "no", "disabled", "0":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }
}
