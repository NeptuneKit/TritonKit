import Foundation

public enum TKDevicectlFileDomainType: String, Codable, Equatable {
    case appDataContainer
    case appGroupDataContainer
}

public enum TKDevicectlCommand {
    private static func command(
        _ arguments: [String],
        riskLevel: TKHostRiskLevel = .readonly,
        requiredConfig: Set<TKHostRequiredConfig> = [.timeout],
        defaultTimeoutSeconds: Double = 30,
        capturesArtifacts: Bool = true,
        sensitiveOutput: Bool = true,
        environment: [String: String] = [:],
        redactedEnvironmentKeys: Set<String> = [],
        redactedArgumentIndexes: Set<Int> = []
    ) -> TKHostCommand {
        TKHostCommand(
            arguments: arguments,
            environment: environment,
            redactedEnvironmentKeys: redactedEnvironmentKeys,
            redactedArgumentIndexes: redactedArgumentIndexes,
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

    public static func deviceInfoFiles(identifier: String, request: TKDevicectlFilesRequest, jsonOutput: String, logOutput: String) -> TKHostCommand {
        var arguments = ["devicectl", "device", "info", "files", "--device", identifier, "--domain-type", request.domain, "--no-recurse"]
        var redacted: Set<Int> = [5]
        for (flag, value) in [("--domain-identifier", request.domainIdentifier), ("--subdirectory", request.subdirectory), ("--username", request.username)] {
            if let value { arguments.append(flag); redacted.insert(arguments.count); arguments.append(value) }
        }
        return command(arguments + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput), riskLevel: request.domain == "temporary" ? .automation : .readonly, requiredConfig: Set<TKHostRequiredConfig>([.target, .timeout, .artifactDir, .redactionPolicy]).union(request.domain == "temporary" ? [.auditRecord] : []), redactedArgumentIndexes: redacted)
    }

    public static func deviceInfoMountpoint(identifier: String, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(["devicectl", "device", "info", "mountpoint", "--device", identifier] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput), riskLevel: .automation, requiredConfig: [.target, .timeout, .artifactDir, .redactionPolicy, .auditRecord], redactedArgumentIndexes: [5])
    }

    public static func deviceInfoLockState(identifier: String, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(["devicectl", "device", "info", "lockState", "--device", identifier] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput), redactedArgumentIndexes: [5])
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

