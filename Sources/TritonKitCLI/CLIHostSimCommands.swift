import ArgumentParser
import Foundation
import TritonKitShared

// MARK: - Host-Side Simulator Commands

enum SimPrivacyAction: String, ExpressibleByArgument {
    case grant
    case revoke
    case reset
}

enum SimPrivacyService: String, ExpressibleByArgument {
    case all
    case calendar
    case contactsLimited = "contacts-limited"
    case contacts
    case location
    case locationAlways = "location-always"
    case photosAdd = "photos-add"
    case photos
    case mediaLibrary = "media-library"
    case microphone
    case motion
    case reminders
    case siri
}

enum SimPasteboardEndpoint: String, ExpressibleByArgument {
    case host
    case device
}

enum SimLogVerboseAction: String, ExpressibleByArgument {
    case enable
    case disable
}

enum SimLogStyle: String, ExpressibleByArgument {
    case `default`
    case syslog
    case json
    case ndjson
    case compact
}

enum SimLogLevel: String, ExpressibleByArgument {
    case `default`
    case info
    case debug
}

enum SimLogType: String, ExpressibleByArgument {
    case activity
    case log
    case trace
}

enum SimVideoCodec: String, ExpressibleByArgument {
    case h264
    case hevc
}

enum SimVideoMaskPolicy: String, ExpressibleByArgument {
    case ignored
    case alpha
    case black
}

enum SimUIAppearanceValue: String, ExpressibleByArgument {
    case light
    case dark
}

enum SimUIIncreaseContrastValue: String, ExpressibleByArgument {
    case enabled
    case disabled
}

enum SimUIContentSizeValue: String, ExpressibleByArgument {
    case increment
    case decrement
    case extraSmall = "extra-small"
    case small
    case medium
    case large
    case extraLarge = "extra-large"
    case extraExtraLarge = "extra-extra-large"
    case extraExtraExtraLarge = "extra-extra-extra-large"
    case accessibilityMedium = "accessibility-medium"
    case accessibilityLarge = "accessibility-large"
    case accessibilityExtraLarge = "accessibility-extra-large"
    case accessibilityExtraExtraLarge = "accessibility-extra-extra-large"
    case accessibilityExtraExtraExtraLarge = "accessibility-extra-extra-extra-large"
}

private func isValidSimctlCoordinate(_ value: String) -> Bool {
    let components = value.split(separator: ",", omittingEmptySubsequences: false)
    guard components.count == 2 else { return false }
    let trimmed = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard
        let latitude = Double(trimmed[0]),
        let longitude = Double(trimmed[1])
    else {
        return false
    }
    return (-90...90).contains(latitude) && (-180...180).contains(longitude)
}

struct Sim: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sim",
        abstract: "Control iOS simulators through host-side Apple tools",
        subcommands: [
            SimList.self,
            SimUse.self,
            SimBoot.self,
            SimShutdown.self,
            SimPair.self,
            SimUnpair.self,
            SimClone.self,
            SimErase.self,
            SimUpgrade.self,
            SimScreenshot.self,
            SimRecord.self,
            SimLogs.self,
            SimDiagnose.self,
            SimLogVerbose.self,
            SimProxy.self,
            SimRuntime.self,
            SimStatusBar.self,
            SimPrivacy.self,
            SimLocation.self,
            SimUI.self,
            SimPasteboard.self,
            SimPush.self,
            SimPersonalization.self,
        ]
    )
}

struct SimProxy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "proxy",
        abstract: "Alias iOS Simulator network proxy takeover to device proxy",
        subcommands: [SimProxyDoctor.self, SimProxyStart.self, SimProxyStatus.self, SimProxyExport.self, SimProxyStop.self]
    )
}

struct SimProxyDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Probe iOS Simulator proxy takeover prerequisites")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printNetworkProxySession(makeNetworkProxyDoctorSession(platform: .ios), outputFormat: effectiveFormat(format, json: json))
    }
}

