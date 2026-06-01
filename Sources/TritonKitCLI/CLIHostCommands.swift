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

func requireConfirmation(
    _ confirmed: Bool,
    action: String,
    hint: String,
    outputFormat: ClientOutputFormat
) throws {
    guard confirmed else {
        try failHostValidation(
            code: "confirmation_required",
            message: "\(action) requires --confirm.",
            hint: hint,
            outputFormat: outputFormat
        )
    }
}

func requireExactlyOneSelector(
    selected: Int,
    code: String,
    message: String,
    hint: String,
    outputFormat: ClientOutputFormat
) throws {
    guard selected == 1 else {
        try failHostValidation(code: code, message: message, hint: hint, outputFormat: outputFormat)
    }
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
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.screenshot",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.screenshot(udid: simulator, output: output),
            outputFormat: effectiveFormat(format, json: json),
            artifacts: [output],
            note: "Host-side simulator screenshot was written."
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

// MARK: - Host-Side App Commands

enum HostAppPlatform: String, ExpressibleByArgument {
    case ios
    case harmony
}

private func hostDevicePlatform(from platform: HostAppPlatform) -> HostDevicePlatform {
    switch platform {
    case .ios:
        return .ios
    case .harmony:
        return .harmony
    }
}

private func hostAppPlatform(from platform: HostDevicePlatform) -> HostAppPlatform {
    switch platform {
    case .ios:
        return .ios
    case .harmony:
        return .harmony
    }
}

private func hostDeviceSelectionRequest(
    device: String?,
    platform: HostAppPlatform?,
    defaultPlatform: HostDevicePlatform?,
    name: String?,
    runtime: String?,
    state: String?,
    ready: Bool
) -> HostDeviceSelectionRequest {
    HostDeviceSelectionRequest(
        device: device,
        platform: platform.map(hostDevicePlatform(from:)) ?? defaultPlatform,
        name: name,
        runtime: runtime,
        state: state,
        ready: ready
    )
}

func ensureHostDeviceSelectorCompatibility(device: String?, simulator: String?, target: String?) throws {
    if device != nil && (simulator != nil || target != nil) {
        throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --simulator or Harmony --target.")
    }
}

private func resolveHostAppDeviceSelection(
    device: String?,
    platform: HostAppPlatform?,
    defaultPlatform: HostDevicePlatform?,
    simulator: String?,
    target: String?,
    name: String?,
    runtime: String?,
    state: String?,
    ready: Bool,
    hdc: String
) throws -> HostDeviceSelectionResult {
    try ensureHostDeviceSelectorCompatibility(device: device, simulator: simulator, target: target)
    return try resolveHostDeviceSelection(
        request: hostDeviceSelectionRequest(
            device: device ?? simulator ?? target,
            platform: platform,
            defaultPlatform: defaultPlatform,
            name: name,
            runtime: runtime,
            state: state,
            ready: ready
        ),
        hdc: hdc
    )
}

struct HostApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Control simulator apps through host-side Apple tools",
        subcommands: [
            HostAppList.self,
            HostAppInfo.self,
            HostAppInspect.self,
            HostAppInstall.self,
            HostAppUninstall.self,
            HostAppLaunch.self,
            HostAppTerminate.self,
            HostAppOpenURL.self,
            HostAppContainer.self,
            HostAppPrefs.self,
        ]
    )
}

