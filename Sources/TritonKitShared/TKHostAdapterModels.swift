import Foundation

public enum TKHostAppContainerKind: String, Codable, Equatable {
    case app
    case data
    case groups
}

public struct TKHostWorkspaceDefaults: Codable, Equatable {
    public let defaultSimulatorUDID: String?
    public let xcode: TKXcodeWorkspaceDefaults?

    public init(defaultSimulatorUDID: String? = nil, xcode: TKXcodeWorkspaceDefaults? = nil) {
        self.defaultSimulatorUDID = defaultSimulatorUDID
        self.xcode = xcode
    }

    public static func filePath(workspace: String) -> String {
        URL(fileURLWithPath: workspace)
            .appendingPathComponent(".triton")
            .appendingPathComponent("host-defaults.json")
            .path
    }
}

public struct TKHostCommand: Codable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let riskLevel: TKHostRiskLevel
    public let requiredConfig: Set<TKHostRequiredConfig>
    public let defaultTimeoutSeconds: Double
    public let capturesArtifacts: Bool
    public let sensitiveOutput: Bool

    public init(
        executable: String = "xcrun",
        arguments: [String],
        riskLevel: TKHostRiskLevel = .readonly,
        requiredConfig: Set<TKHostRequiredConfig> = [.timeout],
        defaultTimeoutSeconds: Double = 30,
        capturesArtifacts: Bool = false,
        sensitiveOutput: Bool = false
    ) {
        self.executable = executable
        self.arguments = arguments
        self.riskLevel = riskLevel
        self.requiredConfig = requiredConfig
        self.defaultTimeoutSeconds = defaultTimeoutSeconds
        self.capturesArtifacts = capturesArtifacts
        self.sensitiveOutput = sensitiveOutput
    }

    public var argv: [String] {
        arguments
    }

    public var processArguments: [String] {
        arguments
    }

    public func missingRequiredConfig(policy: TKHostExecutionPolicy) -> [TKHostRequiredConfig] {
        TKHostRequiredConfig.allCases.filter { requiredConfig.contains($0) && !policy.provides($0) }
    }

    public func withTimeout(_ timeoutSeconds: Double?) -> TKHostCommand {
        guard let timeoutSeconds else {
            return self
        }
        return TKHostCommand(
            executable: executable,
            arguments: arguments,
            riskLevel: riskLevel,
            requiredConfig: requiredConfig,
            defaultTimeoutSeconds: timeoutSeconds,
            capturesArtifacts: capturesArtifacts,
            sensitiveOutput: sensitiveOutput
        )
    }
}

public enum TKHostRiskLevel: String, Codable, Equatable {
    case readonly
    case evidence
    case automation
    case diagnostic
    case breakGlass = "break-glass"
    case unknown
}

public enum TKHostRequiredConfig: String, CaseIterable, Codable, Equatable, Hashable {
    case target
    case artifactDir
    case redactionPolicy
    case timeout
    case auditRecord
}

public struct TKHostExecutionPolicy: Codable, Equatable {
    public let mode: TKHostRiskLevel
    public let target: String?
    public let artifactDir: String?
    public let redactionPolicy: String?
    public let timeoutSeconds: Double?
    public let audit: Bool

    public init(
        mode: TKHostRiskLevel = .readonly,
        target: String? = nil,
        artifactDir: String? = nil,
        redactionPolicy: String? = nil,
        timeoutSeconds: Double? = nil,
        audit: Bool = false
    ) {
        self.mode = mode
        self.target = target
        self.artifactDir = artifactDir
        self.redactionPolicy = redactionPolicy
        self.timeoutSeconds = timeoutSeconds
        self.audit = audit
    }

