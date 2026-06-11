import Foundation
import TritonKitShared

typealias HostDeviceCommandRunner = (TKHostCommand) throws -> HostProcessResult

func resolveHarmonyTarget(target: String?, hdc: String) throws -> TKHarmonyTarget {
    let targets = try harmonyTargets(hdc: hdc).targets
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

func hostDeviceTargets(platform: HostDevicePlatform, scope: HostDeviceScope? = nil, hdc: String, adb: String = "adb") throws -> (targets: [HostDeviceTarget], sourceCommand: String) {
    switch platform {
    case .ios:
        return try iosHostDeviceTargets(scope: scope)
    case .harmony:
        return try harmonyHostDeviceTargets(scope: scope, hdc: hdc)
    case .android:
        let result = try runHostCommand(TKAndroidADBCommand.listDevices(executable: adb))
        let parsed = TKAdbDeviceListParser.parse(result.stdout)
        let androidScope = androidDeviceScope(from: scope)
        let targets = TKAdbDeviceListParser.targets(parsed, matching: androidScope).map(hostDeviceTarget(from:))
        return (targets, result.sourceCommand)
    }
}

func harmonyHostDeviceTargets(
    scope: HostDeviceScope? = nil,
    hdc: String,
    runner: HostDeviceCommandRunner = { command in try runHostCommand(command) }
) throws -> (targets: [HostDeviceTarget], sourceCommand: String) {
    let result = try harmonyTargets(hdc: hdc, runner: runner)
    let targets = result.targets.map(hostDeviceTarget(from:))
    return (filterHostDeviceTargets(targets, scope: scope), result.sourceCommand)
}

func harmonyTargets(
    hdc: String,
    runner: HostDeviceCommandRunner = { command in try runHostCommand(command) }
) throws -> (targets: [TKHarmonyTarget], sourceCommand: String) {
    let verboseResult = try runner(TKHarmonyHDCCommand.listTargets(executable: hdc))
    let verboseTargets = parseHarmonyTargets(from: verboseResult)
    guard verboseTargets.isEmpty else {
        return (verboseTargets, verboseResult.sourceCommand)
    }
    do {
        let plainResult = try runner(TKHarmonyHDCCommand.listTargetsPlain(executable: hdc))
        let plainTargets = parseHarmonyTargets(from: plainResult)
        return (plainTargets, [verboseResult.sourceCommand, plainResult.sourceCommand].joined(separator: "\n"))
    } catch {
        return (verboseTargets, verboseResult.sourceCommand)
    }
}

private func parseHarmonyTargets(from result: HostProcessResult) -> [TKHarmonyTarget] {
    TKHdcTargetListParser.parse([result.stdout, result.stderr].joined(separator: "\n"))
}

private func iosHostDeviceTargets(scope: HostDeviceScope?) throws -> (targets: [HostDeviceTarget], sourceCommand: String) {
    switch scope {
    case .real:
        return try iosRealDeviceTargets()
    case .emulator:
        return ([], "ios scope emulator is not applicable")
    case .all:
        let simulatorResult = try iosSimulatorDeviceTargets()
        do {
            let realResult = try iosRealDeviceTargets()
            return (simulatorResult.targets + realResult.targets, [simulatorResult.sourceCommand, realResult.sourceCommand].joined(separator: "\n"))
        } catch {
            return simulatorResult
        }
    case .simulator, nil:
        return try iosSimulatorDeviceTargets()
    }
}

private func iosSimulatorDeviceTargets() throws -> (targets: [HostDeviceTarget], sourceCommand: String) {
    let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
    let targets = try TKSimctlDeviceListParser.parse(result.stdoutData).map(hostDeviceTarget(from:))
    return (targets, result.sourceCommand)
}

private func iosRealDeviceTargets() throws -> (targets: [HostDeviceTarget], sourceCommand: String) {
    let artifacts = try freshDevicectlArtifactPaths(action: "list-devices")
    let command = TKDevicectlCommand.listDevices(jsonOutput: artifacts.json, logOutput: artifacts.log)
    let result = try runHostCommand(command)
    guard FileManager.default.fileExists(atPath: artifacts.json) else {
        throw IOSDevicectlRunError.jsonMissing(path: artifacts.json)
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: artifacts.json))
    do {
        let targets = try TKDevicectlDeviceListParser.parse(data).map(hostDeviceTarget(from:))
        return (targets, result.sourceCommand)
    } catch let error as TKDevicectlParserError {
        throw IOSDevicectlRunError.jsonParseFailed(error)
    }
}