struct HostAppList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List installed simulator apps")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Flag(help: "Only include User apps") var userOnly = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            let result = try runHostCommand(TKSimctlCommand.listApps(udid: selection.target.target))
            var apps = try TKSimctlAppInfoParser.parseList(result.stdoutData)
            if userOnly {
                apps = apps.filter { $0.applicationType == "User" }
            }
            let output = HostAppListOutput(
                ok: true,
                action: "app.list",
                simulatorUDID: selection.target.target,
                userOnly: userOnly,
                count: apps.count,
                apps: apps
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for app in apps {
                    print("\(app.bundleID)\t\(app.applicationType ?? "-")\t\(app.displayName ?? app.name ?? "-")\t\(app.path ?? "-")")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "Show installed simulator app information")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            let result = try runHostCommand(TKSimctlCommand.appInfo(udid: selection.target.target, bundleID: bundleID))
            let app = try TKSimctlAppInfoParser.parseAppInfo(result.stdoutData, bundleID: bundleID)
            let output = HostAppInfoOutput(
                ok: true,
                action: "app.info",
                simulatorUDID: selection.target.target,
                bundleID: bundleID,
                app: app
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print("\(app.bundleID)\t\(app.applicationType ?? "-")\t\(app.displayName ?? app.name ?? "-")\t\(app.path ?? "-")")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a platform app with host tools")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Harmony bundle name") var bundle: String
    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
            try runSimpleHostCommand(
                action: "app.inspect",
                runtimeScope: "host-harmony",
                target: "harmony:\(selected.target)/app:\(bundle)",
                command: TKHarmonyHDCCommand.appInspect(target: selected.target, bundleName: bundle, executable: hdc),
                outputFormat: outputFormat,
                note: "Harmony app metadata was inspected with bm dump."
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Install an app bundle into a simulator or emulator")

    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to .app bundle") var app: String?
    @Option(help: "Path to Harmony .hap package") var hap: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let effectivePlatform = platform ?? (hap != nil ? .harmony : .ios)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: effectivePlatform,
                defaultPlatform: nil,
                simulator: simulator,
                target: target,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: hdc
            )
            switch hostAppPlatform(from: selection.platform) {
        case .ios:
            guard let app else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "iOS app install requires --app.",
                    hint: "Pass `--app <path.app>` or use `--platform harmony --hap <path.hap>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.install",
                target: "sim:\(selection.target.target)",
                selection: selection,
                command: TKSimctlCommand.installApp(udid: selection.target.target, appPath: app),
                outputFormat: outputFormat,
                artifacts: [app],
                note: "App install was requested; verify with `triton app list --user-only --json` or `triton app info --bundle-id <id> --json`."
            )
        case .harmony:
            guard let hap else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "Harmony app install requires --hap.",
                    hint: "Pass `--platform harmony --hap <debug-signed.hap>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.install",
                runtimeScope: "host-harmony",
                target: "harmony:\(selection.target.target)",
                selection: selection,
                command: TKHarmonyHDCCommand.installHap(target: selection.target.target, hapPath: hap, executable: hdc),
                outputFormat: outputFormat,
                artifacts: [hap],
                note: "Harmony HAP install was requested; verify with `triton app inspect --platform harmony --bundle <bundle> --json` or launch + wait."
            )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall", abstract: "Uninstall an app from a simulator")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Confirm uninstalling the app from the simulator") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard confirm else {
            try failHostValidation(
                code: "destructive_action_requires_policy",
                message: "App uninstall requires --confirm.",
                hint: "Rerun with `--confirm` after verifying the simulator and bundle id.",
                outputFormat: outputFormat
            )
        }
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try runSimpleHostCommand(
                action: "app.uninstall",
                target: "sim:\(selection.target.target)/app:\(bundleID)",
                selection: selection,
                command: TKSimctlCommand.uninstallApp(udid: selection.target.target, bundleID: bundleID),
                outputFormat: outputFormat,
                note: "App uninstall was requested; verify with `triton app info --bundle-id <id> --json` or `triton app list --user-only --json`."
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppLaunch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "launch", abstract: "Launch an installed simulator app")

    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "iOS app bundle identifier") var bundleID: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony ability name") var ability: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            try ensureHostDeviceSelectorCompatibility(device: device, simulator: simulator, target: target)
            let defaultPlatform: HostDevicePlatform? = platform == nil && device == nil ? (bundle != nil ? .harmony : .ios) : nil
            let selection = try resolveHostDeviceSelection(
                request: hostDeviceSelectionRequest(
                    device: device ?? simulator ?? target,
                    platform: platform,
                    defaultPlatform: defaultPlatform,
                    name: name,
                    runtime: runtime,
                    state: state,
                    ready: ready
                ),
                hdc: hdc
            )
            switch hostAppPlatform(from: selection.platform) {
        case .ios:
            guard let bundleID else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "iOS app launch requires --bundle-id.",
                    hint: "Pass `--bundle-id <id>` or use `--platform harmony --bundle <bundle> --ability <ability>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.launch",
                target: "sim:\(selection.target.target)/app:\(bundleID)",
                selection: selection,
                command: TKSimctlCommand.launchApp(udid: selection.target.target, bundleID: bundleID),
                outputFormat: outputFormat,
                note: "App launch was requested; verify readiness with `triton status`, `triton wait`, or `triton app prefs get`."
            )
        case .harmony:
            guard let bundle, let ability else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "Harmony app launch requires --bundle and --ability.",
                    hint: "Pass `--platform harmony --bundle <bundle> --ability <ability>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.launch",
                runtimeScope: "host-harmony",
                target: "harmony:\(selection.target.target)/app:\(bundle)",
                selection: selection,
                command: TKHarmonyHDCCommand.appLaunch(target: selection.target.target, bundleName: bundle, abilityName: ability, executable: hdc),
                outputFormat: outputFormat,
                note: "Harmony app launch was requested; verify readiness with `triton ax --platform harmony`, screenshot, or logs."
            )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppTerminate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "terminate", abstract: "Terminate a running simulator or Harmony app")

    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "iOS app bundle identifier") var bundleID: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let effectivePlatform = platform ?? (bundle != nil ? .harmony : .ios)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: effectivePlatform,
                defaultPlatform: nil,
                simulator: simulator,
                target: target,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: hdc
            )
            switch hostAppPlatform(from: selection.platform) {
        case .ios:
            guard let bundleID else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "iOS app terminate requires --bundle-id.",
                    hint: "Pass `--bundle-id <id>` or use `--platform harmony --bundle <bundle>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.terminate",
                target: "sim:\(selection.target.target)/app:\(bundleID)",
                selection: selection,
                command: TKSimctlCommand.terminateApp(udid: selection.target.target, bundleID: bundleID),
                outputFormat: outputFormat,
                note: "App terminate was requested."
            )
        case .harmony:
            guard let bundle else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "Harmony app terminate requires --bundle.",
                    hint: "Pass `--platform harmony --bundle <bundle>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.terminate",
                runtimeScope: "host-harmony",
                target: "harmony:\(selection.target.target)/app:\(bundle)",
                selection: selection,
                command: TKHarmonyHDCCommand.forceStop(target: selection.target.target, bundleName: bundle, executable: hdc),
                outputFormat: outputFormat,
                note: "Harmony force-stop was requested."
            )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppOpenURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open-url", abstract: "Open a URL in a simulator or Harmony app")

    @Argument(help: "URL to open") var url: String
    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony ability name") var ability: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(name: .customLong("runtime-target"), help: "iOS embedded runtime target id from `triton list`") var runtimeTarget: String = TKLocalTargetID
    @Flag(name: .customLong("wait-ready"), help: "After opening the URL, wait until the embedded runtime is connected and has an active hierarchy") var waitReady = false
    @Flag(help: "After opening the URL, return an embedded runtime snapshot summary") var snapshot = false
    @Option(name: .customLong("snapshot-include"), help: "Comma-separated snapshot sections") var snapshotInclude: String = "app,scene,route,ax,geometry"
    @Option(name: .customLong("max-ax-nodes"), help: "Maximum AX nodes in the runtime snapshot") var maxAXNodes: Int?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Runtime wait timeout in seconds") var timeout: Double = 20
    @Option(help: "Runtime wait polling interval in seconds") var interval: Double = 0.5
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            try ensureHostDeviceSelectorCompatibility(device: device, simulator: simulator, target: target)
            let defaultPlatform: HostDevicePlatform? = platform == nil && device == nil ? (bundle != nil ? .harmony : .ios) : nil
            let selection = try resolveHostDeviceSelection(
                request: hostDeviceSelectionRequest(
                    device: device ?? simulator ?? target,
                    platform: platform,
                    defaultPlatform: defaultPlatform,
                    name: name,
                    runtime: runtime,
                    state: state,
                    ready: ready
                ),
                hdc: hdc
            )
            switch hostAppPlatform(from: selection.platform) {
        case .ios:
            if waitReady || snapshot {
                do {
                    let include = snapshotInclude.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    let summary = try await runIOSAppOpenURLFlow(options: IOSAppOpenURLFlowOptions(
                        simulator: selection.target.target,
                        runtimeTarget: runtimeTarget,
                        url: url,
                        waitReady: waitReady,
                        snapshot: snapshot,
                        snapshotInclude: include,
                        maxAXNodes: maxAXNodes,
                        host: host,
                        port: port,
                        timeout: timeout,
                        interval: interval
                    ))
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(summary))
                    case .text:
                        print("status: \(summary.status.rawValue)")
                        print("source: \(summary.hostAction.sourceCommand)")
                        if let ready = summary.ready {
                            print("runtime: connected=\(ready.connected) hierarchy=\(ready.hierarchyCacheState ?? "-")")
                        }
                        if let snapshot = summary.snapshot {
                            print("snapshot: app=\(snapshot.appName ?? "-") axNodes=\(snapshot.axNodeCount ?? 0)")
                        }
                    }
                } catch {
                    try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
                }
            } else {
                try runSimpleHostCommand(
                    action: "app.open-url",
                    target: "sim:\(selection.target.target)",
                    selection: selection,
                    command: TKSimctlCommand.openURL(udid: selection.target.target, url: url),
                    outputFormat: outputFormat,
                    note: "URL was submitted to the simulator; verify in-app completion with `triton wait`, `triton find`, or `triton assert`."
                )
            }
        case .harmony:
            guard let bundle, let ability else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "Harmony app open-url requires --bundle and --ability.",
                    hint: "Pass `--platform harmony --bundle <bundle> --ability <ability> <url>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.open-url",
                runtimeScope: "host-harmony",
                target: "harmony:\(selection.target.target)/app:\(bundle)",
                selection: selection,
                command: TKHarmonyHDCCommand.appOpenURL(target: selection.target.target, bundleName: bundle, abilityName: ability, url: url, executable: hdc),
                outputFormat: outputFormat,
                note: "Harmony deep link was submitted; verify business completion with `triton wait --platform harmony`, `triton ax --platform harmony`, or screenshot."
            )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppContainer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "container", abstract: "Print a simulator app container path")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Option(help: "Container kind: app, data, or groups") var kind: TKHostAppContainerKind = .data
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            let result = try runHostCommand(TKSimctlCommand.appContainer(udid: selection.target.target, bundleID: bundleID, kind: kind))
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = HostAppContainerOutput(
                ok: true,
                action: "app.container",
                simulatorUDID: selection.target.target,
                bundleID: bundleID,
                kind: kind.rawValue,
                path: path
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print(path)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppPrefs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prefs",
        abstract: "Read and update simulator app preferences as JSON",
        subcommands: [HostAppPrefsDump.self, HostAppPrefsGet.self, HostAppPrefsSet.self]
    )
}

