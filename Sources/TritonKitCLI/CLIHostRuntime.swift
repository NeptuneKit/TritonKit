import ArgumentParser
import Darwin
import Foundation
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
        let output = HostActionOutput(
            ok: true,
            action: action,
            runtimeScope: runtimeScope,
            target: target,
            selection: selection,
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

private struct HostPipeDrainResult {
    let data: Data
    let bytes: Int
    let truncated: Bool
}

private func drainPipe(_ pipe: Pipe, maximumBytes: Int?) -> HostPipeDrainResult {
    let handle = pipe.fileHandleForReading
    var data = Data()
    var bytes = 0
    var truncated = false
    while true {
        guard let chunk = try? handle.read(upToCount: 64 * 1024), !chunk.isEmpty else {
            break
        }
        bytes += chunk.count
        guard let maximumBytes else {
            data.append(chunk)
            continue
        }
        let remaining = maximumBytes - data.count
        if remaining > 0 {
            data.append(chunk.prefix(remaining))
        }
        if chunk.count > remaining || bytes > maximumBytes {
            truncated = true
        }
    }
    return HostPipeDrainResult(data: data, bytes: bytes, truncated: truncated)
}

private func drainPipeToFile(_ pipe: Pipe, outputPath: String) -> (bytes: Int, error: Error?) {
    let flags = O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW
    let fd = open(outputPath, flags, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
    guard fd >= 0 else {
        let message = String(cString: strerror(errno))
        return (0, HostArtifactOutputError.rejected(path: outputPath, reason: message))
    }
    let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? output.close() }
    let input = pipe.fileHandleForReading
    var bytes = 0
    while true {
        guard let chunk = try? input.read(upToCount: 64 * 1024), !chunk.isEmpty else {
            break
        }
        do {
            try output.write(contentsOf: chunk)
            bytes += chunk.count
        } catch {
            return (bytes, error)
        }
    }
    return (bytes, nil)
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

func hostDeviceTargets(platform: HostDevicePlatform, hdc: String) throws -> (targets: [HostDeviceTarget], sourceCommand: String) {
    switch platform {
    case .ios:
        let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
        let targets = try TKSimctlDeviceListParser.parse(result.stdoutData).map(hostDeviceTarget(from:))
        return (targets, result.sourceCommand)
    case .harmony:
        let result = try runHostCommand(TKHarmonyHDCCommand.listTargets(executable: hdc))
        let targets = TKHdcTargetListParser.parse(result.stdout).map(hostDeviceTarget(from:))
        return (targets, result.sourceCommand)
    }
}

func hostDeviceTargetsByPlatform(platform: HostDevicePlatform?, hdc: String) throws -> [HostDevicePlatform: [HostDeviceTarget]] {
    if let platform {
        return [platform: try hostDeviceTargets(platform: platform, hdc: hdc).targets]
    }
    var targets: [HostDevicePlatform: [HostDeviceTarget]] = [:]
    for platform in [HostDevicePlatform.ios, .harmony] {
        targets[platform] = (try? hostDeviceTargets(platform: platform, hdc: hdc).targets) ?? []
    }
    return targets
}

func selectHostDeviceTarget(target: String?, candidates: [HostDeviceTarget]) -> HostDeviceTarget? {
    if let target {
        if target.lowercased() == "booted" {
            let ready = candidates.filter(\.ready)
            return ready.count == 1 ? ready[0] : nil
        }
        return candidates.first(where: { $0.target == target || $0.id == target })
    }
    let ready = candidates.filter(\.ready)
    if ready.count == 1 {
        return ready[0]
    }
    if candidates.count == 1 {
        return candidates[0]
    }
    return nil
}

private func hostDeviceSelectionError(platform: HostDevicePlatform, target: String?, candidates: [HostDeviceTarget]) -> HostDeviceSelectionError {
    if let target {
        return .targetNotFound(target)
    }
    if candidates.isEmpty {
        return .targetNotFound(platform == .ios ? "booted simulator" : "connected target")
    }
    return .ambiguousTargets(candidates)
}

private func platform(from target: HostDeviceTarget) -> HostDevicePlatform? {
    HostDevicePlatform(rawValue: target.platform)
}

private func normalizedContains(_ value: String?, query: String?) -> Bool {
    guard let query, !query.isEmpty else { return true }
    return value?.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
}

private func matchesHostDeviceFilters(_ target: HostDeviceTarget, request: HostDeviceSelectionRequest) -> Bool {
    if let platform = request.platform, target.platform != platform.rawValue {
        return false
    }
    if !normalizedContains(target.name, query: request.name) {
        return false
    }
    if !normalizedContains(target.runtime, query: request.runtime) {
        return false
    }
    if let state = request.state, target.state.compare(state, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame {
        return false
    }
    if request.ready, !target.ready {
        return false
    }
    return true
}

private func explicitHostDeviceMatch(selector: String, candidates: [HostDeviceTarget]) -> HostDeviceTarget? {
    let normalizedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalizedSelector == "booted" {
        let booted = candidates.filter { $0.platform == HostDevicePlatform.ios.rawValue && $0.ready }
        return booted.count == 1 ? booted[0] : nil
    }
    if normalizedSelector.hasPrefix("triton:ios-simulator:") {
        let udid = String(normalizedSelector.dropFirst("triton:ios-simulator:".count))
        return candidates.first { $0.platform == HostDevicePlatform.ios.rawValue && $0.target == udid }
    }
    return candidates.first { $0.id == normalizedSelector || $0.target == normalizedSelector }
}

private func uniqueHostDeviceTarget(
    selector: String,
    source: HostDeviceSelectorSource,
    request: HostDeviceSelectionRequest,
    candidates: [HostDeviceTarget]
) throws -> HostDeviceSelectionResult {
    let ready = candidates.filter(\.ready)
    let selected: HostDeviceTarget?
    if ready.count == 1 {
        selected = ready[0]
    } else if candidates.count == 1 {
        selected = candidates[0]
    } else {
        selected = nil
    }
    guard let selected, let platform = platform(from: selected) else {
        if candidates.isEmpty {
            throw HostDeviceSelectionError.targetNotFound(selector)
        }
        throw HostDeviceSelectionError.ambiguousTargets(candidates)
    }
    return HostDeviceSelectionResult(
        platform: platform,
        target: selected,
        selector: selector,
        source: source,
        filters: HostDeviceSelectionFilters(request: request)
    )
}

func resolveHostDeviceSelection(
    request: HostDeviceSelectionRequest,
    candidates: [HostDevicePlatform: [HostDeviceTarget]],
    aliases: HostTargetAliasStore
) throws -> HostDeviceSelectionResult {
    let allCandidates = candidates.values.flatMap { $0 }
    if let selector = request.device, !selector.isEmpty {
        if selector == "current" {
            guard let current = aliases.current else {
                throw HostDeviceSelectionError.targetNotFound("current")
            }
            var currentRequest = request
            currentRequest.device = current
            let selected = try resolveHostDeviceSelection(request: currentRequest, candidates: candidates, aliases: aliases)
            return HostDeviceSelectionResult(
                platform: selected.platform,
                target: selected.target,
                selector: selector,
                source: .current,
                filters: selected.filters
            )
        }
        if let alias = aliases.aliases[selector] {
            if let requestedPlatform = request.platform, requestedPlatform != alias.platform {
                throw HostDeviceSelectionError.platformMismatch(selector: selector, expected: requestedPlatform, actual: alias.platform)
            }
            let platformCandidates = candidates[alias.platform] ?? []
            guard let selected = explicitHostDeviceMatch(selector: alias.target, candidates: platformCandidates) else {
                throw HostDeviceSelectionError.targetNotFound(selector)
            }
            return HostDeviceSelectionResult(
                platform: alias.platform,
                target: selected,
                selector: selector,
                source: .alias,
                filters: HostDeviceSelectionFilters(request: request)
            )
        }
        let filtered = allCandidates.filter { matchesHostDeviceFilters($0, request: request) }
        guard let selected = explicitHostDeviceMatch(selector: selector, candidates: filtered), let platform = platform(from: selected) else {
            if selector == "booted" {
                let booted = filtered.filter { $0.platform == HostDevicePlatform.ios.rawValue && $0.ready }
                if booted.count > 1 {
                    throw HostDeviceSelectionError.ambiguousTargets(booted)
                }
            }
            throw HostDeviceSelectionError.targetNotFound(selector)
        }
        return HostDeviceSelectionResult(
            platform: platform,
            target: selected,
            selector: selector,
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: request)
        )
    }

    let filtered = allCandidates.filter { matchesHostDeviceFilters($0, request: request) }
    let selector = request.platform?.rawValue ?? "ready"
    return try uniqueHostDeviceTarget(
        selector: selector,
        source: request.platform == nil ? .globalUnique : .platformFilter,
        request: request,
        candidates: filtered
    )
}

func resolveHostDeviceSelection(request: HostDeviceSelectionRequest, hdc: String) throws -> HostDeviceSelectionResult {
    let aliases = try loadHostTargetAliasStore()
    let candidates = try hostDeviceTargetsByPlatform(platform: request.platform, hdc: hdc)
    return try resolveHostDeviceSelection(request: request, candidates: candidates, aliases: aliases)
}

func hostDeviceCurrentSelector(
    explicitSelector: String?,
    explicitTarget: String?,
    selected: HostDeviceSelectionResult
) -> String {
    if let explicitSelector, !explicitSelector.isEmpty {
        return explicitSelector
    }
    if let explicitTarget, !explicitTarget.isEmpty {
        return explicitTarget
    }
    return selected.target.id
}

func resolveHostDeviceTarget(platform: HostDevicePlatform, target: String?, hdc: String) throws -> HostDeviceTarget {
    switch platform {
    case .ios:
        let candidates = try hostDeviceTargets(platform: platform, hdc: hdc).targets
        guard let selected = selectHostDeviceTarget(target: target, candidates: candidates) else {
            throw hostDeviceSelectionError(platform: platform, target: target, candidates: candidates)
        }
        return selected
    case .harmony:
        let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
        return hostDeviceTarget(from: selected)
    }
}

func hostDeviceTarget(from simulator: TKHostSimulatorTarget) -> HostDeviceTarget {
    HostDeviceTarget(
        platform: "ios",
        id: simulator.id,
        target: simulator.udid,
        state: simulator.state,
        ready: simulator.isBooted,
        source: simulator.source,
        name: simulator.name,
        runtime: simulator.runtime,
        transport: nil
    )
}

func hostDeviceTarget(from target: TKHarmonyTarget) -> HostDeviceTarget {
    HostDeviceTarget(
        platform: "harmony",
        id: target.id,
        target: target.target,
        state: target.state,
        ready: target.isConnected,
        source: target.source,
        name: nil,
        runtime: nil,
        transport: target.transport
    )
}

func harmonyTarget(from target: HostDeviceTarget) -> TKHarmonyTarget {
    TKHarmonyTarget(
        target: target.target,
        state: target.state,
        transport: target.transport ?? "hdc",
        source: target.source
    )
}

func ensureParentDirectory(for path: String) throws {
    let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}

func prepareHostArtifactOutputPath(_ path: String) throws {
    try ensureParentDirectory(for: path)
    if (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil {
        throw HostArtifactOutputError.rejected(path: path, reason: "symbolic links are not accepted for artifact output")
    }
    if FileManager.default.fileExists(atPath: path) {
        throw HostArtifactOutputError.rejected(path: path, reason: "path already exists")
    }
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

func captureHostDeviceScreenshot(platform: HostDevicePlatform, target: HostDeviceTarget, selection: HostDeviceSelectionResult? = nil, hdc: String, output: String) throws -> HostDeviceArtifactOutput {
    guard target.ready else {
        throw HostCommandRunError.deviceNotReady(target: target.target, timeoutSeconds: 0)
    }
    switch platform {
    case .ios:
        try prepareHostArtifactOutputPath(output)
        let result = try runHostCommand(TKSimctlCommand.screenshot(udid: target.target, output: output))
        return HostDeviceArtifactOutput(
            ok: true,
            action: "screenshot",
            platform: platform.rawValue,
            target: target,
            selection: selection,
            artifact: output,
            sourceCommands: [result.sourceCommand],
            note: "Host-side iOS simulator screenshot was written."
        )
    case .harmony:
        let capture = try captureHarmonyScreenshot(selected: harmonyTarget(from: target), hdc: hdc, output: output)
        return HostDeviceArtifactOutput(
            ok: true,
            action: "screenshot",
            platform: platform.rawValue,
            target: target,
            selection: selection,
            artifact: output,
            sourceCommands: capture.sourceCommands,
            note: "Host-side Harmony screenshot was captured through snapshot_display using remote artifact \(capture.remotePath)."
        )
    }
}

func waitForHostDeviceReady(
    platform: HostDevicePlatform,
    selected: HostDeviceTarget,
    hdc: String,
    timeout: Double,
    interval: Double
) async throws -> HostDeviceReadyEvent {
    let startedAt = Date()
    let deadline = startedAt.addingTimeInterval(timeout)
    var attempt = 0
    while Date() <= deadline {
        attempt += 1
        switch platform {
        case .ios:
            let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
            let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
            guard let simulator = simulators.first(where: { $0.udid == selected.target || $0.id == selected.id }) else {
                throw HostDeviceSelectionError.targetNotFound(selected.target)
            }
            let currentTarget = hostDeviceTarget(from: simulator)
            let event = HostDeviceReadyEvent(
                ok: currentTarget.ready,
                platform: platform.rawValue,
                target: currentTarget,
                ready: currentTarget.ready,
                attempt: attempt,
                sourceCommand: result.sourceCommand,
                error: nil
            )
            if currentTarget.ready {
                return event
            }
        case .harmony:
            let harmonyTarget = harmonyTarget(from: selected)
            let command = TKHarmonyHDCCommand.bootCompleted(target: harmonyTarget.target, executable: hdc)
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
            if ready {
                return event
            }
        }
        if Date() >= deadline {
            break
        }
        try await Task.sleep(nanoseconds: UInt64(max(0.1, interval) * 1_000_000_000))
    }
    throw HostCommandRunError.deviceNotReady(target: selected.target, timeoutSeconds: timeout)
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

func runHostCommand(
    _ command: TKHostCommand,
    interruptAfter: Double? = nil,
    maximumOutputBytes: Int? = 1_048_576
) throws -> HostProcessResult {
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
    let stdinData = command.stdinData
    let stdinPipe: Pipe? = stdinData.map { _ in Pipe() }
    if let stdinPipe {
        process.standardInput = stdinPipe
    }

    do {
        try process.run()
    } catch {
        throw HostCommandRunError.launchFailed(error.localizedDescription)
    }
    if let stdinData, let stdinPipe {
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: stdinData)
            try stdinPipe.fileHandleForWriting.close()
        } catch {
            process.terminate()
            throw HostCommandRunError.launchFailed(error.localizedDescription)
        }
    }
    if let interruptAfter {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + interruptAfter) {
            if process.isRunning {
                process.interrupt()
            }
        }
    }
    let stdoutGroup = DispatchGroup()
    let stderrGroup = DispatchGroup()
    var stdoutRead = HostPipeDrainResult(data: Data(), bytes: 0, truncated: false)
    var stderrRead = HostPipeDrainResult(data: Data(), bytes: 0, truncated: false)
    stdoutGroup.enter()
    DispatchQueue.global(qos: .utility).async {
        stdoutRead = drainPipe(stdout, maximumBytes: maximumOutputBytes)
        stdoutGroup.leave()
    }
    stderrGroup.enter()
    DispatchQueue.global(qos: .utility).async {
        stderrRead = drainPipe(stderr, maximumBytes: maximumOutputBytes)
        stderrGroup.leave()
    }

    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .utility).async {
        process.waitUntilExit()
        semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
        process.terminate()
        if semaphore.wait(timeout: .now() + 2) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            _ = semaphore.wait(timeout: .now() + 2)
        }
        if stdoutGroup.wait(timeout: .now() + 2) == .timedOut {
            try? stdout.fileHandleForReading.close()
            _ = stdoutGroup.wait(timeout: .now() + 1)
        }
        if stderrGroup.wait(timeout: .now() + 2) == .timedOut {
            try? stderr.fileHandleForReading.close()
            _ = stderrGroup.wait(timeout: .now() + 1)
        }
        throw HostCommandRunError.timeout(command: command, timeoutSeconds: timeoutSeconds, stdoutLogPath: nil, stderrLogPath: nil)
    }
    stdoutGroup.wait()
    stderrGroup.wait()

    let result = HostProcessResult(
        stdoutData: stdoutRead.data,
        stderrData: stderrRead.data,
        exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: stdoutRead.truncated,
        stderrTruncated: stderrRead.truncated,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: stdoutRead.bytes,
        stderrBytes: stderrRead.bytes
    )
    if result.exitCode != 0 {
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    return result
}

func runHostCommandWritingStdoutArtifact(_ command: TKHostCommand, outputPath: String) throws -> HostProcessResult {
    try prepareHostArtifactOutputPath(outputPath)
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

    let stdoutGroup = DispatchGroup()
    let stderrGroup = DispatchGroup()
    var stdoutBytes = 0
    var stdoutError: Error?
    var stderrRead = HostPipeDrainResult(data: Data(), bytes: 0, truncated: false)
    stdoutGroup.enter()
    DispatchQueue.global(qos: .utility).async {
        let result = drainPipeToFile(stdout, outputPath: outputPath)
        stdoutBytes = result.bytes
        stdoutError = result.error
        stdoutGroup.leave()
    }
    stderrGroup.enter()
    DispatchQueue.global(qos: .utility).async {
        stderrRead = drainPipe(stderr, maximumBytes: 1_048_576)
        stderrGroup.leave()
    }

    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .utility).async {
        process.waitUntilExit()
        semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
        process.terminate()
        if semaphore.wait(timeout: .now() + 2) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            _ = semaphore.wait(timeout: .now() + 2)
        }
        if stdoutGroup.wait(timeout: .now() + 2) == .timedOut {
            try? stdout.fileHandleForReading.close()
            _ = stdoutGroup.wait(timeout: .now() + 1)
        }
        if stderrGroup.wait(timeout: .now() + 2) == .timedOut {
            try? stderr.fileHandleForReading.close()
            _ = stderrGroup.wait(timeout: .now() + 1)
        }
        throw HostCommandRunError.timeout(command: command, timeoutSeconds: timeoutSeconds, stdoutLogPath: outputPath, stderrLogPath: nil)
    }
    stdoutGroup.wait()
    stderrGroup.wait()
    if let stdoutError {
        try? FileManager.default.removeItem(atPath: outputPath)
        throw HostCommandRunError.launchFailed(stdoutError.localizedDescription)
    }

    let result = HostProcessResult(
        stdoutData: Data(),
        stderrData: stderrRead.data,
        exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: false,
        stderrTruncated: stderrRead.truncated,
        stdoutLogPath: outputPath,
        stderrLogPath: nil,
        stdoutBytes: stdoutBytes,
        stderrBytes: stderrRead.bytes
    )
    if result.exitCode != 0 {
        try? FileManager.default.removeItem(atPath: outputPath)
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    return result
}