func freshDevicectlArtifactPaths(action: String) throws -> (json: String, log: String) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-devicectl-\(action)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let json = directory.appendingPathComponent("\(action).json").path
    let log = directory.appendingPathComponent("\(action).log").path
    try prepareHostArtifactOutputPath(json)
    try prepareHostArtifactOutputPath(log)
    return (json, log)
}

enum IOSDevicectlRunError: Error, CustomStringConvertible {
    case jsonMissing(path: String)
    case jsonParseFailed(TKDevicectlParserError)

    var description: String {
        switch self {
        case .jsonMissing(let path):
            "devicectl did not write JSON output at \(path)"
        case .jsonParseFailed(let error):
            "devicectl JSON output could not be parsed: \(error)"
        }
    }
}

func hostDeviceTargetsByPlatform(platform: HostDevicePlatform?, scope: HostDeviceScope? = nil, hdc: String, adb: String = "adb") throws -> [HostDevicePlatform: [HostDeviceTarget]] {
    if let platform {
        return [platform: try hostDeviceTargets(platform: platform, scope: scope, hdc: hdc, adb: adb).targets]
    }
    var targets: [HostDevicePlatform: [HostDeviceTarget]] = [:]
    for platform in [HostDevicePlatform.ios, .android, .harmony] {
        targets[platform] = (try? hostDeviceTargets(platform: platform, scope: scope, hdc: hdc, adb: adb).targets) ?? []
    }
    return targets
}

private func androidDeviceScope(from scope: HostDeviceScope?) -> TKAndroidDeviceScope? {
    switch scope {
    case .emulator:
        return .emulator
    case .real:
        return .real
    case .simulator, .all, nil:
        return nil
    }
}

private func filterHostDeviceTargets(_ targets: [HostDeviceTarget], scope: HostDeviceScope?) -> [HostDeviceTarget] {
    guard let scope, scope != .all else { return targets }
    return targets.filter { $0.scope == scope.rawValue }
}