struct HostAppPrefsDump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "dump", abstract: "Dump app preferences")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try printPreferences(simulator: selection.target.target, bundleID: bundleID, key: nil, outputFormat: outputFormat)
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppPrefsGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read one app preference value")

    @Argument(help: "Preference key") var key: String
    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try printPreferences(simulator: selection.target.target, bundleID: bundleID, key: key, outputFormat: outputFormat)
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppPrefsSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set one simulator app preference value from JSON")

    @Argument(help: "Preference key") var key: String
    @Argument(help: "JSON value to write") var value: String
    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try setPreference(
                simulator: selection.target.target,
                bundleID: bundleID,
                key: key,
                value: value,
                outputFormat: outputFormat
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

extension TKHostAppContainerKind: @retroactive ExpressibleByArgument {}

// MARK: - Cross-Platform Host Device Commands

struct Device: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "device",
        abstract: "Discover and inspect host-side devices and emulators",
        subcommands: [DeviceDoctor.self, DeviceList.self, DeviceAlias.self, DeviceUse.self, DeviceCurrent.self, DeviceResolve.self, DeviceWaitReady.self, DeviceScreenshot.self, DeviceRuntimeURL.self, DeviceStop.self]
    )
}

struct DeviceDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Probe platform host tools")

    @Option(help: "Platform adapter: ios|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Optional path to DevEco Emulator executable") var emulator: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let output: HostDeviceDoctorOutput
        switch platform {
        case .ios:
            let simctlProbe = probeHostTool(name: "simctl", command: TKHostCommand(executable: "xcrun", arguments: ["simctl", "help"]))
            let xcodebuildProbe = probeHostTool(name: "xcodebuild", command: TKHostCommand(executable: "xcodebuild", arguments: ["-version"]))
            output = HostDeviceDoctorOutput(
                ok: simctlProbe.available && xcodebuildProbe.available,
                platform: platform.rawValue,
                tools: [simctlProbe, xcodebuildProbe],
                capabilities: ["device.list", "device.use", "device.wait-ready", "device.screenshot", "ios.simctl-targets"],
                artifactsSaved: false
            )
        case .harmony:
            let hdcProbe = probeHostTool(name: "hdc", command: TKHarmonyHDCCommand.version(executable: hdc))
            let emulatorProbe = emulator.map { path in
                probeHostTool(name: "emulator", command: TKHostCommand(executable: path, arguments: ["-version"]))
            }
            output = HostDeviceDoctorOutput(
                ok: hdcProbe.available && (emulatorProbe?.available ?? true),
                platform: platform.rawValue,
                tools: [hdcProbe] + Array(emulatorProbe.map { [$0] } ?? []),
                capabilities: ["device.list", "device.use", "device.wait-ready", "device.runtime-url", "device.screenshot", "harmony.hdc-targets"],
                artifactsSaved: false
            )
        }
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            for tool in output.tools {
                print("\(tool.name)\t\(tool.available ? "available" : "unavailable")\t\(tool.path)")
            }
        }
    }
}