struct SimProxyStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Start an iOS Simulator host-side proxy takeover session when supported")

    @Option(help: "Simulator UDID or booted target selector") var simulator: String = "booted"
    @Option(help: "Capture mode: record|mock|block|throttle") var mode: String = "record"
    @Option(help: "Capture output directory") var output: String?
    @Option(help: "Local proxy endpoint host:port") var proxy: String = "127.0.0.1:19431"
    @Flag(help: "Return iOS Simulator proxy command plan without changing host settings") var planOnly = false
    @Flag(help: "Confirm break-glass proxy mutation after inspecting --plan-only output") var confirm = false
    @Option(help: "Audit record id required for break-glass proxy mutation") var auditRecord: String?
    @Flag(help: "Execute the break-glass proxy command runner after plan review, confirmation, and audit metadata") var executeRunner = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let endpoint = try NetworkProxyEndpoint(proxy)
        let target = try makeNetworkProxyPlanTarget(platform: .ios, device: simulator)
        if planOnly {
            try printNetworkProxySession(
                try makeNetworkProxyStartPlanSession(platform: .ios, target: target, captureMode: mode, endpoint: endpoint),
                outputFormat: outputFormat
            )
            return
        }
        guard confirm, let auditRecord, !auditRecord.isEmpty, executeRunner else {
            try printNetworkProxySession(
                try makeNetworkProxyExecutionPolicyRequiredSession(action: .start, platform: .ios, target: target, captureMode: mode, confirm: confirm, auditRecord: auditRecord, executeRunner: executeRunner),
                outputFormat: outputFormat
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyStartExecutedSession(platform: .ios, target: target, captureMode: mode, endpoint: endpoint, auditRecord: auditRecord, runner: { command in try runHostCommand(command) }, outputDirectory: output),
            outputFormat: outputFormat
        )
    }
}

