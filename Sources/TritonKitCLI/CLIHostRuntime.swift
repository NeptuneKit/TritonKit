import ArgumentParser
import Darwin
import Foundation
import ImageIO
import TritonKitShared

func runSimpleHostCommand(
    action: String,
    runtimeScope: String = "host-simulator",
    target: String,
    selection: HostDeviceSelectionResult? = nil,
    command: TKHostCommand,
    outputFormat: ClientOutputFormat,
    artifacts: [String] = [],
    note: String? = nil,
    interruptAfter: Double? = nil
) throws {
    do {
        let result = try runHostCommand(command, interruptAfter: interruptAfter)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceCommand = redactHostActionSourceCommand(result.sourceCommand, selection: selection)
        let output = HostActionOutput(
            ok: true,
            action: action,
            runtimeScope: runtimeScope,
            target: target,
            selection: selection,
            tool: command.executable,
            exitCode: result.exitCode,
            riskLevel: command.riskLevel.rawValue,
            sourceCommand: sourceCommand,
            stdoutTruncated: result.stdoutTruncated,
            stderrTruncated: result.stderrTruncated,
            stdout: stdout.isEmpty ? nil : stdout,
            stderr: stderr.isEmpty ? nil : stderr,
            artifacts: artifacts,
            screenshot: action == "sim.screenshot" && artifacts.count == 1 ? (try? makeSimulatorScreenshotMetadata(outputPath: artifacts[0])) : nil,
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

func redactHostActionSourceCommand(_ sourceCommand: String, selection: HostDeviceSelectionResult?) -> String {
    guard let selection, selection.target.sensitive || selection.target.scope == "real" else {
        return sourceCommand
    }
    let rawTarget = selection.target.rawTarget
    guard !rawTarget.isEmpty, rawTarget != selection.target.target else {
        return sourceCommand
    }
    return sourceCommand.replacingOccurrences(of: rawTarget, with: selection.target.target)
}

func runHostCommandCapturingStdoutArtifact(
    action: String,
    runtimeScope: String = "host-simulator",
    target: String,
    command: TKHostCommand,
    outputPath: String,
    outputFormat: ClientOutputFormat,
    note: String? = nil
) throws {
    do {
        try prepareHostArtifactOutputPath(outputPath)
        let result = try runHostCommandWritingStdoutArtifact(command, outputPath: outputPath)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = HostArtifactCaptureOutput(
            ok: true,
            action: action,
            runtimeScope: runtimeScope,
            target: target,
            tool: command.executable,
            exitCode: result.exitCode,
            riskLevel: command.riskLevel.rawValue,
            sourceCommand: result.sourceCommand,
            artifact: outputPath,
            stdoutBytes: result.stdoutBytes,
            stderrBytes: result.stderrBytes,
            stdoutTruncated: result.stdoutTruncated,
            stderrTruncated: result.stderrTruncated,
            stderr: stderr.isEmpty ? nil : stderr,
            note: note
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            print(outputPath)
            if let note { print(note) }
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func runHostSimulatorScreenshotCommand(
    simulator: String,
    command: TKHostCommand,
    outputPath: String,
    outputFormat: ClientOutputFormat
) throws {
    do {
        let result = try runHostCommand(command)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let size = imagePixelSize(path: outputPath)
        let output = HostSimulatorScreenshotOutput(
            ok: true,
            action: "sim.screenshot",
            runtimeScope: "host-simulator",
            target: "sim:\(simulator)",
            tool: command.executable,
            exitCode: result.exitCode,
            riskLevel: command.riskLevel.rawValue,
            sourceCommand: result.sourceCommand,
            stdoutTruncated: result.stdoutTruncated,
            stderrTruncated: result.stderrTruncated,
            stderr: stderr.isEmpty ? nil : stderr,
            artifact: outputPath,
            pixelWidth: size?.width,
            pixelHeight: size?.height,
            display: parseSimctlScreenshotDisplayMetadata(stderr: result.stderr),
            orientationPolicy: "raw-framebuffer",
            orientationNote: "simctl io screenshot writes the simulator display framebuffer as provided by CoreSimulator. Triton reports this as raw framebuffer orientation and does not rotate iPad screenshots yet.",
            note: "Host-side simulator screenshot was written with raw framebuffer orientation metadata."
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            print(outputPath)
            print(output.orientationNote)
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func parseSimctlScreenshotDisplayMetadata(stderr: String) -> HostSimulatorScreenshotDisplayMetadata {
    let line = stderr
        .split(whereSeparator: \.isNewline)
        .map(String.init)
        .first { $0.contains("Defaulting to display:") || $0.contains("display:") }
    guard let line else {
        return HostSimulatorScreenshotDisplayMetadata(rawLine: nil, displayID: nil, screenID: nil, name: nil)
    }

    let displayID = value(after: "display:", before: "(", in: line)
    let screenID = value(after: "screenID:", before: ",", in: line)
    let name = value(after: "name:", before: ")", in: line)
    return HostSimulatorScreenshotDisplayMetadata(
        rawLine: line,
        displayID: displayID,
        screenID: screenID,
        name: name
    )
}

func imagePixelSize(path: String) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
        return nil
    }
    return (width, height)
}

private func value(after marker: String, before terminator: String, in line: String) -> String? {
    guard let markerRange = line.range(of: marker) else { return nil }
    let tail = line[markerRange.upperBound...]
    let end = tail.range(of: terminator)?.lowerBound ?? tail.endIndex
    let value = tail[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
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

func loadHostTargetAliasStore() throws -> HostTargetAliasStore {
    let path = HostTargetAliasStore.filePath(workspace: FileManager.default.currentDirectoryPath)
    guard FileManager.default.fileExists(atPath: path) else {
        return .empty
    }
    return try JSONDecoder().decode(HostTargetAliasStore.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
}

func saveHostTargetAliasStore(_ store: HostTargetAliasStore) throws -> String {
    let path = HostTargetAliasStore.filePath(workspace: FileManager.default.currentDirectoryPath)
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(store).write(to: url, options: [.atomic])
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

func makeSimulatorScreenshotMetadata(outputPath: String) throws -> HostSimulatorScreenshotMetadata {
    let dimensions = try? readPNGDimensions(path: outputPath)
    return HostSimulatorScreenshotMetadata(
        path: outputPath,
        contentType: "image/png",
        pixelWidth: dimensions?.width,
        pixelHeight: dimensions?.height,
        orientationSemantics: "raw-simctl-framebuffer",
        normalizationApplied: false,
        normalizationStrategy: "metadata-only",
        note: "TritonKit preserves the raw framebuffer orientation emitted by `xcrun simctl io screenshot`; compare pixelWidth/pixelHeight and simulator display state before treating this artifact as a display-normalized screenshot."
    )
}

private func readPNGDimensions(path: String) throws -> (width: Int, height: Int) {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    guard data.count >= 24 else {
        throw RuntimeError("Screenshot metadata could not be read: PNG file is too short.")
    }
    let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    guard Array(data.prefix(8)) == signature else {
        throw RuntimeError("Screenshot metadata could not be read: output is not a PNG file.")
    }
    guard String(data: data[12..<16], encoding: .ascii) == "IHDR" else {
        throw RuntimeError("Screenshot metadata could not be read: PNG IHDR chunk is missing.")
    }
    let width = data[16..<20].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    let height = data[20..<24].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    return (Int(width), Int(height))
}