struct DeviceList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List platform targets")

    @Option(help: "Platform adapter: ios|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try hostDeviceTargets(platform: platform, hdc: hdc)
            let output = HostDeviceListOutput(
                ok: true,
                platform: platform.rawValue,
                targets: result.targets,
                defaultTarget: selectHostDeviceTarget(target: nil, candidates: result.targets),
                sourceCommand: result.sourceCommand
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for target in result.targets {
                    switch platform {
                    case .ios:
                        print("\(target.target)\t\(target.state)\t\(target.runtime ?? "-")\t\(target.name ?? "-")")
                    case .harmony:
                        print("\(target.target)\t\(target.state)\t\(target.transport ?? "-")")
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Set the current agent host target")

    @Argument(help: "Target selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var selector: String?
    @Option(help: "Platform adapter: ios|harmony") var platform: HostDevicePlatform?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if selector != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("device use accepts either <selector> or --target, not both.")
            }
            let selected = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: selector ?? target, platform: platform, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc
            )
            var store = try loadHostTargetAliasStore()
            store.current = hostDeviceCurrentSelector(explicitSelector: selector, explicitTarget: target, selected: selected)
            let defaultsPath = try saveHostTargetAliasStore(store)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceUseOutput(ok: true, platform: selected.platform.rawValue, target: selected.target, defaultsPath: defaultsPath, selection: selected)))
            case .text:
                print(selected.target.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceCurrent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current", abstract: "Show the current agent host target")

    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let store = try loadHostTargetAliasStore()
            let path = HostTargetAliasStore.filePath(workspace: FileManager.default.currentDirectoryPath)
            let selection = try store.current.map {
                try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: $0), hdc: hdc)
            }
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceCurrentOutput(ok: true, current: store.current, selection: selection, path: path)))
            case .text:
                print(selection?.target.target ?? "")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceResolve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "resolve", abstract: "Resolve one host target selector without executing an action")

    @Argument(help: "Target selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var selector: String?
    @Option(help: "Platform adapter: ios|harmony") var platform: HostDevicePlatform?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: selector, platform: platform, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceResolveOutput(ok: true, selection: selection)))
            case .text:
                print(selection.target.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceAlias: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "alias",
        abstract: "Manage stable host target aliases",
        subcommands: [DeviceAliasList.self, DeviceAliasSet.self, DeviceAliasRemove.self]
    )
}