    public static func resolve(
        explicitMode: TKHostRiskLevel? = nil,
        artifactDir: String? = nil,
        redactionPolicy: String? = nil,
        timeoutSeconds: Double? = nil,
        target: String? = nil,
        audit: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TKHostExecutionPolicy {
        let environmentMode = environment["TRITON_HOST_POLICY"]
            .flatMap(TKHostRiskLevel.init(rawValue:))
            ?? environment["HARMONY_NEXT_AUTOMATION_POLICY"].flatMap(TKHostRiskLevel.init(rawValue:))
        return TKHostExecutionPolicy(
            mode: explicitMode ?? environmentMode ?? .readonly,
            target: target,
            artifactDir: artifactDir,
            redactionPolicy: redactionPolicy,
            timeoutSeconds: timeoutSeconds,
            audit: audit
        )
    }

    public func provides(_ config: TKHostRequiredConfig) -> Bool {
        switch config {
        case .target:
            return !(target?.isEmpty ?? true)
        case .artifactDir:
            return !(artifactDir?.isEmpty ?? true)
        case .redactionPolicy:
            return !(redactionPolicy?.isEmpty ?? true)
        case .timeout:
            return timeoutSeconds != nil
        case .auditRecord:
            return audit
        }
    }
}

public enum TKSimctlCommand {
    public static func listAvailableDevices() -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "list", "devices", "available", "--json"])
    }

    public static func boot(udid: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "boot", udid], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func shutdown(udid: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "shutdown", udid], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func erase(udid: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "erase", udid], riskLevel: .breakGlass, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func screenshot(udid: String, output: String) -> TKHostCommand {
        TKHostCommand(
            arguments: ["simctl", "io", udid, "screenshot", output],
            riskLevel: .evidence,
            requiredConfig: [.artifactDir, .redactionPolicy, .timeout, .auditRecord],
            capturesArtifacts: true,
            sensitiveOutput: true
        )
    }

    public static func appInfo(udid: String, bundleID: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "appinfo", udid, bundleID])
    }

    public static func listApps(udid: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "listapps", udid])
    }

    public static func installApp(udid: String, appPath: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "install", udid, appPath], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func uninstallApp(udid: String, bundleID: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "uninstall", udid, bundleID], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func launchApp(udid: String, bundleID: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "launch", udid, bundleID], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func terminateApp(udid: String, bundleID: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "terminate", udid, bundleID], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func openURL(udid: String, url: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "openurl", udid, url], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func appContainer(udid: String, bundleID: String, kind: TKHostAppContainerKind) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "get_app_container", udid, bundleID, kind.rawValue])
    }

    public static func installAppData(udid: String, xcappdata: String) -> TKHostCommand {
        TKHostCommand(arguments: ["simctl", "install_app_data", udid, xcappdata], riskLevel: .evidence, requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord], capturesArtifacts: true)
    }
}

public enum TKHarmonyHDCCommand {
    public static func version(executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-v"])
    }

    public static func listTargets(executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["list", "targets", "-v"])
    }

    public static func bootCompleted(target: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "param", "get", "bootevent.boot.completed"], riskLevel: .readonly, requiredConfig: [.target, .timeout])
    }

    public static func appInspect(target: String, bundleName: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "bm", "dump", "-n", bundleName], riskLevel: .readonly, requiredConfig: [.target, .timeout])
    }

    public static func appLaunch(target: String, bundleName: String, abilityName: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "aa", "start", "-b", bundleName, "-a", abilityName], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func inputText(target: String, text: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "uitest", "uiInput", "text", text], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }
}

public struct TKHarmonyTarget: Codable, Equatable {
    public let id: String
    public let target: String
    public let state: String
    public let transport: String
    public let isConnected: Bool
    public let source: String

    public init(target: String, state: String, transport: String = "hdc", source: String = "hdc") {
        self.id = "harmony:\(target)"
        self.target = target
        self.state = state
        self.transport = transport
        self.isConnected = state.lowercased() == "connected"
        self.source = source
    }
}

public enum TKHdcTargetListParser {
    public static func parse(_ text: String) -> [TKHarmonyTarget] {
        text.split(whereSeparator: \.isNewline)
            .compactMap { line -> TKHarmonyTarget? in
                let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count >= 2 else { return nil }
                guard parts[0].lowercased() != "connectkey" else { return nil }
                if parts.count >= 3, isKnownTransport(parts[1]), isKnownState(parts[2]) {
                    return TKHarmonyTarget(target: parts[0], state: parts[2], transport: parts[1])
                }
                return TKHarmonyTarget(target: parts[0], state: parts[1])
            }
    }

    public static func defaultTarget(from targets: [TKHarmonyTarget]) -> TKHarmonyTarget? {
        let connected = targets.filter(\.isConnected)
        return connected.count == 1 ? connected[0] : nil
    }

    private static func isKnownTransport(_ value: String) -> Bool {
        switch value.lowercased() {
        case "tcp", "usb", "bt", "uart":
            return true
        default:
            return false
        }
    }

