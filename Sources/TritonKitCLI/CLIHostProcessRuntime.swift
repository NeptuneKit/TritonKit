import ArgumentParser
import Darwin
import Foundation
import TritonKitShared

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
private func iosDevicectlErrorMapping(stderr: String) -> (code: String, hint: String) {
    let lowercased = stderr.lowercased()
    if lowercased.contains("unable to find utility") || lowercased.contains("devicectl") && lowercased.contains("not found") {
        return (
            "devicectl_not_found",
            "Install or select an Xcode that provides `xcrun devicectl`, then rerun `triton device doctor --platform ios --scope real --json`."
        )
    }
    if lowercased.contains("not trusted") || lowercased.contains("trust this computer") || lowercased.contains("pairing") && lowercased.contains("denied") {
        return (
            "device_not_trusted",
            "Unlock the iOS device, trust this Mac, then rerun `triton device wait-ready --device <selector> --json`."
        )
    }
    if lowercased.contains("developer mode") {
        return (
            "developer_mode_required",
            "Enable Developer Mode on the iOS device and reconnect it before retrying."
        )
    }
    if lowercased.contains("locked") || lowercased.contains("passcode") {
        return (
            "device_locked",
            "Unlock the selected iOS device and keep it awake while waiting for readiness."
        )
    }
    if lowercased.contains("developer disk image") || lowercased.contains("ddi") {
        return (
            "ddi_missing",
            "Open Xcode once or install the matching DeviceSupport/DDI for this iOS version, then retry."
        )
    }
    return (
        "host_action_failed",
        "Inspect the devicectl log artifact, verify the iOS device is connected, trusted, unlocked, and supported by the selected Xcode."
    )
}

func failHostCommand(_ error: Error, outputFormat: ClientOutputFormat) throws -> Never {
    if let exitCode = error as? ExitCode {
        throw exitCode
    }

    let detail: TKCLIErrorDetail
    var hostDeviceCandidates: [HostDeviceTarget]?
    switch error {
    case _ as ValidationError:
        detail = hostValidationErrorDetail(error)
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
    case let error as AndroidDeviceReadinessError:
        detail = TKCLIErrorDetail(
            code: error.code,
            message: "\(error)",
            hint: error.hint
        )
    case let error as HarmonyDeviceReadinessError:
        detail = TKCLIErrorDetail(
            code: error.code,
            message: "\(error)",
            hint: error.hint
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
            hint: "Use --device as the unified selector, or choose one explicit selector path (--simulator or --target), but do not combine them."
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
    case IOSDevicectlRunError.jsonMissing:
        detail = TKCLIErrorDetail(
            code: "devicectl_json_missing",
            message: "\(error)",
            hint: "devicectl must be invoked with --json-output <fresh-path>; inspect the paired log artifact and retry."
        )
    case IOSDevicectlRunError.jsonParseFailed:
        detail = TKCLIErrorDetail(
            code: "devicectl_json_parse_failed",
            message: "\(error)",
            hint: "Keep the sanitized devicectl JSON fixture and update the parser for this Xcode/CoreDevice shape."
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
        } else if command.arguments.first == "devicectl" {
            let mapping = iosDevicectlErrorMapping(stderr: result.stderr)
            code = mapping.code
            hint = mapping.hint
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

func hostValidationErrorDetail(_ error: Error) -> TKCLIErrorDetail {
    TKCLIErrorDetail(
        code: "validation_failed",
        message: "\(error)",
        hint: "Fix the CLI arguments and retry."
    )
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

func failAndroidTextNotFound(_ text: String, outputFormat: ClientOutputFormat) throws -> Never {
    try failHostValidation(
        code: "text_not_found",
        message: "Android layout text was not found: \(text)",
        hint: "Run `triton observe tree --platform android --output <path.xml> --json` and inspect the dumped text, content-desc, and resource-id values.",
        outputFormat: outputFormat
    )
}