struct DeviceAliasList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List host target aliases")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let store = try loadHostTargetAliasStore()
            let path = HostTargetAliasStore.filePath(workspace: FileManager.default.currentDirectoryPath)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceAliasListOutput(ok: true, current: store.current, aliases: store.aliases, path: path)))
            case .text:
                for name in store.aliases.keys.sorted() {
                    if let alias = store.aliases[name] {
                        print("\(name)\t\(alias.platform.rawValue)\t\(alias.target)")
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceAliasSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set a host target alias")

    @Argument(help: "Alias name") var name: String
    @Option(help: "Platform adapter: ios|harmony") var platform: HostDevicePlatform
    @Option(help: "Raw platform target id: iOS UDID or Harmony HDC target") var target: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"#, options: .regularExpression) != nil else {
                throw HostDeviceSelectionError.parameterConflict("Alias name must be 1-64 characters and use letters, digits, dot, underscore, or hyphen.")
            }
            var store = try loadHostTargetAliasStore()
            let alias = HostTargetAlias(platform: platform, target: target)
            store.aliases[name] = alias
            let path = try saveHostTargetAliasStore(store)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceAliasMutationOutput(ok: true, action: "device.alias.set", name: name, alias: alias, path: path)))
            case .text:
                print(name)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceAliasRemove: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove a host target alias")

    @Argument(help: "Alias name") var name: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            var store = try loadHostTargetAliasStore()
            let removed = store.aliases.removeValue(forKey: name)
            if store.current == name {
                store.current = nil
            }
            let path = try saveHostTargetAliasStore(store)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceAliasMutationOutput(ok: true, action: "device.alias.remove", name: name, alias: removed, path: path)))
            case .text:
                print(name)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceWaitReady: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "wait-ready", abstract: "Wait until a platform target is ready")

    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Platform adapter: ios|harmony") var platform: HostDevicePlatform?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets before waiting") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Timeout in seconds") var timeout: Double = 30
    @Option(help: "Polling interval in seconds") var interval: Double = 1
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if device != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
            }
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: device ?? target, platform: platform, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc
            )
            let event = try await waitForHostDeviceReady(
                platform: selection.platform,
                selected: selection.target,
                hdc: hdc,
                timeout: timeout,
                interval: interval
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(event))
            case .text:
                print("\(event.target.target)\tready=\(event.ready)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceScreenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Capture a host-side device screenshot")

    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Platform adapter: ios|harmony") var platform: HostDevicePlatform?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Output image path") var output: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if device != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
            }
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: device ?? target, platform: platform, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc
            )
            let artifact = try captureHostDeviceScreenshot(platform: selection.platform, target: selection.target, selection: selection, hdc: hdc, output: output)
            switch outputFormat {
            case .json:
                print(try encodeJSON(artifact))
            case .text:
                print(output)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceRuntimeURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "runtime-url", abstract: "Prepare and print a Harmony embedded runtime base URL")

    @Option(help: "Platform adapter: harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Unified host device selector: alias, harmony:<target>, raw id, or current") var device: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter when available") var name: String?
    @Option(help: "Runtime filter when available") var runtime: String?
    @Option(help: "Target state filter, for example connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Local TCP port for host-side runtime access") var localPort: Int = TKHarmonyRuntimeDefaults.hostAccessPort
    @Option(help: "Remote TCP port where the Harmony embedded runtime listens") var remotePort: Int = TKHarmonyRuntimeDefaults.hostAccessPort
    @Flag(help: "Skip HDC fport setup and only print the local base URL") var noForward = false
    @Flag(help: "Probe /v2/runtime/manifest after preparing the base URL") var probeManifest = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .harmony else {
                throw RuntimeError("device runtime-url only supports Harmony targets")
            }
            if device != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
            }
            try validateTCPPort(localPort, name: "--local-port")
            try validateTCPPort(remotePort, name: "--remote-port")
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(
                    device: device ?? target,
                    platform: .harmony,
                    name: name,
                    runtime: runtime,
                    state: state,
                    ready: ready
                ),
                hdc: hdc
            )
            let selected = harmonyTarget(from: selection.target)
            let baseURL = "http://127.0.0.1:\(localPort)"
            var sourceCommand: String?
            var forwarded = false
            if !noForward {
                let result = try runHostCommand(TKHarmonyHDCCommand.forwardPort(target: selected.target, localPort: localPort, remotePort: remotePort, executable: hdc))
                sourceCommand = result.sourceCommand
                forwarded = true
            }
            let manifest: TKRuntimeManifestResponse?
            if probeManifest {
                let data = try await EmbeddedRuntimeHTTPClient(baseURL: baseURL).request(.runtimeManifest)
                manifest = try JSONDecoder().decode(TKRuntimeManifestResponse.self, from: data)
            } else {
                manifest = nil
            }
            let output = HostRuntimeURLOutput(
                ok: true,
                platform: platform.rawValue,
                target: selected,
                localPort: localPort,
                remotePort: remotePort,
                baseURL: baseURL,
                forwarded: forwarded,
                sourceCommand: sourceCommand,
                manifest: manifest,
                note: "Use `--runtime-base-url \(baseURL)` with runtime, state, snapshot, ledger, and semantic action commands."
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(baseURL)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a host-side device or emulator")

    @Option(help: "Platform adapter: harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Harmony HVD name, for example Codex Test Phone") var hvd: String
    @Option(help: "DevEco deployed emulator path, for example ~/.Huawei/Emulator/deployed") var path: String
    @Option(help: "Path to DevEco Emulator executable") var emulator: String = "/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
    @Option(help: "Triton launchd job label to unload before stopping") var launchdLabel: String = "triton-harmony-emulator"
    @Option(help: "launchd domain, defaults to gui/<uid>") var launchdDomain: String = defaultLaunchdDomain()
    @Flag(help: "Skip launchd print/bootout and only run Emulator -stop") var skipLaunchd = false
    @Flag(help: "Confirm stopping the emulator and unloading Triton launchd supervision") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .harmony else {
                throw RuntimeError("device stop currently supports Harmony Emulator only")
            }
            let plan = try harmonyEmulatorStopPlan(
                hvd: hvd,
                deployedPath: path,
                emulator: emulator,
                launchdLabel: launchdLabel,
                launchdDomain: launchdDomain,
                includeLaunchd: !skipLaunchd,
                confirmed: confirm
            )
            var sourceCommands: [String] = []
            for command in plan.commands {
                let result = try runHostCommand(command)
                sourceCommands.append(result.sourceCommand)
            }
            let output = HostDeviceStopOutput(
                ok: true,
                action: plan.action,
                platform: plan.platform,
                hvd: plan.hvd,
                deployedPath: plan.deployedPath,
                emulator: plan.emulator,
                launchdLabel: plan.launchdLabel,
                launchdDomain: plan.launchdDomain,
                sourceCommands: sourceCommands,
                note: "Harmony emulator stop completed. Verify with `triton device list --platform harmony --json`; the target should remain disconnected or absent."
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(output.note)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