struct SimProxyStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Inspect iOS Simulator host-side proxy takeover state")

    @Option(help: "Simulator UDID or booted target selector") var simulator: String = "booted"
    @Option(help: "Proxy session directory produced by proxy start --output") var session: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let target = try makeNetworkProxyPlanTarget(platform: .ios, device: simulator)
        if let session, !session.isEmpty {
            try printNetworkProxySession(
                try makeNetworkProxyStatusSession(platform: .ios, target: target, sessionDirectory: session),
                outputFormat: effectiveFormat(format, json: json)
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyStatusProbeSession(platform: .ios, target: target, runner: { command in try runHostCommand(command) }),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct SimProxyExport: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "export", abstract: "Export an iOS Simulator proxy capture when a session exists")

    @Option(help: "Simulator UDID or booted target selector") var simulator: String = "booted"
    @Option(help: "HAR or NDJSON output path") var output: String?
    @Option(help: "Proxy session directory produced by proxy start --output") var session: String?
    @Flag(help: "Return network capture artifact plan without writing files") var planOnly = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let target = try makeNetworkProxyPlanTarget(platform: .ios, device: simulator)
        if planOnly {
            let outputPath = try makeNetworkProxyExportPlanOutputPath(output)
            try printNetworkProxySession(
                try makeNetworkProxyExportPlanSession(platform: .ios, target: target, outputPath: outputPath),
                outputFormat: effectiveFormat(format, json: json)
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyExportSession(platform: .ios, target: target, sessionDirectory: session, outputPath: output),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct SimProxyStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop an iOS Simulator host-side proxy takeover session and restore settings")

    @Option(help: "Simulator UDID or booted target selector") var simulator: String = "booted"
    @Flag(help: "Restore simulator proxy settings") var restore = false
    @Flag(help: "Return iOS Simulator restore command plan without changing host settings") var planOnly = false
    @Flag(help: "Confirm break-glass proxy restore after inspecting --plan-only output") var confirm = false
    @Option(help: "Audit record id required for break-glass proxy restore") var auditRecord: String?
    @Flag(help: "Execute the break-glass proxy restore runner after plan review, confirmation, and audit metadata") var executeRunner = false
    @Option(help: "Restore snapshot path produced by proxy start") var restoreSnapshot: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let target = try makeNetworkProxyPlanTarget(platform: .ios, device: simulator)
        if planOnly {
            try printNetworkProxySession(
                try makeNetworkProxyStopPlanSession(
                    platform: .ios,
                    target: target,
                    restore: restore,
                    restoreSnapshotPath: restoreSnapshot
                ),
                outputFormat: outputFormat
            )
            return
        }
        guard confirm, let auditRecord, !auditRecord.isEmpty, executeRunner else {
            try printNetworkProxySession(
                try makeNetworkProxyExecutionPolicyRequiredSession(action: .stop, platform: .ios, target: target, captureMode: nil, confirm: confirm, auditRecord: auditRecord, executeRunner: executeRunner),
                outputFormat: outputFormat
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyStopExecutedSession(platform: .ios, target: target, restore: restore, auditRecord: auditRecord, runner: { command in try runHostCommand(command) }, restoreSnapshotPath: restoreSnapshot),
            outputFormat: outputFormat
        )
    }
}

struct SimList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List available simulators")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
            let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostSimulatorListOutput(ok: true, simulators: simulators)))
            case .text:
                for simulator in simulators {
                    print("\(simulator.udid)\t\(simulator.state)\t\(simulator.runtime)\t\(simulator.name)")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Set the workspace default simulator")

    @Argument(help: "Simulator UDID") var udid: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
            let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
            guard let simulator = simulators.first(where: { $0.udid == udid || $0.id == udid }) else {
                throw HostSimulatorRunError.simulatorNotFound(udid)
            }
            let existing = (try? loadHostWorkspaceDefaults()) ?? TKHostWorkspaceDefaults()
            let defaults = TKHostWorkspaceDefaults(defaultSimulatorUDID: simulator.udid, xcode: existing.xcode)
            let path = try saveHostWorkspaceDefaults(defaults)
            let output = HostSimulatorUseOutput(
                ok: true,
                action: "sim.use",
                simulator: simulator,
                defaultsPath: path
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(simulator.udid)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimBoot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "boot", abstract: "Boot a simulator")

    @Argument(help: "Simulator UDID") var udid: String
    @Flag(help: "Wait until the simulator reports Booted") var wait = false
    @Flag(help: "Emit compact JSON lines while waiting") var jsonl = false
    @Option(help: "Timeout in seconds when --wait is set") var timeout: Double = 60
    @Option(help: "Polling interval in seconds when --wait is set") var interval: Double = 1
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard wait else {
            try runSimpleHostCommand(
                action: "sim.boot",
                target: "sim:\(udid)",
                command: TKSimctlCommand.boot(udid: udid),
                outputFormat: outputFormat,
                note: "Simulator boot was requested."
            )
            return
        }

        do {
            do {
                _ = try runHostCommand(TKSimctlCommand.boot(udid: udid))
            } catch {
                if !(try simulatorIsBooted(udid: udid)) {
                    throw error
                }
            }
            try await waitForSimulatorBoot(
                udid: udid,
                timeout: timeout,
                interval: interval,
                outputFormat: outputFormat,
                jsonl: jsonl
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimShutdown: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "shutdown", abstract: "Shutdown a simulator")

    @Argument(help: "Simulator UDID or booted") var udid: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.shutdown",
            target: "sim:\(udid)",
            command: TKSimctlCommand.shutdown(udid: udid),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator shutdown was requested."
        )
    }
}