    public static func copyFromDevice(
        identifier: String,
        source: String,
        destination: String,
        domainType: TKDevicectlFileDomainType,
        domainIdentifier: String,
        jsonOutput: String,
        logOutput: String
    ) -> TKHostCommand {
        command(
            [
                "devicectl", "device", "copy", "from",
                "--device", identifier,
                "--source", source,
                "--destination", destination,
                "--domain-type", domainType.rawValue,
                "--domain-identifier", domainIdentifier,
            ] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput),
            riskLevel: .evidence,
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
        environment: [String: String] = [:],
        arguments appArguments: [String] = [],
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
        var redactedArgumentIndexes: Set<Int> = []
        if !environment.isEmpty {
            arguments += ["--environment-variables", encodedEnvironmentVariables(environment)]
            redactedArgumentIndexes.insert(arguments.count - 1)
        }
        arguments += artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput)
        arguments.append(bundleID)
        arguments += appArguments
        return command(
            arguments,
            riskLevel: .automation,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: 60,
            redactedArgumentIndexes: redactedArgumentIndexes
        )
    }

    private static func encodedEnvironmentVariables(_ environment: [String: String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard
            let data = try? encoder.encode(environment),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }

    public static func terminateApp(identifier: String, pid: Int, jsonOutput: String, logOutput: String) -> TKHostCommand {
        command(
            ["devicectl", "device", "process", "terminate", "--device", identifier, "--pid", String(pid)] + artifactArguments(jsonOutput: jsonOutput, logOutput: logOutput),
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
    public let alternateIdentifiers: [String]

    enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case runtime
        case state
        case ready
        case transport
        case blockedReasons
        case source
        case platform
        case scope
        case kind
        case id
        case redactedTarget
    }

    public init(
        identifier: String,
        name: String? = nil,
        runtime: String? = nil,
        state: String,
        ready: Bool,
        transport: String? = nil,
        blockedReasons: [String],
        source: String = "devicectl",
        alternateIdentifiers: [String] = [],
        platform: String = "ios",
        scope: String = "real",
        kind: String = "real-device",
        simulatorUDID: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.runtime = runtime
        self.state = state
        self.ready = ready
        self.transport = transport
        self.blockedReasons = blockedReasons
        self.source = source
        self.platform = platform
        self.scope = scope
        self.kind = kind
        if scope == "simulator", let simulatorUDID {
            let canonicalUDID = UUID(uuidString: simulatorUDID)?.uuidString ?? simulatorUDID
            self.id = "sim:\(canonicalUDID)"
        } else {
            self.id = "ios-\(scope):\(TKDevicectlDeviceTarget.stableHash(identifier))"
        }
        self.redactedTarget = self.id
        self.alternateIdentifiers = Array(NSOrderedSet(array: alternateIdentifiers.filter { !$0.isEmpty && $0 != identifier })) as? [String] ?? alternateIdentifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.runtime = try container.decodeIfPresent(String.self, forKey: .runtime)
        self.state = try container.decode(String.self, forKey: .state)
        self.ready = try container.decode(Bool.self, forKey: .ready)
        self.transport = try container.decodeIfPresent(String.self, forKey: .transport)
        self.blockedReasons = try container.decode([String].self, forKey: .blockedReasons)
        self.source = try container.decode(String.self, forKey: .source)
        self.platform = try container.decode(String.self, forKey: .platform)
        self.scope = try container.decode(String.self, forKey: .scope)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.id = try container.decode(String.self, forKey: .id)
        self.redactedTarget = try container.decode(String.self, forKey: .redactedTarget)
        self.alternateIdentifiers = []
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
    case invalidDeviceIdentifier
    case unsuccessfulOutcome
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

        if let outcome = (dictionary["info"] as? [String: Any])?["outcome"], normalized(string(outcome)) != "success" {
            throw TKDevicectlParserError.unsuccessfulOutcome
        }
        return try devices.map(parseDevice(_:))
    }

    private static func parseDevice(_ record: [String: Any]) throws -> TKDevicectlDeviceTarget {
        guard let rawIdentifier = (record["identifier"] ?? record["deviceIdentifier"]) as? String,
              !rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TKDevicectlParserError.invalidDeviceIdentifier
        }
        let identifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        // properties is authoritative when present, including empty/unknown sections.
        // Never resurrect stale deprecated mirrors to manufacture readiness.
        let modern = record["properties"] != nil
        let properties = dictionary(record["properties"])
        var deviceProperties = modern ? dictionary(properties["state"]) : dictionary(record["deviceProperties"])
        let hardwareProperties = modern ? dictionary(properties["hardware"]) : dictionary(record["hardwareProperties"])
        var connectionProperties = modern ? dictionary(properties["connection"]) : dictionary(record["connectionProperties"])
        if modern {
            connectionProperties["tunnelState"] = connectionProperties["state"]
            let version = dictionary(properties["software"])["osVersionNumber"]
            deviceProperties["osVersionNumber"] = dictionary(version)["stringValue"] ?? version
            if let mode = deviceProperties["developerModeStatus"] as? [String: Any] {
                deviceProperties["developerModeStatus"] = mode.count == 1 && mode["enabled"] is [String: Any] ? "enabled"
                    : (mode.count == 1 && mode["disabled"] is [String: Any] ? "disabled" : "unknown")
            }
        }
        let name = string(deviceProperties["name"] ?? deviceProperties["deviceName"])
        let runtime = runtimeName(from: string(deviceProperties["osVersionNumber"] ?? deviceProperties["osVersion"] ?? deviceProperties["productVersion"]))
        let transport = string(connectionProperties["transportType"] ?? connectionProperties["transport"] ?? connectionProperties["connectionType"])
        var stateRecord = record
        if deviceProperties["visibilityClass"] != nil { stateRecord["visibilityClass"] = deviceProperties["visibilityClass"] }
        let reality = normalized(string(hardwareProperties["reality"]))
        let declaredPlatform = normalized(string(hardwareProperties["platform"]))
        let platform = declaredPlatform.isEmpty && !modern ? "ios" : (declaredPlatform.isEmpty ? "unknown" : declaredPlatform)
        let simulatorUDID = string(hardwareProperties["udid"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Legacy list payloads describe physical devices. New payloads require an
        // explicit reality; neither a UUID, transport, nor device name proves kind.
        let legacyPhysical = !modern && reality.isEmpty && !deviceProperties.isEmpty && !connectionProperties.isEmpty
        let scope = platform == "ios" && reality == "simulated" && simulatorUDID?.isEmpty == false ? "simulator"
            : (platform == "ios" && (reality == "physical" || legacyPhysical) ? "real" : "unknown")
        let kind = scope == "simulator" ? "simulator" : (scope == "real" ? "real-device" : "unknown")
        var reasons = blockedReasons(record: stateRecord, deviceProperties: deviceProperties, connectionProperties: connectionProperties)
        if scope == "simulator" {
            let boot = normalized(string(deviceProperties["bootState"]))
            if boot != "booted" { reasons.append(boot == "shutdown" ? "not-booted" : "readiness-unknown") }
        } else if scope == "real" {
            let pairing = normalized(string(connectionProperties["pairingState"] ?? connectionProperties["pairingStatus"]))
            let paired = ["paired", "trusted"].contains(pairing) || bool(connectionProperties["trusted"]) == true
            let mode = normalized(string(deviceProperties["developerModeStatus"] ?? deviceProperties["developerMode"]))
            let enabled = ["enabled", "on", "true", "available"].contains(mode) || bool(deviceProperties["developerModeEnabled"]) == true
            let tunnel = normalized(string(connectionProperties["tunnelState"] ?? connectionProperties["connectionState"]))
            let boot = normalized(string(deviceProperties["bootState"]))
            if !boot.isEmpty && boot != "booted" { reasons.append(boot == "shutdown" ? "not-booted" : "readiness-unknown") }
            let visibility = normalized(string(stateRecord["visibilityClass"]))
            let unknownVisibility = stateRecord["visibilityClass"] != nil && !["default", "available", "offline", "unavailable", "hidden"].contains(visibility)
            if reasons.isEmpty && (!paired || !enabled || !["connected", "disconnected"].contains(tunnel) || unknownVisibility) { reasons.append("readiness-unknown") }
        } else {
            reasons.append("readiness-unknown")
        }
        let blockedReasons = Array(NSOrderedSet(array: reasons)) as? [String] ?? reasons
        let state = blockedReasons.contains("offline") ? "offline" : (blockedReasons.contains("readiness-unknown") ? "unknown" : (blockedReasons.isEmpty ? "connected" : "blocked"))
        return TKDevicectlDeviceTarget(
            identifier: identifier,
            name: name,
            runtime: runtime,
            state: state,
            ready: blockedReasons.isEmpty,
            transport: transport,
            blockedReasons: blockedReasons,
            alternateIdentifiers: alternateIdentifiers(record: record, deviceProperties: deviceProperties, hardwareProperties: hardwareProperties),
            platform: platform,
            scope: scope,
            kind: kind,
            simulatorUDID: simulatorUDID
        )
    }

    private static func alternateIdentifiers(record: [String: Any], deviceProperties: [String: Any], hardwareProperties: [String: Any]) -> [String] {
        let values = [
            string(record["udid"] ?? record["UDID"] ?? record["uniqueDeviceID"] ?? record["uniqueDeviceIdentifier"]),
            string(deviceProperties["udid"] ?? deviceProperties["UDID"] ?? deviceProperties["uniqueDeviceID"] ?? deviceProperties["uniqueDeviceIdentifier"]),
            string(hardwareProperties["udid"] ?? hardwareProperties["UDID"] ?? hardwareProperties["uniqueDeviceID"] ?? hardwareProperties["uniqueDeviceIdentifier"]),
            string(hardwareProperties["serialNumber"] ?? hardwareProperties["serial"]),
            string(hardwareProperties["ecid"]),
        ]
        return Array(NSOrderedSet(array: values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })) as? [String] ?? []
    }

    private static func blockedReasons(record: [String: Any], deviceProperties: [String: Any], connectionProperties: [String: Any]) -> [String] {
        var reasons: [String] = []
        let visibility = normalized(string(record["visibilityClass"]))
        let tunnelState = normalized(string(connectionProperties["tunnelState"] ?? connectionProperties["connectionState"]))
        let pairingState = normalized(string(connectionProperties["pairingState"] ?? connectionProperties["pairingStatus"]))
        let developerMode = normalized(string(deviceProperties["developerModeStatus"] ?? deviceProperties["developerMode"]))
        let lockState = normalized(string(deviceProperties["lockState"] ?? deviceProperties["activationState"]))
        let ddiState = normalized(string(deviceProperties["ddiStatus"] ?? deviceProperties["developerDiskImageStatus"]))
        let trusted = bool(connectionProperties["trusted"])
        let pairingEligible = ["paired", "trusted"].contains(pairingState) || trusted == true
        let visibilityUnavailable = visibility == "offline" || visibility == "unavailable"
        let lazyServiceActivationEligible = pairingEligible && !visibilityUnavailable

        // CoreDevice can report an available, paired device before it lazily
        // establishes its tunnel. `disconnected` describes that service tunnel,
        // not necessarily the physical device, so only explicit unavailable
        // visibility/tunnel states, or a disconnected unpaired target, are
        // terminal discovery blockers.
        if visibilityUnavailable || tunnelState == "offline" || tunnelState == "unavailable" || (tunnelState == "disconnected" && !lazyServiceActivationEligible) {
            reasons.append("offline")
        }
        if pairingState == "untrusted" || pairingState == "nottrusted" || pairingState == "not-trusted" || pairingState == "not trusted" || pairingState == "unpaired" || trusted == false {
            reasons.append("not-trusted")
        }
        if ["disabled", "off", "false", "unavailable"].contains(developerMode) || bool(deviceProperties["developerModeEnabled"]) == false {
            reasons.append("developer-mode-required")
        }
        if lockState == "locked" || lockState == "passcodelocked" || lockState == "passcode-locked" || bool(deviceProperties["isLocked"]) == true {
            reasons.append("locked")
        }
        // A false service/mount snapshot is also expected before devicectl lazily
        // activates development services. Keep fail-closed behavior for an
        // explicit missing/unavailable DDI status or a concrete DDI error.
        let ddiSnapshotUnavailable = bool(deviceProperties["ddiServicesAvailable"]) == false
            || bool(deviceProperties["developerDiskImageMounted"]) == false
        if ddiState == "missing"
            || ddiState == "unavailable"
            || ddiState == "notavailable"
            || deviceProperties["developerDiskImageError"] != nil
            || (ddiSnapshotUnavailable && !lazyServiceActivationEligible)
        {
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
