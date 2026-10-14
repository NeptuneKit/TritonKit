import ArgumentParser
import CryptoKit
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
    sourceType: String? = nil,
    sourcesCaptured: [String]? = nil,
    streamLayout: String? = nil,
    artifactSensitive: Bool? = nil,
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
            sourceType: sourceType,
            sourcesCaptured: sourcesCaptured,
            streamLayout: streamLayout,
            artifactSensitive: artifactSensitive,
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
        let routed = try resizeAwareSimulatorScreenshotCommand(command, simulator: simulator)
        let result = try runHostCommand(routed)
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

func mediaSeedArtifacts(manifest: TKSimulatorMediaSeedManifest) -> [HostSimulatorMediaSeedArtifact] {
    var artifacts = [
        HostSimulatorMediaSeedArtifact(
            kind: "media-seed-manifest",
            path: manifest.manifestPath,
            role: "manifest",
            bytes: fileByteCount(path: manifest.manifestPath),
            contentType: "application/json",
            sha256: nil
        )
    ]
    artifacts += manifest.resolvedFiles.map { file in
        HostSimulatorMediaSeedArtifact(
            kind: "media-fixture-file",
            path: file.path,
            role: file.kind,
            bytes: fileByteCount(path: file.path),
            contentType: mediaSeedContentType(kind: file.kind, path: file.path),
            sha256: file.sha256
        )
    }
    return artifacts
}

func fileByteCount(path: String) -> UInt64? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
        return nil
    }
    if let size = attributes[.size] as? UInt64 {
        return size
    }
    if let size = attributes[.size] as? NSNumber {
        return size.uint64Value
    }
    return nil
}

private func mediaSeedContentType(kind: String, path: String) -> String? {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    switch ext {
    case "jpg", "jpeg":
        return "image/jpeg"
    case "png":
        return "image/png"
    case "gif":
        return "image/gif"
    case "heic", "heif":
        return "image/heic"
    case "mov":
        return "video/quicktime"
    case "mp4", "m4v":
        return "video/mp4"
    default:
        return kind == "image" ? "image/*" : kind == "video" ? "video/*" : nil
    }
}

private func value(after marker: String, before terminator: String, in line: String) -> String? {
    guard let markerRange = line.range(of: marker) else { return nil }
    let tail = line[markerRange.upperBound...]
    let end = tail.range(of: terminator)?.lowerBound ?? tail.endIndex
    let value = tail[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

func loadHostWorkspaceDefaults() throws -> TKHostWorkspaceDefaults? {
    let workspace = FileManager.default.currentDirectoryPath
    guard let store = try HostWorkspaceConfigStorage.existing(workspace: workspace),
          let data = try store.read(name: "host-defaults.json") else { return nil }
    return try JSONDecoder().decode(TKHostWorkspaceDefaults.self, from: data)
}

func saveHostWorkspaceDefaults(_ defaults: TKHostWorkspaceDefaults) throws -> String {
    let workspace = FileManager.default.currentDirectoryPath
    let store = try HostWorkspaceConfigStorage(workspace: workspace, create: true)
    try store.save(name: "host-defaults.json", data: JSONEncoder().encode(defaults), validate: {
        _ = try JSONDecoder().decode(TKHostWorkspaceDefaults.self, from: $0)
    })
    return TKHostWorkspaceDefaults.filePath(workspace: workspace)
}

func loadHostTargetAliasStore() throws -> HostTargetAliasStore {
    let workspace = FileManager.default.currentDirectoryPath
    guard let store = try HostWorkspaceConfigStorage.existing(workspace: workspace),
          let data = try store.read(name: "host-targets.json") else { return .empty }
    return try JSONDecoder().decode(HostTargetAliasStore.self, from: data)
}

func saveHostTargetAliasStore(_ store: HostTargetAliasStore) throws -> String {
    let workspace = FileManager.default.currentDirectoryPath
    let storage = try HostWorkspaceConfigStorage(workspace: workspace, create: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try storage.save(name: "host-targets.json", data: encoder.encode(store), validate: {
        _ = try JSONDecoder().decode(HostTargetAliasStore.self, from: $0)
    })
    return HostTargetAliasStore.filePath(workspace: workspace)
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

func makeHostScreenshotArtifactMetadata(outputPath: String) throws -> HostScreenshotArtifactMetadata {
    let data = try Data(contentsOf: URL(fileURLWithPath: outputPath), options: [.mappedIfSafe])
    let digest = SHA256.hash(data: data)
    let dimensions = try? readImageDimensions(path: outputPath)
    return HostScreenshotArtifactMetadata(
        bytes: data.count,
        width: dimensions?.width,
        height: dimensions?.height,
        sha256: digest.map { String(format: "%02x", $0) }.joined(),
        capturedAt: ISO8601DateFormatter().string(from: Date())
    )
}

private func readImageDimensions(path: String) throws -> (width: Int, height: Int) {
    if let png = try? readPNGDimensions(path: path) {
        return png
    }
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
        throw RuntimeError("Screenshot metadata could not be read: image dimensions are unavailable.")
    }
    return (width, height)
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