struct SimScreenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Capture a host-side simulator framebuffer screenshot")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Output PNG path") var output: String
    @Option(help: "CoreSimulator display selector, for example internal, external, screen id, or display UUID") var display: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runHostSimulatorScreenshotCommand(
            simulator: simulator,
            command: TKSimctlCommand.screenshot(udid: simulator, output: output, display: display),
            outputPath: output,
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct SimRecord: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "record", abstract: "Record a host-side simulator video")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Output MOV path") var output: String
    @Option(help: "Recording duration in seconds before simctl is interrupted") var duration: Double = 10
    @Option(help: "Video codec: h264 or hevc") var codec: SimVideoCodec?
    @Option(help: "Display identifier or alias to record") var display: String?
    @Option(help: "Mask policy for non-rectangular displays") var mask: SimVideoMaskPolicy?
    @Flag(help: "Force overwrite of the output file") var force = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard duration > 0 else {
            try failHostValidation(
                code: "invalid_duration",
                message: "--duration must be greater than 0.",
                hint: "Pass a positive recording duration in seconds.",
                outputFormat: outputFormat
            )
        }
        try runSimpleHostCommand(
            action: "sim.record",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.recordVideo(
                udid: simulator,
                output: output,
                codec: codec?.rawValue,
                display: display,
                mask: mask?.rawValue,
                force: force,
                defaultTimeoutSeconds: duration + 30
            ),
            outputFormat: outputFormat,
            artifacts: [output],
            note: "Host-side simulator video recording was written.",
            interruptAfter: duration
        )
    }
}

struct SimLogs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "logs", abstract: "Capture bounded simulator OSLog stream output")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Output log path") var output: String
    @Option(help: "Capture duration in seconds") var duration: Double = 10
    @Option(help: "Log output style") var style: SimLogStyle = .ndjson
    @Option(help: "Log level") var level: SimLogLevel?
    @Option(help: "NSPredicate log filter") var predicate: String?
    @Option(help: "Limit stream to a log event type") var type: SimLogType?
    @Flag(help: "Annotate output with source file and line-number") var source = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard duration > 0 else {
            try failHostValidation(
                code: "invalid_duration",
                message: "--duration must be greater than 0.",
                hint: "Pass a positive log capture duration in seconds.",
                outputFormat: outputFormat
            )
        }
        try runHostCommandCapturingStdoutArtifact(
            action: "sim.logs",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.logStream(
                udid: simulator,
                duration: duration,
                style: style.rawValue,
                level: level?.rawValue,
                predicate: predicate,
                source: source,
                type: type?.rawValue
            ),
            outputPath: output,
            outputFormat: outputFormat,
            note: "Bounded simulator log stream was written."
        )
    }
}

struct SimDiagnose: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "diagnose", abstract: "Collect simulator diagnostic information and logs")

    @Option(name: .customLong("output"), help: "Output directory or archive path") var output: String?
    @Option(name: .customLong("timeout"), help: "Timeout in seconds") var timeout: Double = 300
    @Flag(name: .customLong("no-archive"), help: "Do not archive collected diagnostics") var noArchive = false
    @Flag(name: .customLong("all-logs"), help: "Include all device logs") var allLogs = false
    @Flag(name: .customLong("data-containers"), help: "Include booted device data containers") var dataContainers = false
    @Option(name: .customLong("udid"), help: "Simulator UDID to include in the diagnostics bundle") var udids: [String] = []
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.diagnose",
            target: udids.isEmpty ? "sim:booted" : "sim:\(udids.joined(separator: ","))",
            command: TKSimctlCommand.diagnose(
                output: output,
                timeout: timeout,
                noArchive: noArchive,
                allLogs: allLogs,
                dataContainers: dataContainers,
                udids: udids
            ),
            outputFormat: effectiveFormat(format, json: json),
            artifacts: output.map { [$0] } ?? [],
            note: "Simulator diagnostics collection was submitted."
        )
    }
}

struct SimLogVerbose: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "logverbose", abstract: "Enable or disable verbose simulator logging")

    @Option(name: .customLong("simulator"), help: "Simulator UDID or booted; omit to affect all booted devices") var simulator: String?
    @Argument(help: "Verbose logging state") var action: SimLogVerboseAction
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.logverbose.\(action.rawValue)",
            target: simulator.map { "sim:\($0)" } ?? "sim:booted",
            command: TKSimctlCommand.logVerbose(udid: simulator, enabled: action == .enable),
            outputFormat: effectiveFormat(format, json: json),
            note: action == .enable ? "Verbose logging was enabled." : "Verbose logging was disabled."
        )
    }
}