    private static func isKnownState(_ value: String) -> Bool {
        switch value.lowercased() {
        case "connected", "offline", "unauthorized", "unknown":
            return true
        default:
            return false
        }
    }
}

public enum TKHarmonyBootCompletedParser {
    public static func isReady(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
}

public struct TKHostSimulatorTarget: Codable, Equatable {
    public let id: String
    public let udid: String
    public let name: String
    public let runtimeIdentifier: String
    public let platform: String
    public let runtime: String
    public let state: String
    public let isAvailable: Bool
    public let isBooted: Bool
    public let deviceTypeIdentifier: String?
    public let source: String

    public init(
        udid: String,
        name: String,
        runtimeIdentifier: String,
        state: String,
        isAvailable: Bool,
        deviceTypeIdentifier: String? = nil,
        source: String = "simctl"
    ) {
        self.id = "sim:\(udid)"
        self.udid = udid
        self.name = name
        self.runtimeIdentifier = runtimeIdentifier
        self.platform = TKHostSimulatorTarget.platformName(from: runtimeIdentifier)
        self.runtime = TKHostSimulatorTarget.runtimeName(from: runtimeIdentifier)
        self.state = state
        self.isAvailable = isAvailable
        self.isBooted = state.lowercased() == "booted"
        self.deviceTypeIdentifier = deviceTypeIdentifier
        self.source = source
    }

    static func platformName(from runtimeIdentifier: String) -> String {
        let raw = runtimeIdentifier.split(separator: ".").last.map(String.init) ?? runtimeIdentifier
        if raw.hasPrefix("iOS-") { return "iOS Simulator" }
        if raw.hasPrefix("watchOS-") { return "watchOS Simulator" }
        if raw.hasPrefix("tvOS-") { return "tvOS Simulator" }
        if raw.hasPrefix("xrOS-") || raw.hasPrefix("visionOS-") { return "visionOS Simulator" }
        return "Simulator"
    }

    static func runtimeName(from runtimeIdentifier: String) -> String {
        let raw = runtimeIdentifier.split(separator: ".").last.map(String.init) ?? runtimeIdentifier
        let prefixes = ["iOS", "watchOS", "tvOS", "xrOS", "visionOS"]
        for prefix in prefixes where raw.hasPrefix(prefix + "-") {
            let version = raw.dropFirst(prefix.count + 1).replacingOccurrences(of: "-", with: ".")
            let displayPrefix = prefix == "xrOS" ? "visionOS" : prefix
            return "\(displayPrefix) \(version)"
        }
        return raw.replacingOccurrences(of: "-", with: " ")
    }
}

public enum TKSimctlDeviceListParser {
    private struct Response: Decodable {
        let devices: [String: [Device]]
    }

    private struct Device: Decodable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool
        let deviceTypeIdentifier: String?
    }

    public static func parse(_ data: Data) throws -> [TKHostSimulatorTarget] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.devices.flatMap { runtimeIdentifier, devices in
            devices.map { device in
                TKHostSimulatorTarget(
                    udid: device.udid,
                    name: device.name,
                    runtimeIdentifier: runtimeIdentifier,
                    state: device.state,
                    isAvailable: device.isAvailable,
                    deviceTypeIdentifier: device.deviceTypeIdentifier
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.isBooted != rhs.isBooted { return lhs.isBooted && !rhs.isBooted }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

public struct TKHostInstalledApp: Codable, Equatable {
    public let bundleID: String
    public let displayName: String?
    public let name: String?
    public let executable: String?
    public let version: String?
    public let applicationType: String?
    public let path: String?
    public let bundleURL: String?
    public let bundleContainerURL: String?
    public let dataContainerURL: String?
    public let groupContainers: [String: String]
    public let tags: [String]

    public init(bundleID: String, info: [String: Any]) {
        self.bundleID = bundleID
        self.displayName = TKHostInstalledApp.stringValue(info["CFBundleDisplayName"])
        self.name = TKHostInstalledApp.stringValue(info["CFBundleName"])
        self.executable = TKHostInstalledApp.stringValue(info["CFBundleExecutable"])
        self.version = TKHostInstalledApp.stringValue(info["CFBundleVersion"])
        self.applicationType = TKHostInstalledApp.stringValue(info["ApplicationType"])
        self.path = TKHostInstalledApp.stringValue(info["Path"])
        self.bundleURL = TKHostInstalledApp.stringValue(info["Bundle"])
        self.bundleContainerURL = TKHostInstalledApp.stringValue(info["BundleContainer"])
        self.dataContainerURL = TKHostInstalledApp.stringValue(info["DataContainer"])
        self.groupContainers = (info["GroupContainers"] as? [String: Any] ?? [:])
            .compactMapValues(TKHostInstalledApp.stringValue)
        self.tags = (info["SBAppTags"] as? [Any] ?? []).compactMap(TKHostInstalledApp.stringValue)
    }

    fileprivate static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return value.boolValue ? "true" : "false"
            }
            return value.stringValue
        case let value?:
            return String(describing: value)
        case nil:
            return nil
        }
    }
}

public enum TKSimctlAppInfoParser {
    public static func parseList(_ data: Data) throws -> [TKHostInstalledApp] {
        let plist = try parseOpenStepPlist(data)
        guard let dictionary = plist as? [String: Any] else {
            throw TKSimctlAppInfoParserError.invalidRoot
        }
        return dictionary.compactMap { bundleID, value in
            guard let info = value as? [String: Any] else { return nil }
            return TKHostInstalledApp(bundleID: bundleID, info: info)
        }
        .sorted { $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending }
    }