func truncatedData(_ data: Data, maximumBytes: Int? = 1_048_576) -> (data: Data, truncated: Bool) {
    guard let maximumBytes else {
        return (data, false)
    }
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
    if let exitCode = error as? ExitCode {
        throw exitCode
    }

    let detail: TKCLIErrorDetail
    var hostDeviceCandidates: [HostDeviceTarget]?
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
    case HostDeviceSelectionError.ambiguousTargets(let targets):
        hostDeviceCandidates = targets
        detail = TKCLIErrorDetail(
            code: "ambiguous_target",
            message: "\(error)",
            hint: "Narrow with --device, --platform, --name, --runtime, --state, or --ready.",
            nearestCandidates: targets.map(\.target),
            suggestedCommands: [
                "triton device alias set <name> --platform <ios|harmony> --target <id> --json",
                "triton <command> --device <alias-or-id> --json",
            ],
            candidateCount: targets.count
        )
    case HostDeviceSelectionError.targetNotFound:
        detail = TKCLIErrorDetail(
            code: "target_not_found",
            message: "\(error)",
            hint: "Run `triton device list --platform ios --json` or `triton device list --platform harmony --json`, then retry with --device <alias-or-id>."
        )
    case HostDeviceSelectionError.platformMismatch:
        detail = TKCLIErrorDetail(
            code: "target_platform_mismatch",
            message: "\(error)",
            hint: "Remove --platform or pick an alias/id for the requested platform."
        )
    case HostDeviceSelectionError.parameterConflict:
        detail = TKCLIErrorDetail(
            code: "parameter_conflict",
            message: "\(error)",
            hint: "Use --device as the unified selector, or keep the legacy --simulator / --target path, but do not combine them."
        )
    case HostCommandRunError.deviceNotReady:
        detail = TKCLIErrorDetail(
            code: "device_not_ready",
            message: "\(error)",
            hint: "Check target readiness with `triton device wait-ready`, boot the simulator/emulator if needed, or select a ready target."
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
    case XcresultCLIError.parseFailed:
        detail = TKCLIErrorDetail(
            code: "xcresult_parse_failed",
            message: "\(error)",
            hint: "The .xcresult may have been produced by an unsupported Xcode version. Keep the bundle and file an issue with sanitized compact xcresulttool JSON output."
        )
    case XcresultCLIError.outputTooLarge:
        detail = TKCLIErrorDetail(
            code: "xcresult_output_too_large",
            message: "\(error)",
            hint: "Use a smaller result bundle or wait for the follow-up artifact-backed xcresult parser; do not attach raw private xcresult JSON to public issues."
        )
    case let error as HostArtifactOutputError:
        detail = TKCLIErrorDetail(
            code: "artifact_output_rejected",
            message: "\(error)",
            hint: "Use a fresh artifact path under an explicit output directory. Existing files and symbolic links are rejected to avoid accidental overwrite."
        )
    case TKSimctlAppInfoParserError.emptyInfo:
        detail = TKCLIErrorDetail(
            code: "app_info_not_available",
            message: "Installed app information is not available.",
            hint: "Verify the simulator is booted and the bundle id is installed."
        )
    case HostCommandRunError.nonZeroExit(let command, let result):
        let code: String
        let hint: String
        let isHDC = command.executable == "hdc" || command.executable.hasSuffix("/hdc")
        let simctlSubcommand = command.arguments.dropFirst().first
        if command.executable == "xcodebuild" {
            code = "xcodebuild_failed"
            hint = "Inspect the xcodebuild output, verify workspace/project, scheme, destination, signing, and DerivedData path."
        } else if command.arguments.first == "xctrace" {
            code = "xctrace_record_failed"
            hint = "Verify the template, target device, attach/launch selection, time limit, privacy prompt state, and output path."
        } else if command.arguments.first == "xcresulttool" {
            if result.stderr.lowercased().contains("no such file") || result.stderr.lowercased().contains("does not exist") || result.stderr.lowercased().contains("not found") {
                code = "result_bundle_not_found"
                hint = "Verify the .xcresult path exists and points to a complete result bundle."
            } else {
                code = "xcresulttool_failed"
                hint = "Verify the result bundle path and inspect the xcresulttool output."
            }
        } else if command.arguments.first == "xccov" {
            code = "coverage_report_failed"
            hint = "Verify the .xcresult contains coverage data and that --target or --file matches the coverage report."
        } else if isHDC && command.arguments.contains("list") && command.arguments.contains("targets") {
            code = "host_action_failed"
            hint = "Verify hdc is installed, available on PATH, and can list Harmony targets."
        } else if command.arguments.contains("status_bar") {
            code = "status_bar_operation_failed"
            hint = "Verify the simulator is booted and the requested status bar flags are supported."
        } else if command.arguments.contains("diagnose") {
            code = "sim_diagnose_failed"
            hint = "Verify the simulator is booted, the output path is writable, and the requested log/archive flags are supported."
        } else if command.arguments.contains("logverbose") {
            code = "sim_logverbose_failed"
            hint = "Verify the simulator is booted and the requested verbose logging state is supported."
        } else if command.arguments.contains("recordVideo") {
            code = "sim_record_failed"
            hint = "Verify the simulator is booted, the output path is writable, and the requested codec, display, and mask options are supported."
        } else if command.arguments.contains("stream") && command.arguments.contains("log") {
            code = "sim_logs_failed"
            hint = "Verify the simulator is booted, the output path is writable, and the requested predicate, level, style, and type options are supported."
        } else if command.arguments.contains("privacy") {
            code = "privacy_operation_failed"
            hint = "Verify the simulator is booted, the privacy service is supported, and the bundle id is installed."
        } else if command.arguments.contains("location") {
            code = "location_operation_failed"
            hint = "Verify the simulator is booted and the requested location scenario or coordinate is valid."
        } else if command.arguments.contains("ui") {
            code = "ui_operation_failed"
            hint = "Verify the simulator is booted and the requested UI option is supported."
        } else if command.arguments.contains("pbcopy") || command.arguments.contains("pbpaste") || command.arguments.contains("pbsync") {
            code = "pasteboard_operation_failed"
            hint = "Verify the simulator is booted and the requested pasteboard endpoints are valid."
        } else if command.arguments.contains("push") {
            code = "push_payload_invalid"
            hint = "Verify the push payload path or stdin payload, bundle id, and JSON structure."
        } else if simctlSubcommand == "pair" {
            code = "sim_pair_failed"
            hint = "Verify the watch and phone simulator UDIDs exist and are compatible."
        } else if simctlSubcommand == "unpair" {
            code = "sim_unpair_failed"
            hint = "Verify the device pair UUID exists. Run `xcrun simctl list pairs` if Triton schema does not yet expose pair listing."
        } else if simctlSubcommand == "clone" {
            code = "sim_clone_failed"
            hint = "Verify the source simulator exists, the new name is valid, and the destination device set path is writable."
        } else if simctlSubcommand == "erase" {
            code = "sim_erase_failed"
            hint = "Verify the simulator exists, is not in an incompatible state, and the erase was intentionally run with --confirm."
        } else if simctlSubcommand == "upgrade" {
            code = "sim_upgrade_failed"
            hint = "Verify the simulator exists and the runtime identifier is newer and available on this machine."
        } else if command.arguments.contains("personalization") {
            code = "sim_personalization_failed"
            hint = "Verify the personalization action, runtime or manifest identifier, and whether the destructive action requires --confirm."
        } else if command.arguments.contains("runtime") && command.arguments.contains("add") {
            code = "runtime_add_failed"
            hint = "Verify the runtime image path exists and the runtime can be staged, verified, and mounted."
        } else if command.arguments.contains("runtime") && command.arguments.contains("delete") {
            code = "runtime_delete_failed"
            hint = "Run with --dry-run first, then pass --confirm only when deleting the selected runtimes is intentional."
        } else if command.arguments.contains("runtime") && command.arguments.contains("unmount") {
            code = "runtime_unmount_failed"
            hint = "Verify the runtime identifier exists and no required simulator is actively using it."
        } else if command.arguments.contains("runtime") && command.arguments.contains("scan-and-mount") {
            code = "runtime_scan_and_mount_failed"
            hint = "Verify CoreSimulator runtime storage is readable and retry after any active simulator maintenance finishes."
        } else if command.arguments.contains("runtime") && command.arguments.contains("match") {
            code = "runtime_match_failed"
            hint = "Verify the SDK canonical name, runtime build, and optional SDK build match installed Xcode/runtime data."
        } else if command.arguments.contains("runtime") && command.arguments.contains("dyld_shared_cache") {
            code = "runtime_dyld_cache_failed"
            hint = "Verify the runtime identifier exists; removal requires an intentional --confirm gate in Triton."
        } else if command.arguments.contains("runtime") && command.arguments.contains("verify") {
            code = "runtime_verify_failed"
            hint = "Verify the runtime identifier and that the selected runtime is installed and verifiable."
        } else if command.arguments.contains("runtime") && command.arguments.contains("list") {
            code = "runtime_list_failed"
            hint = "Verify simctl can list installed simulator runtimes on this machine."
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
        if let hostDeviceCandidates {
            print(try encodeJSON(HostDeviceSelectionErrorOutput(ok: false, error: detail, candidates: hostDeviceCandidates)))
        } else {
            print(try encodeJSON(TKCLIErrorResponse(error: detail)))
        }
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
