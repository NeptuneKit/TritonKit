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

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Only include User apps") var userOnly = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.listApps(udid: simulator))
            var apps = try TKSimctlAppInfoParser.parseList(result.stdoutData)
            if userOnly {
                apps = apps.filter { $0.applicationType == "User" }
            }
            let output = HostAppListOutput(
                ok: true,
                action: "app.list",
                simulatorUDID: simulator,
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

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.appInfo(udid: simulator, bundleID: bundleID))
            let app = try TKSimctlAppInfoParser.parseAppInfo(result.stdoutData, bundleID: bundleID)
            let output = HostAppInfoOutput(
                ok: true,
                action: "app.info",
                simulatorUDID: simulator,
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

    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform = .ios
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Path to .app bundle") var app: String?
    @Option(help: "Path to Harmony .hap package") var hap: String?
    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        switch platform {
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
                target: "sim:\(simulator)",
                command: TKSimctlCommand.installApp(udid: simulator, appPath: app),
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
            do {
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                try runSimpleHostCommand(
                    action: "app.install",
                    runtimeScope: "host-harmony",
                    target: "harmony:\(selected.target)",
                    command: TKHarmonyHDCCommand.installHap(target: selected.target, hapPath: hap, executable: hdc),
                    outputFormat: outputFormat,
                    artifacts: [hap],
                    note: "Harmony HAP install was requested; verify with `triton app inspect --platform harmony --bundle <bundle> --json` or launch + wait."
                )
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
        }
    }
}

struct HostAppUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall", abstract: "Uninstall an app from a simulator")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
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
        try runSimpleHostCommand(
            action: "app.uninstall",
            target: "sim:\(simulator)/app:\(bundleID)",
            command: TKSimctlCommand.uninstallApp(udid: simulator, bundleID: bundleID),
            outputFormat: outputFormat,
            note: "App uninstall was requested; verify with `triton app info --bundle-id <id> --json` or `triton app list --user-only --json`."
        )
    }
}

struct HostAppLaunch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "launch", abstract: "Launch an installed simulator app")

    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform = .ios
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "iOS app bundle identifier") var bundleID: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony ability name") var ability: String?
    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        switch platform {
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
                target: "sim:\(simulator)/app:\(bundleID)",
                command: TKSimctlCommand.launchApp(udid: simulator, bundleID: bundleID),
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
            do {
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                try runSimpleHostCommand(
                    action: "app.launch",
                    runtimeScope: "host-harmony",
                    target: "harmony:\(selected.target)/app:\(bundle)",
                    command: TKHarmonyHDCCommand.appLaunch(target: selected.target, bundleName: bundle, abilityName: ability, executable: hdc),
                    outputFormat: outputFormat,
                    note: "Harmony app launch was requested; verify readiness with `triton ax --platform harmony`, screenshot, or logs."
                )
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
        }
    }
}

struct HostAppTerminate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "terminate", abstract: "Terminate a running simulator or Harmony app")

    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform = .ios
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "iOS app bundle identifier") var bundleID: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        switch platform {
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
                target: "sim:\(simulator)/app:\(bundleID)",
                command: TKSimctlCommand.terminateApp(udid: simulator, bundleID: bundleID),
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
            do {
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                try runSimpleHostCommand(
                    action: "app.terminate",
                    runtimeScope: "host-harmony",
                    target: "harmony:\(selected.target)/app:\(bundle)",
                    command: TKHarmonyHDCCommand.forceStop(target: selected.target, bundleName: bundle, executable: hdc),
                    outputFormat: outputFormat,
                    note: "Harmony force-stop was requested."
                )
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
        }
    }
}

struct HostAppOpenURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open-url", abstract: "Open a URL in a simulator or Harmony app")

    @Argument(help: "URL to open") var url: String
    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform = .ios
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony ability name") var ability: String?
    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String?
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
        switch platform {
        case .ios:
            if waitReady || snapshot {
                do {
                    let include = snapshotInclude.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    let summary = try await runIOSAppOpenURLFlow(options: IOSAppOpenURLFlowOptions(
                        simulator: simulator,
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
                    target: "sim:\(simulator)",
                    command: TKSimctlCommand.openURL(udid: simulator, url: url),
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
            do {
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                try runSimpleHostCommand(
                    action: "app.open-url",
                    runtimeScope: "host-harmony",
                    target: "harmony:\(selected.target)/app:\(bundle)",
                    command: TKHarmonyHDCCommand.appOpenURL(target: selected.target, bundleName: bundle, abilityName: ability, url: url, executable: hdc),
                    outputFormat: outputFormat,
                    note: "Harmony deep link was submitted; verify business completion with `triton wait --platform harmony`, `triton ax --platform harmony`, or screenshot."
                )
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
        }
    }
}

struct HostAppContainer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "container", abstract: "Print a simulator app container path")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Option(help: "Container kind: app, data, or groups") var kind: TKHostAppContainerKind = .data
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.appContainer(udid: simulator, bundleID: bundleID, kind: kind))
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = HostAppContainerOutput(
                ok: true,
                action: "app.container",
                simulatorUDID: simulator,
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

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printPreferences(simulator: simulator, bundleID: bundleID, key: nil, outputFormat: effectiveFormat(format, json: json))
    }
}

