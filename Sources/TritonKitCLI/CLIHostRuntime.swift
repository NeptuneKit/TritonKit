import ArgumentParser
import Darwin
import Foundation
import TritonKitShared

func runSimpleHostCommand(
    action: String,
    runtimeScope: String = "host-simulator",
    target: String,
    command: TKHostCommand,
    outputFormat: ClientOutputFormat,
    artifacts: [String] = [],
    note: String? = nil
) throws {
    do {
        let result = try runHostCommand(command)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = HostActionOutput(
            ok: true,
            action: action,
            runtimeScope: runtimeScope,
            target: target,
            tool: command.executable,
            exitCode: result.exitCode,
            riskLevel: command.riskLevel.rawValue,
            sourceCommand: result.sourceCommand,
            stdoutTruncated: result.stdoutTruncated,
            stderrTruncated: result.stderrTruncated,
            stdout: stdout.isEmpty ? nil : stdout,
            stderr: stderr.isEmpty ? nil : stderr,
            artifacts: artifacts,
            note: note
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            if let note { print(note) }
            if !stdout.isEmpty { print(stdout) }
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func loadHostWorkspaceDefaults() throws -> TKHostWorkspaceDefaults? {
    let path = TKHostWorkspaceDefaults.filePath(workspace: FileManager.default.currentDirectoryPath)
    guard FileManager.default.fileExists(atPath: path) else {
        return nil
    }
    return try JSONDecoder().decode(TKHostWorkspaceDefaults.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
}

func saveHostWorkspaceDefaults(_ defaults: TKHostWorkspaceDefaults) throws -> String {
    let path = TKHostWorkspaceDefaults.filePath(workspace: FileManager.default.currentDirectoryPath)
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(defaults)
    try data.write(to: url, options: [.atomic])
    return path
}

func simulatorIsBooted(udid: String) throws -> Bool {
    let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
    let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
    guard let simulator = simulators.first(where: { $0.udid == udid || $0.id == udid }) else {
        throw HostSimulatorRunError.simulatorNotFound(udid)
    }
    return simulator.isBooted
}

func waitForSimulatorBoot(
    udid: String,
    timeout: Double,
    interval: Double,
    outputFormat: ClientOutputFormat,
    jsonl: Bool
) async throws {
    let startedAt = Date()
    let deadline = startedAt.addingTimeInterval(timeout)
    var attempt = 0
    var lastEvent: HostSimulatorReadyEvent?
    while Date() <= deadline {
        attempt += 1
        let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
        let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
        guard let simulator = simulators.first(where: { $0.udid == udid || $0.id == udid }) else {
            throw HostSimulatorRunError.simulatorNotFound(udid)
        }
        let event = HostSimulatorReadyEvent(
            ok: simulator.isBooted,
            action: "sim.boot.wait",
            simulatorUDID: simulator.udid,
            state: simulator.state,
            ready: simulator.isBooted,
            attempt: attempt,
            elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
            sourceCommand: result.sourceCommand
        )
        lastEvent = event
        if jsonl {
            print(try encodeCompactJSON(event))
        } else if outputFormat == .text {
            print("\(simulator.udid)\tstate=\(simulator.state)\tready=\(simulator.isBooted)")
        }
        if simulator.isBooted {
            if !jsonl, outputFormat == .json {
                print(try encodeJSON(event))
            }
            return
        }
        try await Task.sleep(nanoseconds: UInt64(max(0.1, interval) * 1_000_000_000))
    }
    if let lastEvent, jsonl {
        print(try encodeCompactJSON(lastEvent))
    }
    throw HostCommandRunError.timeout(command: TKSimctlCommand.boot(udid: udid), timeoutSeconds: timeout, stdoutLogPath: nil, stderrLogPath: nil)
}

func probeHostTool(name: String, command: TKHostCommand) -> HostToolProbeOutput {
    do {
        let result = try runHostCommand(command)
        let summary = result.stdout
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)
        return HostToolProbeOutput(
            name: name,
            path: command.executable,
            available: true,
            versionSummary: summary,
            error: nil,
            sourceCommand: result.sourceCommand
        )
    } catch {
        return HostToolProbeOutput(
            name: name,
            path: command.executable,
            available: false,
            versionSummary: nil,
            error: "\(error)",
            sourceCommand: hostSourceCommand(command)
        )
    }
}

func resolveHarmonyTarget(target: String?, hdc: String) throws -> TKHarmonyTarget {
    let result = try runHostCommand(TKHarmonyHDCCommand.listTargets(executable: hdc))
    let targets = TKHdcTargetListParser.parse(result.stdout)
    if let target {
        guard let selected = targets.first(where: { $0.target == target || $0.id == target }) else {
            throw HostDeviceRunError.targetNotFound(target)
        }
        guard selected.isConnected else {
            throw HostDeviceRunError.targetOffline(selected.target)
        }
        return selected
    }
    if let selected = TKHdcTargetListParser.defaultTarget(from: targets) {
        return selected
    }
    throw HostDeviceRunError.ambiguousTarget(targets.filter(\.isConnected))
}

func resolveHarmonyTarget(target: String, hdc: String) throws -> TKHarmonyTarget {
    try resolveHarmonyTarget(target: target == TKLocalTargetID ? nil : target, hdc: hdc)
}

func ensureParentDirectory(for path: String) throws {
    let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}

func temporaryHarmonyArtifactPath(prefix: String, extension fileExtension: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString).\(fileExtension)")
        .path
}

func remoteHarmonyArtifactPath(prefix: String, extension fileExtension: String) -> String {
    "/data/local/tmp/\(prefix)-\(UUID().uuidString).\(fileExtension)"
}

func dumpHarmonyLayout(
    selected: TKHarmonyTarget,
    hdc: String,
    output: String?
) throws -> (localPath: String, sourceCommands: [String], data: Data) {
    let localPath = output ?? temporaryHarmonyArtifactPath(prefix: "triton-layout", extension: "json")
    try ensureParentDirectory(for: localPath)

    let dumpResult = try runHostCommand(TKHarmonyHDCCommand.dumpLayout(target: selected.target, executable: hdc))
    let remotePath: String
    do {
        remotePath = try TKHarmonyDumpLayoutParser.remotePath(from: dumpResult.stdout)
    } catch {
        throw HostCommandRunError.layoutPathNotFound
    }
    let recvResult = try runHostCommand(TKHarmonyHDCCommand.recvFile(target: selected.target, remotePath: remotePath, localPath: localPath, executable: hdc))
    let data = try Data(contentsOf: URL(fileURLWithPath: localPath))
    return (localPath, [dumpResult.sourceCommand, recvResult.sourceCommand], data)
}

func captureHarmonyScreenshot(
    selected: TKHarmonyTarget,
    hdc: String,
    output: String
) throws -> (remotePath: String, sourceCommands: [String]) {
    try ensureParentDirectory(for: output)
    let remotePath = remoteHarmonyArtifactPath(prefix: "triton-smoke", extension: "jpeg")
    let screenshotResult = try runHostCommand(TKHarmonyHDCCommand.screenshot(target: selected.target, remotePath: remotePath, executable: hdc))
    let recvResult = try runHostCommand(TKHarmonyHDCCommand.recvFile(target: selected.target, remotePath: remotePath, localPath: output, executable: hdc))
    return (remotePath, [screenshotResult.sourceCommand, recvResult.sourceCommand])
}

func validateTCPPort(_ port: Int, name: String) throws {
    guard (1...65_535).contains(port) else {
        throw RuntimeError("\(name) must be between 1 and 65535")
    }
}

func printPreferences(
    simulator: String,
    bundleID: String,
    key: String?,
    outputFormat: ClientOutputFormat
) throws {
    do {
        let containerResult = try runHostCommand(TKSimctlCommand.appContainer(udid: simulator, bundleID: bundleID, kind: .data))
        let container = containerResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let plistPath = TKHostPreferencesSnapshot.plistPath(dataContainer: container, bundleID: bundleID)
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw HostCommandRunError.missingPreferences(path: plistPath)
        }
        let snapshot = try TKHostPreferencesSnapshot(bundleID: bundleID, plistPath: plistPath, data: Data(contentsOf: URL(fileURLWithPath: plistPath)))
        let value = key.flatMap { snapshot.value(forKey: $0) }
        if let key, value == nil {
            throw HostCommandRunError.preferenceKeyNotFound(key)
        }
        let output = HostPreferencesOutput(
            ok: true,
            action: key == nil ? "app.prefs.dump" : "app.prefs.get",
            simulatorUDID: simulator,
            bundleID: bundleID,
            plistPath: plistPath,
            key: key,
            value: value,
            preferences: key == nil ? snapshot.preferences : nil
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            if let key {
                print("\(key)=\(value.map(renderPreferenceValue) ?? "")")
            } else {
                for (key, value) in snapshot.preferences.sorted(by: { $0.key < $1.key }) {
                    print("\(key)=\(renderPreferenceValue(value))")
                }
            }
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func setPreference(
    simulator: String,
    bundleID: String,
    key: String,
    value: String,
    outputFormat: ClientOutputFormat
) throws {
    do {
        let newValue = try parseHostPreferenceJSONValue(value)
        let containerResult = try runHostCommand(TKSimctlCommand.appContainer(udid: simulator, bundleID: bundleID, kind: .data))
        let container = containerResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let plistPath = TKHostPreferencesSnapshot.plistPath(dataContainer: container, bundleID: bundleID)
        let existingData = FileManager.default.fileExists(atPath: plistPath) ? try Data(contentsOf: URL(fileURLWithPath: plistPath)) : nil
        let update = try updatingPreferencePlistData(
            existingData: existingData,
            bundleID: bundleID,
            plistPath: plistPath,
            key: key,
            newValue: newValue
        )
        try ensureParentDirectory(for: plistPath)
        try update.data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
        let output = HostPreferencesSetOutput(
            ok: true,
            action: "app.prefs.set",
            simulatorUDID: simulator,
            bundleID: bundleID,
            plistPath: plistPath,
            key: key,
            previousValue: update.previousValue,
            newValue: update.newValue,
            restartAdvice: "Terminate and relaunch the app if it reads this preference only at startup."
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            print("\(key)=\(renderPreferenceValue(update.newValue))")
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func parseHostPreferenceJSONValue(_ value: String) throws -> TKHostPreferenceValue {
    let data = Data(value.utf8)
    let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    return try hostPreferenceValue(fromJSONObject: object)
}

func updatingPreferencePlistData(
    existingData: Data?,
    bundleID: String,
    plistPath: String,
    key: String,
    newValue: TKHostPreferenceValue
) throws -> HostPreferencePlistUpdateResult {
    let dictionary: [String: Any]
    if let existingData {
        let object = try PropertyListSerialization.propertyList(from: existingData, options: [], format: nil)
        guard let existing = object as? [String: Any] else {
            throw TKHostPreferencesError.invalidRoot
        }
        dictionary = existing
    } else {
        dictionary = [:]
    }

    let snapshotData = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
    let snapshot = try TKHostPreferencesSnapshot(bundleID: bundleID, plistPath: plistPath, data: snapshotData)
    let previousValue = snapshot.value(forKey: key)
    var updated = dictionary
    updated[key] = try propertyListObject(fromPreferenceValue: newValue)
    let data = try PropertyListSerialization.data(fromPropertyList: updated, format: .binary, options: 0)
    return HostPreferencePlistUpdateResult(data: data, previousValue: previousValue, newValue: newValue)
}

private func hostPreferenceValue(fromJSONObject object: Any) throws -> TKHostPreferenceValue {
    switch object {
    case let value as String:
        return .string(value)
    case let value as NSNumber:
        if isBooleanNumber(value) {
            return .bool(value.boolValue)
        }
        let doubleValue = value.doubleValue
        if floor(doubleValue) == doubleValue {
            return .int(value.intValue)
        }
        return .double(doubleValue)
    case let value as Bool:
        return .bool(value)
    case let value as [Any]:
        return .array(try value.map(hostPreferenceValue(fromJSONObject:)))
    case let value as [String: Any]:
        return .dictionary(try value.mapValues(hostPreferenceValue(fromJSONObject:)))
    case _ as NSNull:
        throw RuntimeError("Property list preferences do not support null. Use a string, number, bool, array, or object.")
    default:
        throw RuntimeError("Unsupported preference JSON value.")
    }
}

private func isBooleanNumber(_ value: NSNumber) -> Bool {
    CFGetTypeID(value) == CFBooleanGetTypeID() || String(cString: value.objCType) == "c" || String(cString: value.objCType) == "B"
}

private func propertyListObject(fromPreferenceValue value: TKHostPreferenceValue) throws -> Any {
    switch value {
    case .string(let value):
        return value
    case .bool(let value):
        return value
    case .int(let value):
        return value
    case .double(let value):
        return value
    case .array(let values):
        return try values.map(propertyListObject(fromPreferenceValue:))
    case .dictionary(let values):
        return try values.mapValues(propertyListObject(fromPreferenceValue:))
    case .data(let value):
        guard let data = Data(base64Encoded: value) else {
            throw RuntimeError("Invalid base64 data preference value.")
        }
        return data
    }
}

func runHostCommand(_ command: TKHostCommand) throws -> HostProcessResult {
    let timeoutSeconds = command.defaultTimeoutSeconds
    let process = Process()
    if command.executable.contains("/") {
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.processArguments
    } else if command.executable == "xcrun" {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = command.processArguments
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command.executable] + command.processArguments
    }

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
    } catch {
        throw HostCommandRunError.launchFailed(error.localizedDescription)
    }
    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .utility).async {
        process.waitUntilExit()
        semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
        process.terminate()
        throw HostCommandRunError.timeout(command: command, timeoutSeconds: timeoutSeconds, stdoutLogPath: nil, stderrLogPath: nil)
    }

    let stdoutRaw = stdout.fileHandleForReading.readDataToEndOfFile()
    let stderrRaw = stderr.fileHandleForReading.readDataToEndOfFile()
    let stdoutRead = truncatedData(stdoutRaw)
    let stderrRead = truncatedData(stderrRaw)
    let result = HostProcessResult(
        stdoutData: stdoutRead.data,
        stderrData: stderrRead.data,
        exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: stdoutRead.truncated,
        stderrTruncated: stderrRead.truncated,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: stdoutRaw.count,
        stderrBytes: stderrRaw.count
    )
    if result.exitCode != 0 {
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    return result
}

func truncatedData(_ data: Data, maximumBytes: Int = 1_048_576) -> (data: Data, truncated: Bool) {
    guard data.count > maximumBytes else {
        return (data, false)
    }
    return (data.prefix(maximumBytes), true)
}

func hostSourceCommand(_ command: TKHostCommand) -> String {
    ([command.executable] + command.arguments).map(shellEscaped).joined(separator: " ")
}

func shellEscaped(_ value: String) -> String {
    guard !value.isEmpty else { return "''" }
    if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: #"'\"$`"#))) == nil {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func renderPreferenceValue(_ value: TKHostPreferenceValue) -> String {
    switch value {
    case .string(let value):
        value
    case .bool(let value):
        value ? "true" : "false"
    case .int(let value):
        "\(value)"
    case .double(let value):
        "\(value)"
    case .array(let values):
        "[" + values.map(renderPreferenceValue).joined(separator: ",") + "]"
    case .dictionary(let values):
        "{" + values.keys.sorted().map { "\($0):\(renderPreferenceValue(values[$0]!))" }.joined(separator: ",") + "}"
    case .data(let value):
        value
    }
}

func failHostCommand(_ error: Error, outputFormat: ClientOutputFormat) throws -> Never {
    let detail: TKCLIErrorDetail
    switch error {
    case XcodeWorkflowError.missingContainer:
        detail = TKCLIErrorDetail(
            code: "invalid_workspace_path",
            message: "\(error)",
            hint: "Run `triton xcode discover --path . --json`, then `triton xcode use --workspace <path> --scheme <scheme> --simulator <udid> --json`."
        )
    case XcodeWorkflowError.ambiguousContainer:
        detail = TKCLIErrorDetail(
            code: "ambiguous_workspace",
            message: "\(error)",
            hint: "Pass exactly one of --workspace or --project."
        )
    case XcodeWorkflowError.missingScheme:
        detail = TKCLIErrorDetail(
            code: "scheme_not_found",
            message: "\(error)",
            hint: "Run `triton xcode schemes --workspace <path> --json` to inspect schemes."
        )
    case XcodeWorkflowError.appPathUnresolved, TKXcodeBuildSettingsError.appPathUnresolved:
        detail = TKCLIErrorDetail(
            code: "app_path_unresolved",
            message: "\(error)",
            hint: "Run `triton xcode settings --json` and check BUILT_PRODUCTS_DIR and FULL_PRODUCT_NAME."
        )
    case XcodeWorkflowError.bundleIDUnresolved:
        detail = TKCLIErrorDetail(
            code: "bundle_id_unresolved",
            message: "\(error)",
            hint: "Verify the built .app has an Info.plist with CFBundleIdentifier."
        )
    case XcodeWorkflowError.simulatorRequired:
        detail = TKCLIErrorDetail(
            code: "simulator_not_found",
            message: "\(error)",
            hint: "Pass `--simulator <udid>` or run `triton sim use <udid> --json` first."
        )
    case TKXcodeDiscoveryError.pathNotFound:
        detail = TKCLIErrorDetail(
            code: "invalid_workspace_path",
            message: "\(error)",
            hint: "Pass an existing repo path to `triton xcode discover --path <path> --json`."
        )
    case HostSimulatorRunError.simulatorNotFound:
        detail = TKCLIErrorDetail(
            code: "simulator_not_found",
            message: "\(error)",
            hint: "Run `triton sim list --json` to inspect available simulator UDIDs."
        )
    case HostDeviceRunError.ambiguousTarget(let targets):
        detail = TKCLIErrorDetail(
            code: "ambiguous_target",
            message: "\(error)",
            hint: "Pass --target with one of: \(targets.map(\.target).joined(separator: ", "))."
        )
    case HostDeviceRunError.targetOffline:
        detail = TKCLIErrorDetail(
            code: "target_offline",
            message: "\(error)",
            hint: "Start the target and wait until hdc reports Connected."
        )
    case HostDeviceRunError.targetNotFound:
        detail = TKCLIErrorDetail(
            code: "target_not_found",
            message: "\(error)",
            hint: "Run `triton device list --platform harmony --json` to inspect available targets."
        )
    case HostCommandRunError.deviceNotReady:
        detail = TKCLIErrorDetail(
            code: "device_not_ready",
            message: "\(error)",
            hint: "Check emulator boot state, increase --timeout, or inspect hdc shell param output."
        )
    case HostCommandRunError.layoutPathNotFound:
        detail = TKCLIErrorDetail(
            code: "harmony_layout_path_not_found",
            message: "\(error)",
            hint: "Inspect `hdc shell uitest dumpLayout` output and verify uitest is available on the target."
        )
    case HostCommandRunError.layoutTextNotFound:
        detail = TKCLIErrorDetail(
            code: "harmony_layout_text_not_found",
            message: "\(error)",
            hint: "Run `triton ax --platform harmony --output <path> --json` and inspect the dumped attributes.text values."
        )
    case HostCommandRunError.timeout:
        detail = TKCLIErrorDetail(
            code: "host_command_timeout",
            message: "\(error)",
            hint: "Retry with a smaller target set or a command-specific timeout when supported."
        )
    case HostCommandRunError.missingPreferences:
        detail = TKCLIErrorDetail(
            code: "plist_not_found",
            message: "\(error)",
            hint: "Launch the app once or verify the bundle id and simulator data container."
        )
    case HostCommandRunError.preferenceKeyNotFound:
        detail = TKCLIErrorDetail(
            code: "preference_key_not_found",
            message: "\(error)",
            hint: "Run `triton app prefs dump --bundle-id <id> --json` to inspect available keys."
        )
    case XcodeDiagnosticsError.notIdle(let status):
        detail = TKCLIErrorDetail(
            code: "xcode_not_idle",
            message: "\(error)",
            hint: "Wait for the listed PIDs to finish, cancel stale builds, or retry with a more specific --workspace. Blocking PIDs: \(status.processes.map { "\($0.pid)" }.joined(separator: ", "))."
        )
    case TKSimctlAppInfoParserError.emptyInfo:
        detail = TKCLIErrorDetail(
            code: "app_info_not_available",
            message: "Installed app information is not available.",
            hint: "Verify the simulator is booted and the bundle id is installed."
        )
    case HostCommandRunError.nonZeroExit(let command, _):
        let code: String
        let hint: String
        let isHDC = command.executable == "hdc" || command.executable.hasSuffix("/hdc")
        if command.executable == "xcodebuild" {
            code = "xcodebuild_failed"
            hint = "Inspect the xcodebuild output, verify workspace/project, scheme, destination, signing, and DerivedData path."
        } else if isHDC && command.arguments.contains("list") && command.arguments.contains("targets") {
            code = "host_action_failed"
            hint = "Verify hdc is installed, available on PATH, and can list Harmony targets."
        } else if isHDC && command.arguments.contains("install") {
            code = "app_install_failed"
            hint = "Verify the Harmony target is Connected and --hap points to a debug-signed HAP."
        } else if isHDC && command.arguments.contains("aa") && command.arguments.contains("start") && command.arguments.contains("-U") {
            code = "host_open_url_failed"
            hint = "Verify the Harmony bundle, ability, target, and deep link URL."
        } else if isHDC && command.arguments.contains("aa") && command.arguments.contains("start") {
            code = "app_launch_failed"
            hint = "Verify the Harmony bundle, ability, target, and installed app state."
        } else if isHDC && command.arguments.contains("force-stop") {
            code = "app_terminate_failed"
            hint = "Verify the Harmony bundle and target."
        } else if isHDC && command.arguments.contains("dumpLayout") {
            code = "harmony_layout_failed"
            hint = "Verify the Harmony target is ready and uitest dumpLayout is available."
        } else if isHDC && command.arguments.contains("recv") {
            code = "harmony_artifact_recv_failed"
            hint = "Verify the remote artifact path exists and the local output directory is writable."
        } else if isHDC && command.arguments.contains("snapshot_display") {
            code = "harmony_screenshot_failed"
            hint = "Verify the Harmony target supports snapshot_display and use a .jpeg-compatible output flow."
        } else if command.arguments.contains("get_app_container") {
            code = "app_container_not_found"
            hint = "Verify the simulator is booted, the app is installed, and the bundle id is correct."
        } else if command.arguments.contains("appinfo") || command.arguments.contains("listapps") {
            code = "app_info_not_available"
            hint = "Verify the simulator is booted, the app is installed, and the bundle id is correct."
        } else if command.arguments.contains("install") {
            code = "app_install_failed"
            hint = "Verify the simulator is booted and the .app path points to a simulator build."
        } else if command.arguments.contains("launch") {
            code = "app_launch_failed"
            hint = "Verify the simulator is booted and the bundle id is installed."
        } else if command.arguments.contains("terminate") {
            code = "app_terminate_failed"
            hint = "Verify the simulator is booted and the bundle id is running or installed."
        } else if command.arguments.contains("openurl") {
            code = "host_open_url_failed"
            hint = "Verify the simulator is booted and the URL scheme is valid."
        } else {
            code = "host_action_failed"
            hint = "Check the simulator UDID, bundle id, Xcode selection, and underlying simctl availability."
        }
        detail = TKCLIErrorDetail(
            code: code,
            message: "\(error)",
            hint: hint
        )
    default:
        detail = TKCLIErrorDetail(
            code: "host_action_failed",
            message: "\(error)",
            hint: "Check the host tool availability and retry with explicit target parameters."
        )
    }

    switch outputFormat {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        print(detail.message)
        if let hint = detail.hint { print("hint: \(hint)") }
    }
    throw ExitCode.failure
}

func failHostValidation(code: String, message: String, hint: String, outputFormat: ClientOutputFormat) throws -> Never {
    let detail = TKCLIErrorDetail(code: code, message: message, hint: hint)
    switch outputFormat {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        print(message)
        print("hint: \(hint)")
    }
    throw ExitCode.failure
}