struct SimStatusBar: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status-bar",
        abstract: "Read or override the simulator status bar",
        subcommands: [SimStatusBarList.self, SimStatusBarClear.self, SimStatusBarOverride.self]
    )
}

struct SimStatusBarList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List existing status bar overrides")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.status-bar.list",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.statusBarList(udid: simulator),
            outputFormat: effectiveFormat(format, json: json),
            note: "Status bar override values were read from the simulator."
        )
    }
}

struct SimStatusBarClear: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clear", abstract: "Clear simulator status bar overrides")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.status-bar.clear",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.statusBarClear(udid: simulator),
            outputFormat: effectiveFormat(format, json: json),
            note: "Status bar overrides were cleared on the simulator."
        )
    }
}

struct SimStatusBarOverride: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "override", abstract: "Set simulator status bar override values")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(name: .customLong("time"), help: "Set the date or time to a fixed value") var time: String?
    @Option(name: .customLong("dataNetwork"), help: "Set the data network type") var dataNetwork: String?
    @Option(name: .customLong("wifiMode"), help: "Set the Wi-Fi mode") var wifiMode: String?
    @Option(name: .customLong("wifiBars"), help: "Set Wi-Fi bars from 0 to 3") var wifiBars: Int?
    @Option(name: .customLong("cellularMode"), help: "Set the cellular mode") var cellularMode: String?
    @Option(name: .customLong("cellularBars"), help: "Set cellular bars from 0 to 4") var cellularBars: Int?
    @Option(name: .customLong("operatorName"), help: "Set the carrier name") var operatorName: String?
    @Option(name: .customLong("batteryState"), help: "Set the battery state") var batteryState: String?
    @Option(name: .customLong("batteryLevel"), help: "Set the battery level from 0 to 100") var batteryLevel: Int?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        guard [
            time != nil,
            dataNetwork != nil,
            wifiMode != nil,
            wifiBars != nil,
            cellularMode != nil,
            cellularBars != nil,
            operatorName != nil,
            batteryState != nil,
            batteryLevel != nil,
        ].contains(true) else {
            try failHostValidation(
                code: "validation_failed",
                message: "status-bar override requires at least one override value.",
                hint: "Pass --time, --dataNetwork, --wifiMode, --wifiBars, --cellularMode, --cellularBars, --operatorName, --batteryState, or --batteryLevel.",
                outputFormat: effectiveFormat(format, json: json)
            )
        }
        try runSimpleHostCommand(
            action: "sim.status-bar.override",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.statusBarOverride(
                udid: simulator,
                time: time,
                dataNetwork: dataNetwork,
                wifiMode: wifiMode,
                wifiBars: wifiBars,
                cellularMode: cellularMode,
                cellularBars: cellularBars,
                operatorName: operatorName,
                batteryState: batteryState,
                batteryLevel: batteryLevel
            ),
            outputFormat: effectiveFormat(format, json: json),
            note: "Status bar override values were submitted to the simulator."
        )
    }
}

struct SimPrivacy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "privacy",
        abstract: "Grant, revoke, or reset simulator privacy permissions",
        subcommands: [SimPrivacyGrant.self, SimPrivacyRevoke.self, SimPrivacyReset.self]
    )
}

struct SimPrivacyGrant: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "grant", abstract: "Grant a simulator privacy permission")

    @Argument(help: "Privacy service") var service: SimPrivacyService
    @Argument(help: "Bundle identifier") var bundleID: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.privacy.grant",
            target: "sim:\(simulator)/app:\(bundleID)",
            command: TKSimctlCommand.privacy(udid: simulator, action: SimPrivacyAction.grant.rawValue, service: service.rawValue, bundleID: bundleID),
            outputFormat: effectiveFormat(format, json: json),
            note: "Privacy permission grant was submitted to the simulator."
        )
    }
}

