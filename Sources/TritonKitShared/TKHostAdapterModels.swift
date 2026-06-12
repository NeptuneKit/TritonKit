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
    public let stdinData: Data?

    public init(
        executable: String = "xcrun",
        arguments: [String],
        riskLevel: TKHostRiskLevel = .readonly,
        requiredConfig: Set<TKHostRequiredConfig> = [.timeout],
        defaultTimeoutSeconds: Double = 30,
        capturesArtifacts: Bool = false,
        sensitiveOutput: Bool = false,
        stdinData: Data? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.riskLevel = riskLevel
        self.requiredConfig = requiredConfig
        self.defaultTimeoutSeconds = defaultTimeoutSeconds
        self.capturesArtifacts = capturesArtifacts
        self.sensitiveOutput = sensitiveOutput
        self.stdinData = stdinData
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
            sensitiveOutput: sensitiveOutput,
            stdinData: stdinData
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
    private static func command(
        _ arguments: [String],
        riskLevel: TKHostRiskLevel = .readonly,
        requiredConfig: Set<TKHostRequiredConfig> = [.timeout],
        defaultTimeoutSeconds: Double = 30,
        capturesArtifacts: Bool = false,
        sensitiveOutput: Bool = false,
        stdinData: Data? = nil
    ) -> TKHostCommand {
        TKHostCommand(
            arguments: arguments,
            riskLevel: riskLevel,
            requiredConfig: requiredConfig,
            defaultTimeoutSeconds: defaultTimeoutSeconds,
            capturesArtifacts: capturesArtifacts,
            sensitiveOutput: sensitiveOutput,
            stdinData: stdinData
        )
    }

    public static func listAvailableDevices() -> TKHostCommand {
        command(["simctl", "list", "devices", "available", "--json"])
    }

    public static func diagnose(
        output: String? = nil,
        timeout: Double? = 300,
        noArchive: Bool = false,
        allLogs: Bool = false,
        dataContainers: Bool = false,
        udids: [String] = []
    ) -> TKHostCommand {
        var arguments = ["simctl", "diagnose"]
        if let timeout {
            arguments += ["--timeout", "\(timeout)"]
        }
        if let output {
            arguments += ["--output", output]
        }
        if noArchive {
            arguments.append("--no-archive")
        }
        if allLogs {
            arguments.append("--all-logs")
        }
        if dataContainers {
            arguments.append("--data-containers")
        }
        for udid in udids {
            arguments += ["--udid", udid]
        }
        return command(arguments, riskLevel: .diagnostic, requiredConfig: [.timeout, .auditRecord], defaultTimeoutSeconds: timeout ?? 300, capturesArtifacts: output != nil, sensitiveOutput: true)
    }

    public static func recordVideo(
        udid: String,
        output: String,
        codec: String? = nil,
        display: String? = nil,
        mask: String? = nil,
        force: Bool = false,
        defaultTimeoutSeconds: Double = 600
    ) -> TKHostCommand {
        var arguments = ["simctl", "io", udid, "recordVideo"]
        if let codec {
            arguments.append("--codec=\(codec)")
        }
        if let display {
            arguments.append("--display=\(display)")
        }
        if let mask {
            arguments.append("--mask=\(mask)")
        }
        if force {
            arguments.append("--force")
        }
        arguments.append(output)
        return command(
            arguments,
            riskLevel: .evidence,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: defaultTimeoutSeconds,
            capturesArtifacts: true,
            sensitiveOutput: true
        )
    }

    public static func logStream(
        udid: String,
        duration: Double,
        style: String = "ndjson",
        level: String? = nil,
        predicate: String? = nil,
        source: Bool = false,
        type: String? = nil,
        defaultTimeoutSeconds: Double? = nil
    ) -> TKHostCommand {
        let timeout = max(1, Int(ceil(duration)))
        var arguments = ["simctl", "spawn", udid, "log", "stream", "--style", style, "--timeout", "\(timeout)"]
        if let level {
            arguments += ["--level", level]
        }
        if let predicate {
            arguments += ["--predicate", predicate]
        }
        if source {
            arguments.append("--source")
        }
        if let type {
            arguments += ["--type", type]
        }
        return command(
            arguments,
            riskLevel: .evidence,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: defaultTimeoutSeconds ?? duration + 10,
            capturesArtifacts: true,
            sensitiveOutput: true
        )
    }

    public static func logVerbose(udid: String? = nil, enabled: Bool) -> TKHostCommand {
        var arguments = ["simctl", "logverbose"]
        if let udid {
            arguments.append(udid)
        }
        arguments.append(enabled ? "enable" : "disable")
        return command(arguments, riskLevel: .diagnostic, requiredConfig: udid == nil ? [.timeout, .auditRecord] : [.target, .timeout, .auditRecord])
    }

    public static func boot(udid: String) -> TKHostCommand {
        command(["simctl", "boot", udid], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func shutdown(udid: String) -> TKHostCommand {
        command(["simctl", "shutdown", udid], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func pair(watchDevice: String, phoneDevice: String) -> TKHostCommand {
        command(["simctl", "pair", watchDevice, phoneDevice], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func unpair(pairUUID: String) -> TKHostCommand {
        command(["simctl", "unpair", pairUUID], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func clone(device: String, newName: String, destinationDeviceSet: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "clone", device, newName]
        if let destinationDeviceSet {
            arguments.append(destinationDeviceSet)
        }
        return command(arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func erase(udid: String) -> TKHostCommand {
        command(["simctl", "erase", udid], riskLevel: .breakGlass, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func upgrade(device: String, runtimeIdentifier: String) -> TKHostCommand {
        command(["simctl", "upgrade", device, runtimeIdentifier], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func screenshot(udid: String, output: String, display: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "io", udid, "screenshot"]
        if let display {
            arguments.append("--display=\(display)")
        }
        arguments.append(output)
        return command(
            arguments,
            riskLevel: .evidence,
            requiredConfig: [.artifactDir, .redactionPolicy, .timeout, .auditRecord],
            capturesArtifacts: true,
            sensitiveOutput: true
        )
    }

    public static func appInfo(udid: String, bundleID: String) -> TKHostCommand {
        command(["simctl", "appinfo", udid, bundleID])
    }

    public static func listApps(udid: String) -> TKHostCommand {
        command(["simctl", "listapps", udid])
    }

    public static func installApp(udid: String, appPath: String) -> TKHostCommand {
        command(["simctl", "install", udid, appPath], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func uninstallApp(udid: String, bundleID: String) -> TKHostCommand {
        command(["simctl", "uninstall", udid, bundleID], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func launchApp(udid: String, bundleID: String) -> TKHostCommand {
        command(["simctl", "launch", udid, bundleID], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func terminateApp(udid: String, bundleID: String) -> TKHostCommand {
        command(["simctl", "terminate", udid, bundleID], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func openURL(udid: String, url: String) -> TKHostCommand {
        command(["simctl", "openurl", udid, url], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func appContainer(udid: String, bundleID: String, kind: TKHostAppContainerKind) -> TKHostCommand {
        command(["simctl", "get_app_container", udid, bundleID, kind.rawValue])
    }

    public static func installAppData(udid: String, xcappdata: String) -> TKHostCommand {
        command(["simctl", "install_app_data", udid, xcappdata], riskLevel: .evidence, requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord], capturesArtifacts: true)
    }

    public static func statusBarList(udid: String) -> TKHostCommand {
        command(["simctl", "status_bar", udid, "list"])
    }

    public static func statusBarClear(udid: String) -> TKHostCommand {
        command(["simctl", "status_bar", udid, "clear"], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func statusBarOverride(
        udid: String,
        time: String? = nil,
        dataNetwork: String? = nil,
        wifiMode: String? = nil,
        wifiBars: Int? = nil,
        cellularMode: String? = nil,
        cellularBars: Int? = nil,
        operatorName: String? = nil,
        batteryState: String? = nil,
        batteryLevel: Int? = nil
    ) -> TKHostCommand {
        var arguments = ["simctl", "status_bar", udid, "override"]
        if let time { arguments += ["--time", time] }
        if let dataNetwork { arguments += ["--dataNetwork", dataNetwork] }
        if let wifiMode { arguments += ["--wifiMode", wifiMode] }
        if let wifiBars { arguments += ["--wifiBars", "\(wifiBars)"] }
        if let cellularMode { arguments += ["--cellularMode", cellularMode] }
        if let cellularBars { arguments += ["--cellularBars", "\(cellularBars)"] }
        if let operatorName { arguments += ["--operatorName", operatorName] }
        if let batteryState { arguments += ["--batteryState", batteryState] }
        if let batteryLevel { arguments += ["--batteryLevel", "\(batteryLevel)"] }
        return command(arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func privacy(udid: String, action: String, service: String, bundleID: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "privacy", udid, action, service]
        if let bundleID {
            arguments.append(bundleID)
        }
        return command(arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func locationList(udid: String) -> TKHostCommand {
        command(["simctl", "location", udid, "list"])
    }

    public static func locationClear(udid: String) -> TKHostCommand {
        command(["simctl", "location", udid, "clear"], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func locationSet(udid: String, coordinate: String) -> TKHostCommand {
        command(["simctl", "location", udid, "set", coordinate], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func locationRun(udid: String, scenario: String) -> TKHostCommand {
        command(["simctl", "location", udid, "run", scenario], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func locationStart(
        udid: String,
        waypoints: [String],
        speed: Double? = nil,
        distance: Double? = nil,
        interval: Double? = nil
    ) -> TKHostCommand {
        var arguments = ["simctl", "location", udid, "start"]
        if let speed { arguments.append("--speed=\(speed)") }
        if let distance { arguments.append("--distance=\(distance)") }
        if let interval { arguments.append("--interval=\(interval)") }
        arguments += waypoints
        return command(arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func uiAppearance(udid: String, value: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "ui", udid, "appearance"]
        if let value {
            arguments.append(value)
        }
        return command(arguments, riskLevel: value == nil ? .readonly : .automation, requiredConfig: value == nil ? [.timeout] : [.target, .timeout, .auditRecord])
    }

    public static func uiIncreaseContrast(udid: String, value: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "ui", udid, "increase_contrast"]
        if let value {
            arguments.append(value)
        }
        return command(arguments, riskLevel: value == nil ? .readonly : .automation, requiredConfig: value == nil ? [.timeout] : [.target, .timeout, .auditRecord])
    }

    public static func uiContentSize(udid: String, value: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "ui", udid, "content_size"]
        if let value {
            arguments.append(value)
        }
        return command(arguments, riskLevel: value == nil ? .readonly : .automation, requiredConfig: value == nil ? [.timeout] : [.target, .timeout, .auditRecord])
    }

    public static func pasteboardCopy(udid: String, text: String, verbose: Bool = false) -> TKHostCommand {
        var arguments = ["simctl", "pbcopy"]
        if verbose {
            arguments.append("-v")
        }
        arguments.append(udid)
        return command(arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord], stdinData: Data(text.utf8))
    }

    public static func pasteboardPaste(udid: String) -> TKHostCommand {
        command(["simctl", "pbpaste", udid])
    }

    public static func pasteboardSync(source: String, destination: String, promises: Bool = false, verbose: Bool = false) -> TKHostCommand {
        var arguments = ["simctl", "pbsync"]
        if promises {
            arguments.append("-p")
        }
        if verbose {
            arguments.append("-v")
        }
        arguments.append(source)
        arguments.append(destination)
        return command(arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func push(udid: String, bundleID: String? = nil, payload: String, stdinData: Data? = nil) -> TKHostCommand {
        var arguments = ["simctl", "push", udid]
        if let bundleID {
            arguments.append(bundleID)
        }
        arguments.append(payload)
        return command(arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord], stdinData: stdinData)
    }

    public static func runtimeList(verbose: Bool = false) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "list"]
        if verbose {
            arguments.append("-v")
        }
        arguments.append("-j")
        return command(arguments)
    }

    public static func runtimeVerify(identifier: String) -> TKHostCommand {
        command(["simctl", "runtime", "verify", identifier], riskLevel: .diagnostic, requiredConfig: [.timeout, .auditRecord])
    }

    public static func runtimeAdd(path: String, move: Bool = false, async: Bool = false) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "add", path]
        if move {
            arguments.append("--move")
        }
        if async {
            arguments.append("--async")
        }
        return command(arguments, riskLevel: .automation, requiredConfig: [.timeout, .auditRecord], defaultTimeoutSeconds: async ? 30 : 600)
    }

    public static func runtimeDelete(
        identifier: String? = nil,
        notUsedSinceDays: Int? = nil,
        dryRun: Bool = false,
        keepAsset: Bool = false
    ) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "delete"]
        if let identifier {
            arguments.append(identifier)
        } else if let notUsedSinceDays {
            arguments += ["--notUsedSinceDays", "\(notUsedSinceDays)"]
        }
        if dryRun {
            arguments.append("--dry-run")
        }
        if keepAsset {
            arguments.append("--keep-asset")
        }
        return command(
            arguments,
            riskLevel: dryRun ? .readonly : .breakGlass,
            requiredConfig: dryRun ? [.timeout] : [.timeout, .auditRecord],
            defaultTimeoutSeconds: 300
        )
    }

    public static func runtimeUnmount(identifier: String) -> TKHostCommand {
        command(["simctl", "runtime", "unmount", identifier], riskLevel: .automation, requiredConfig: [.timeout, .auditRecord], defaultTimeoutSeconds: 120)
    }

    public static func runtimeScanAndMount() -> TKHostCommand {
        command(["simctl", "runtime", "scan-and-mount"], riskLevel: .automation, requiredConfig: [.timeout, .auditRecord], defaultTimeoutSeconds: 300)
    }

    public static func runtimeMatchList(verbose: Bool = false) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "match", "list"]
        if verbose {
            arguments.append("-v")
        }
        arguments.append("-j")
        return command(arguments)
    }

    public static func runtimeMatchSet(sdkName: String, runtimeBuild: String, sdkBuild: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "match", "set", sdkName, runtimeBuild]
        if let sdkBuild {
            arguments += ["--sdkBuild", sdkBuild]
        }
        return command(arguments, riskLevel: .automation, requiredConfig: [.timeout, .auditRecord])
    }

    public static func runtimeMatchSetDefault(sdkName: String, sdkBuild: String? = nil) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "match", "set", sdkName, "--default"]
        if let sdkBuild {
            arguments += ["--sdkBuild", sdkBuild]
        }
        return command(arguments, riskLevel: .automation, requiredConfig: [.timeout, .auditRecord])
    }

    public static func runtimeDyldSharedCacheUpdate(runtime: String? = nil, all: Bool = false, force: Bool = false) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "dyld_shared_cache", "update"]
        if all {
            arguments.append("--all")
        } else if let runtime {
            arguments.append(runtime)
        }
        if force {
            arguments.append("--force")
        }
        return command(arguments, riskLevel: force ? .automation : .diagnostic, requiredConfig: [.timeout, .auditRecord], defaultTimeoutSeconds: 300)
    }

    public static func runtimeDyldSharedCacheRemove(runtime: String? = nil, all: Bool = false) -> TKHostCommand {
        var arguments = ["simctl", "runtime", "dyld_shared_cache", "remove"]
        if all {
            arguments.append("--all")
        } else if let runtime {
            arguments.append(runtime)
        }
        return command(arguments, riskLevel: .breakGlass, requiredConfig: [.timeout, .auditRecord], defaultTimeoutSeconds: 300)
    }

    public static func personalization(
        action: String,
        arguments personalizationArguments: [String] = [],
        riskLevel: TKHostRiskLevel = .diagnostic
    ) -> TKHostCommand {
        command(
            ["simctl", "personalization", action] + personalizationArguments,
            riskLevel: riskLevel,
            requiredConfig: riskLevel == .breakGlass ? [.timeout, .auditRecord] : [.timeout],
            defaultTimeoutSeconds: 300
        )
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

public struct TKHostSimulatorRuntime: Codable, Equatable {
    public let id: String
    public let identifier: String
    public let build: String
    public let deletable: Bool
    public let kind: String
    public let lastUsedAt: String?
    public let mountPath: String?
    public let parentMountPath: String?
    public let path: String
    public let platformIdentifier: String
    public let runtimeBundlePath: String
    public let runtimeIdentifier: String
    public let signatureState: String
    public let sizeBytes: Int64
    public let state: String
    public let supportedArchitectures: [String]
    public let version: String
    public let source: String

    fileprivate init(record: RuntimeRecord, source: String = "simctl") {
        self.id = "runtime:\(record.identifier)"
        self.identifier = record.identifier
        self.build = record.build
        self.deletable = record.deletable
        self.kind = record.kind
        self.lastUsedAt = record.lastUsedAt
        self.mountPath = record.mountPath
        self.parentMountPath = record.parentMountPath
        self.path = record.path
        self.platformIdentifier = record.platformIdentifier
        self.runtimeBundlePath = record.runtimeBundlePath
        self.runtimeIdentifier = record.runtimeIdentifier
        self.signatureState = record.signatureState
        self.sizeBytes = record.sizeBytes
        self.state = record.state
        self.supportedArchitectures = record.supportedArchitectures
        self.version = record.version
        self.source = source
    }
}

private struct RuntimeRecord: Decodable {
    let build: String
    let deletable: Bool
    let identifier: String
    let kind: String
    let lastUsedAt: String?
    let mountPath: String?
    let parentMountPath: String?
    let path: String
    let platformIdentifier: String
    let runtimeBundlePath: String
    let runtimeIdentifier: String
    let signatureState: String
    let sizeBytes: Int64
    let state: String
    let supportedArchitectures: [String]
    let version: String
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

public enum TKSimctlRuntimeListParser {
    public static func parse(_ data: Data) throws -> [TKHostSimulatorRuntime] {
        let runtimes = try JSONDecoder().decode([String: RuntimeRecord].self, from: data)
        return runtimes.values
            .map { TKHostSimulatorRuntime(record: $0) }
            .sorted { lhs, rhs in
                lhs.identifier.localizedStandardCompare(rhs.identifier) == .orderedAscending
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([TKHostPreferenceValue].self) {
            self = .array(value)
        } else if let envelope = try? container.decode(TKHostPreferenceDataEnvelope.self), envelope.plistType == "data" {
            self = .data(envelope.base64)
        } else if let legacyEnvelope = try? container.decode([String: String].self), let data = legacyEnvelope["data"] {
            self = .data(data)
        } else if let value = try? container.decode([String: TKHostPreferenceValue].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported host preference value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .dictionary(let values):
            try container.encode(values)
        case .data(let value):
            let byteCount = Data(base64Encoded: value)?.count ?? 0
            try container.encode(TKHostPreferenceDataEnvelope(plistType: "data", base64: value, length: byteCount))
        }
    }
}

private struct TKHostPreferenceDataEnvelope: Codable, Equatable {
    let plistType: String
    let base64: String
    let length: Int
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