    public static func parseAppInfo(_ data: Data, bundleID: String) throws -> TKHostInstalledApp {
        let plist = try parseOpenStepPlist(data)
        guard let info = plist as? [String: Any] else {
            throw TKSimctlAppInfoParserError.invalidRoot
        }
        let onlyEchoedBundleIdentifier = info.count == 1 && TKHostInstalledApp.stringValue(info["CFBundleIdentifier"]) == bundleID
        guard !info.isEmpty, !onlyEchoedBundleIdentifier else {
            throw TKSimctlAppInfoParserError.emptyInfo
        }
        return TKHostInstalledApp(bundleID: bundleID, info: info)
    }

    private static func parseOpenStepPlist(_ data: Data) throws -> Any {
        var format = PropertyListSerialization.PropertyListFormat.openStep
        return try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
    }
}

public enum TKSimctlAppInfoParserError: Error, Equatable {
    case invalidRoot
    case emptyInfo
}

public enum TKHostPreferenceValue: Codable, Equatable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case array([TKHostPreferenceValue])
    case dictionary([String: TKHostPreferenceValue])
    case data(String)

    public var kind: String {
        switch self {
        case .string: "string"
        case .bool: "bool"
        case .int: "int"
        case .double: "double"
        case .array: "array"
        case .dictionary: "dictionary"
        case .data: "data"
        }
    }
}

public struct TKHostPreferencesSnapshot: Codable, Equatable {
    public let bundleID: String
    public let plistPath: String
    public let preferences: [String: TKHostPreferenceValue]

    public init(bundleID: String, plistPath: String, data: Data) throws {
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw TKHostPreferencesError.invalidRoot
        }
        self.bundleID = bundleID
        self.plistPath = plistPath
        self.preferences = dictionary.compactMapValues(TKHostPreferencesSnapshot.preferenceValue)
    }

    public static func plistPath(dataContainer: String, bundleID: String) -> String {
        URL(fileURLWithPath: dataContainer)
            .appendingPathComponent("Library")
            .appendingPathComponent("Preferences")
            .appendingPathComponent("\(bundleID).plist")
            .path
    }

    public func value(forKey key: String) -> TKHostPreferenceValue? {
        preferences[key]
    }

    private static func preferenceValue(_ value: Any) -> TKHostPreferenceValue? {
        switch value {
        case let value as String:
            return .string(value)
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .int(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }
            let doubleValue = value.doubleValue
            if floor(doubleValue) == doubleValue {
                return .int(value.intValue)
            }
            return .double(doubleValue)
        case let value as Double:
            return .double(value)
        case let value as [Any]:
            return .array(value.compactMap(preferenceValue))
        case let value as [String: Any]:
            return .dictionary(value.compactMapValues(preferenceValue))
        case let value as Data:
            return .data(value.base64EncodedString())
        default:
            return nil
        }
    }
}

public enum TKHostPreferencesError: Error, Equatable {
    case invalidRoot
}