struct SimPrivacyRevoke: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "revoke", abstract: "Revoke a simulator privacy permission")

    @Argument(help: "Privacy service") var service: SimPrivacyService
    @Argument(help: "Bundle identifier") var bundleID: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.privacy.revoke",
            target: "sim:\(simulator)/app:\(bundleID)",
            command: TKSimctlCommand.privacy(udid: simulator, action: SimPrivacyAction.revoke.rawValue, service: service.rawValue, bundleID: bundleID),
            outputFormat: effectiveFormat(format, json: json),
            note: "Privacy permission revoke was submitted to the simulator."
        )
    }
}

struct SimPrivacyReset: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reset", abstract: "Reset simulator privacy permissions")

    @Argument(help: "Privacy service") var service: SimPrivacyService
    @Argument(help: "Bundle identifier, when resetting one app") var bundleID: String?
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.privacy.reset",
            target: bundleID.map { "sim:\(simulator)/app:\($0)" } ?? "sim:\(simulator)",
            command: TKSimctlCommand.privacy(udid: simulator, action: SimPrivacyAction.reset.rawValue, service: service.rawValue, bundleID: bundleID),
            outputFormat: effectiveFormat(format, json: json),
            note: "Privacy permission reset was submitted to the simulator."
        )
    }
}

struct SimLocation: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "location",
        abstract: "Control simulated location",
        subcommands: [SimLocationList.self, SimLocationClear.self, SimLocationSet.self, SimLocationRun.self, SimLocationStart.self]
    )
}

struct SimLocationList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List available simulated location scenarios")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.location.list",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.locationList(udid: simulator),
            outputFormat: effectiveFormat(format, json: json),
            note: "Available simulated location scenarios were listed."
        )
    }
}

struct SimLocationClear: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clear", abstract: "Clear simulated location")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.location.clear",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.locationClear(udid: simulator),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulated location was cleared."
        )
    }
}

struct SimLocationSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set a simulated location coordinate")

    @Argument(help: "Latitude and longitude as <lat>,<lon>") var coordinate: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        guard isValidSimctlCoordinate(coordinate) else {
            try failHostValidation(
                code: "invalid_location_value",
                message: "Invalid simulated location coordinate: \(coordinate)",
                hint: "Pass <lat>,<lon> with decimal points and valid latitude/longitude bounds.",
                outputFormat: effectiveFormat(format, json: json)
            )
        }
        try runSimpleHostCommand(
            action: "sim.location.set",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.locationSet(udid: simulator, coordinate: coordinate),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulated location was updated to the requested coordinate."
        )
    }
}

struct SimLocationRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Run a simulated location scenario")

    @Argument(help: "Scenario name") var scenario: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.location.run",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.locationRun(udid: simulator, scenario: scenario),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulated location scenario was started."
        )
    }
}

struct SimLocationStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Run a waypoint-based simulated route")

    @Argument(help: "Latitude and longitude waypoints as <lat>,<lon>") var waypoints: [String]
    @Option(name: .customLong("speed"), help: "Speed in meters per second") var speed: Double?
    @Option(name: .customLong("distance"), help: "Distance between updates in meters") var distance: Double?
    @Option(name: .customLong("interval"), help: "Interval between updates in seconds") var interval: Double?
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        guard waypoints.count >= 2, waypoints.allSatisfy(isValidSimctlCoordinate) else {
            try failHostValidation(
                code: "invalid_location_value",
                message: "location start requires at least two valid <lat>,<lon> waypoints.",
                hint: "Pass two or more waypoints such as 37.629538,-122.395733 40.628083,-73.768254.",
                outputFormat: effectiveFormat(format, json: json)
            )
        }
        try runSimpleHostCommand(
            action: "sim.location.start",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.locationStart(udid: simulator, waypoints: waypoints, speed: speed, distance: distance, interval: interval),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulated location route was started."
        )
    }
}