struct HostAppPrefsGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read one app preference value")

    @Argument(help: "Preference key") var key: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printPreferences(simulator: simulator, bundleID: bundleID, key: key, outputFormat: effectiveFormat(format, json: json))
    }
}

struct HostAppPrefsSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set one simulator app preference value from JSON")

    @Argument(help: "Preference key") var key: String
    @Argument(help: "JSON value to write") var value: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try setPreference(
            simulator: simulator,
            bundleID: bundleID,
            key: key,
            value: value,
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

extension TKHostAppContainerKind: @retroactive ExpressibleByArgument {}

// MARK: - Cross-Platform Host Device Commands

enum HostPlatform: String, ExpressibleByArgument {
    case harmony
}

struct Device: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "device",
        abstract: "Discover and inspect host-side devices and emulators",
        subcommands: [DeviceDoctor.self, DeviceList.self, DeviceUse.self, DeviceWaitReady.self, DeviceRuntimeURL.self]
    )
}

struct DeviceDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Probe platform host tools")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Optional path to DevEco Emulator executable") var emulator: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let hdcProbe = probeHostTool(name: "hdc", command: TKHarmonyHDCCommand.version(executable: hdc))
        let emulatorProbe = emulator.map { path in
            probeHostTool(name: "emulator", command: TKHostCommand(executable: path, arguments: ["-version"]))
        }
        let output = HostDeviceDoctorOutput(
            ok: hdcProbe.available,
            platform: platform.rawValue,
            tools: [hdcProbe] + Array(emulatorProbe.map { [$0] } ?? []),
            capabilities: ["device.list", "device.wait-ready", "harmony.hdc-targets"],
            artifactsSaved: false
        )
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

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKHarmonyHDCCommand.listTargets(executable: hdc))
            let targets = TKHdcTargetListParser.parse(result.stdout)
            let output = HostDeviceListOutput(
                ok: true,
                platform: platform.rawValue,
                targets: targets,
                defaultTarget: TKHdcTargetListParser.defaultTarget(from: targets),
                sourceCommand: result.sourceCommand
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for target in targets {
                    print("\(target.target)\t\(target.state)\t\(target.transport)")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Resolve one platform target")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceUseOutput(ok: true, platform: platform.rawValue, target: selected)))
            case .text:
                print(selected.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceWaitReady: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "wait-ready", abstract: "Wait until a platform target is ready")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Timeout in seconds") var timeout: Double = 30
    @Option(help: "Polling interval in seconds") var interval: Double = 1
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
            let deadline = Date().addingTimeInterval(timeout)
            var attempt = 0
            while Date() <= deadline {
                attempt += 1
                let command = TKHarmonyHDCCommand.bootCompleted(target: selected.target, executable: hdc)
                let result = try runHostCommand(command)
                let ready = TKHarmonyBootCompletedParser.isReady(result.stdout)
                let event = HostDeviceReadyEvent(
                    ok: ready,
                    platform: platform.rawValue,
                    target: selected,
                    ready: ready,
                    attempt: attempt,
                    sourceCommand: result.sourceCommand,
                    error: nil
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(event))
                case .text:
                    print("\(selected.target)\tready=\(ready)")
                }
                if ready { return }
                try await Task.sleep(nanoseconds: UInt64(max(0.1, interval) * 1_000_000_000))
            }
            try failHostCommand(HostCommandRunError.deviceNotReady(target: selected.target, timeoutSeconds: timeout), outputFormat: outputFormat)
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceRuntimeURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "runtime-url", abstract: "Prepare and print a Harmony embedded runtime base URL")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Target id, for example 127.0.0.1:10100") var target: String?
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
            try validateTCPPort(localPort, name: "--local-port")
            try validateTCPPort(remotePort, name: "--remote-port")
            let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
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