func selectHostDeviceTarget(target: String?, candidates: [HostDeviceTarget]) -> HostDeviceTarget? {
    if let target {
        if target.lowercased() == "booted" {
            let ready = candidates.filter(\.ready)
            return ready.count == 1 ? ready[0] : nil
        }
        return candidates.first(where: { $0.target == target || $0.id == target || $0.rawTarget == target })
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
        switch platform {
        case .ios:
            return .targetNotFound("booted simulator")
        case .android:
            return .targetNotFound("connected Android emulator")
        case .harmony:
            return .targetNotFound("connected target")
        }
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
    if let scope = request.scope, scope != .all, target.scope != scope.rawValue {
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
    return candidates.first { $0.id == normalizedSelector || $0.target == normalizedSelector || $0.rawTarget == normalizedSelector }
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

func resolveHostDeviceSelection(request: HostDeviceSelectionRequest, hdc: String, adb: String = "adb") throws -> HostDeviceSelectionResult {
    let aliases = try loadHostTargetAliasStore()
    let candidates = try hostDeviceTargetsByPlatform(platform: request.platform, scope: request.scope, hdc: hdc, adb: adb)
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
    case .android:
        let candidates = try hostDeviceTargets(platform: platform, hdc: hdc).targets
        guard let selected = selectHostDeviceTarget(target: target, candidates: candidates) else {
            throw hostDeviceSelectionError(platform: platform, target: target, candidates: candidates)
        }
        return selected
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
        transport: nil,
        scope: "simulator",
        kind: "simulator"
    )
}

func hostDeviceTarget(from target: TKDevicectlDeviceTarget) -> HostDeviceTarget {
    HostDeviceTarget(
        platform: target.platform,
        id: target.id,
        target: target.redactedTarget,
        state: target.state,
        ready: target.ready,
        source: target.source,
        name: target.name,
        runtime: target.runtime,
        transport: target.transport,
        scope: target.scope,
        kind: target.kind,
        blockedReasons: target.blockedReasons,
        sensitive: false,
        rawTarget: target.identifier
    )
}

func hostDeviceTarget(from target: TKHarmonyTarget) -> HostDeviceTarget {
    let isSensitive = target.scope == .real
    return HostDeviceTarget(
        platform: "harmony",
        id: target.id,
        target: isSensitive ? target.id : target.target,
        state: target.state,
        ready: target.isReady,
        source: target.source,
        name: nil,
        runtime: nil,
        transport: target.transport,
        scope: target.scope.rawValue,
        kind: target.kind,
        blockedReasons: target.blockedReasons,
        sensitive: isSensitive,
        rawTarget: target.target
    )
}

func hostDeviceTarget(from target: TKAndroidTarget) -> HostDeviceTarget {
    let isSensitive = target.scope == .real
    return HostDeviceTarget(
        platform: "android",
        id: target.id,
        target: isSensitive ? target.id : target.serial,
        state: target.state,
        ready: target.isReady,
        source: target.source,
        name: target.model,
        runtime: target.product,
        transport: target.transportID ?? target.transport,
        scope: target.scope.rawValue,
        kind: target.kind,
        blockedReasons: target.blockedReasons,
        sensitive: isSensitive,
        rawTarget: target.serial
    )
}

func harmonyTarget(from target: HostDeviceTarget) -> TKHarmonyTarget {
    TKHarmonyTarget(
        target: target.rawTarget,
        state: target.state,
        transport: target.transport ?? "hdc",
        source: target.source
    )
}

enum HarmonyDeviceReadinessError: Error, CustomStringConvertible {
    case unauthorized(String)
    case offline(String)
    case debuggingDisabled(String, String)
    case shellUnavailable(String, String)

    var description: String {
        switch self {
        case .unauthorized(let target):
            "Harmony target is unauthorized: \(target)"
        case .offline(let target):
            "Harmony target is offline: \(target)"
        case .debuggingDisabled(let target, let detail):
            "Harmony debugging is unavailable on target \(target): \(detail)"
        case .shellUnavailable(let target, let detail):
            "Harmony shell is unavailable on target \(target): \(detail)"
        }
    }

    var code: String {
        switch self {
        case .unauthorized:
            "harmony_target_unauthorized"
        case .offline:
            "harmony_target_offline"
        case .debuggingDisabled:
            "harmony_debugging_disabled"
        case .shellUnavailable:
            "harmony_shell_unavailable"
        }
    }

    var hint: String {
        switch self {
        case .unauthorized:
            "Authorize Harmony debugging for the target, then rerun `triton device wait-ready --platform harmony --scope real --json`."
        case .offline:
            "Reconnect the Harmony target or restart hdc, then verify it appears as Connected in `hdc list targets -v`."
        case .debuggingDisabled:
            "Enable Harmony debugging and wait until bootevent.boot.completed becomes true."
        case .shellUnavailable:
            "Verify `hdc -t <target> shell` works for the selected target before running Triton actions."
        }
    }
}
func waitForHostDeviceReady(
    platform: HostDevicePlatform,
    selected: HostDeviceTarget,
    hdc: String,
    adb: String = "adb",
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
            if selected.scope == HostDeviceScope.real.rawValue {
                let result = try iosRealDeviceTargets()
                guard let currentTarget = result.targets.first(where: { $0.id == selected.id || $0.target == selected.target || $0.rawTarget == selected.rawTarget }) else {
                    throw HostDeviceSelectionError.targetNotFound(selected.target)
                }
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
            } else {
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
            }
        case .harmony:
            let listResult = try runHostCommand(TKHarmonyHDCCommand.listTargets(executable: hdc))
            let targets = TKHdcTargetListParser.parse(listResult.stdout)
            guard let current = targets.first(where: { $0.target == selected.target || $0.id == selected.id }) else {
                throw HostDeviceSelectionError.targetNotFound(selected.target)
            }
            if current.blockedReasons.contains("unauthorized") {
                throw HarmonyDeviceReadinessError.unauthorized(current.target)
            }
            if current.blockedReasons.contains("offline") || !current.isConnected {
                throw HarmonyDeviceReadinessError.offline(current.target)
            }
            if current.blockedReasons.contains("debugging-disabled") {
                throw HarmonyDeviceReadinessError.debuggingDisabled(current.target, current.state)
            }

            let bootCommand = TKHarmonyHDCCommand.bootCompleted(target: current.target, executable: hdc)
            let bootResult: HostProcessResult
            do {
                bootResult = try runHostCommand(bootCommand)
            } catch HostCommandRunError.nonZeroExit(_, let result) {
                let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw HarmonyDeviceReadinessError.debuggingDisabled(current.target, detail.isEmpty ? "bootevent probe failed" : detail)
            }
            let bootReady = TKHarmonyBootCompletedParser.isReady(bootResult.stdout)
            let shellCommand = TKHarmonyHDCCommand.shellProbe(target: current.target, executable: hdc)
            let shellResult: HostProcessResult?
            if bootReady {
                do {
                    shellResult = try runHostCommand(shellCommand)
                } catch HostCommandRunError.nonZeroExit(_, let result) {
                    let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    throw HarmonyDeviceReadinessError.shellUnavailable(current.target, detail.isEmpty ? "shell probe failed" : detail)
                }
            } else {
                shellResult = nil
            }
            let shellReady = shellResult.map {
                TKHarmonyShellProbeParser.isAvailable(stdout: $0.stdout, stderr: $0.stderr, exitCode: $0.exitCode)
            } ?? false
            if bootReady, !shellReady {
                let detail = shellResult?.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "shell probe did not return triton-shell-ready"
                throw HarmonyDeviceReadinessError.shellUnavailable(current.target, detail.isEmpty ? "shell probe failed" : detail)
            }
            let ready = bootReady && shellReady
            var sourceCommands = [listResult.sourceCommand, bootResult.sourceCommand]
            if let shellResult {
                sourceCommands.append(shellResult.sourceCommand)
            }
            let sourceCommand = sourceCommands.joined(separator: "\n")
            let currentTarget = hostDeviceTarget(from: current)
            let event = HostDeviceReadyEvent(
                ok: ready,
                platform: platform.rawValue,
                target: currentTarget,
                ready: ready,
                attempt: attempt,
                sourceCommand: sourceCommand,
                error: nil
            )
            if ready {
                return event
            }
        case .android:
            let stateResult = try runAndroidADBReadinessProbe(TKAndroidADBCommand.getState(serial: selected.rawTarget, executable: adb))
            let state = TKAndroidADBStateParser.parse(stateResult.stdout, stderr: stateResult.stderr, exitCode: stateResult.exitCode)
            switch state {
            case .device:
                break
            case .unauthorized:
                throw AndroidDeviceReadinessError.unauthorized(selected.target)
            case .offline, .failed:
                throw AndroidDeviceReadinessError.offline(selected.target)
            case .debuggingDisabled:
                throw AndroidDeviceReadinessError.debuggingDisabled(selected.target)
            case .unknown(let raw):
                throw AndroidDeviceReadinessError.packageManagerUnavailable(selected.target, "adb state \(raw)")
            }
            let packageResult = try runAndroidADBReadinessProbe(TKAndroidADBCommand.packageManagerPath(serial: selected.rawTarget, executable: adb))
            let packageStatus = TKAndroidPackageManagerProbeParser.parse(packageResult.stdout, stderr: packageResult.stderr, exitCode: packageResult.exitCode)
            let sourceCommands = [stateResult.sourceCommand, packageResult.sourceCommand]
            let ready: Bool
            switch packageStatus {
            case .available:
                ready = true
            case .unavailable(let reason):
                if Date().addingTimeInterval(interval) >= deadline {
                    throw AndroidDeviceReadinessError.packageManagerUnavailable(selected.target, reason)
                }
                ready = false
            }
            let event = HostDeviceReadyEvent(
                ok: ready,
                platform: platform.rawValue,
                target: selected,
                ready: ready,
                attempt: attempt,
                sourceCommand: sourceCommands.joined(separator: "\n"),
                sourceCommands: sourceCommands,
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

private func runAndroidADBReadinessProbe(_ command: TKHostCommand) throws -> HostProcessResult {
    do {
        return try runHostCommand(command)
    } catch HostCommandRunError.nonZeroExit(_, let result) {
        return result
    }
}