struct SimUI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ui",
        abstract: "Read or set simulator UI appearance and accessibility settings",
        subcommands: [SimUIAppearance.self, SimUIIncreaseContrast.self, SimUIContentSize.self]
    )
}

struct SimUIAppearance: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "appearance", abstract: "Get or set the simulator appearance style")

    @Argument(help: "Appearance style, omit to query current state") var value: SimUIAppearanceValue?
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: value == nil ? "sim.ui.appearance.get" : "sim.ui.appearance.set",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.uiAppearance(udid: simulator, value: value?.rawValue),
            outputFormat: effectiveFormat(format, json: json),
            note: value == nil ? "Current simulator appearance was read." : "Simulator appearance was updated."
        )
    }
}

struct SimUIIncreaseContrast: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "increase-contrast", abstract: "Get or set Increase Contrast")

    @Argument(help: "Increase Contrast value, omit to query current state") var value: SimUIIncreaseContrastValue?
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: value == nil ? "sim.ui.increase-contrast.get" : "sim.ui.increase-contrast.set",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.uiIncreaseContrast(udid: simulator, value: value?.rawValue),
            outputFormat: effectiveFormat(format, json: json),
            note: value == nil ? "Current Increase Contrast state was read." : "Increase Contrast state was updated."
        )
    }
}

struct SimUIContentSize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "content-size", abstract: "Get or set the preferred content size category")

    @Argument(help: "Content size value, omit to query current state") var value: SimUIContentSizeValue?
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: value == nil ? "sim.ui.content-size.get" : "sim.ui.content-size.set",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.uiContentSize(udid: simulator, value: value?.rawValue),
            outputFormat: effectiveFormat(format, json: json),
            note: value == nil ? "Current preferred content size was read." : "Preferred content size was updated."
        )
    }
}

struct SimPasteboard: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pasteboard",
        abstract: "Read, write, or sync simulator pasteboard content",
        subcommands: [SimPasteboardSet.self, SimPasteboardGet.self, SimPasteboardSync.self]
    )
}

struct SimPasteboardSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Copy text onto the simulator pasteboard")

    @Argument(help: "Text to copy") var text: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Emit verbose simctl diagnostics") var verbose = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.pasteboard.set",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.pasteboardCopy(udid: simulator, text: text, verbose: verbose),
            outputFormat: effectiveFormat(format, json: json),
            note: "Pasteboard text was copied onto the simulator."
        )
    }
}

struct SimPasteboardGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read simulator pasteboard content")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.pasteboard.get",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.pasteboardPaste(udid: simulator),
            outputFormat: effectiveFormat(format, json: json),
            note: "Pasteboard text was read from the simulator."
        )
    }
}

struct SimPasteboardSync: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync", abstract: "Sync pasteboard content between host and simulator")

    @Argument(help: "Source pasteboard: host or device") var source: SimPasteboardEndpoint
    @Argument(help: "Destination pasteboard: host or device") var destination: SimPasteboardEndpoint
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Use promise data for secondary types") var promises = false
    @Flag(help: "Emit verbose simctl diagnostics") var verbose = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let sourceValue = source == .device ? simulator : source.rawValue
        let destinationValue = destination == .device ? simulator : destination.rawValue
        try runSimpleHostCommand(
            action: "sim.pasteboard.sync",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.pasteboardSync(source: sourceValue, destination: destinationValue, promises: promises, verbose: verbose),
            outputFormat: effectiveFormat(format, json: json),
            note: "Pasteboard content was synchronized."
        )
    }
}

struct SimPush: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "push", abstract: "Send a simulated push notification")

    @Option(name: .customLong("bundle-id"), help: "Bundle identifier") var bundleID: String?
    @Option(help: "JSON payload file or '-' for stdin") var payload: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.push",
            target: bundleID.map { "sim:\(simulator)/app:\($0)" } ?? "sim:\(simulator)",
            command: TKSimctlCommand.push(udid: simulator, bundleID: bundleID, payload: payload),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulated push notification was submitted."
        )
    }
}
