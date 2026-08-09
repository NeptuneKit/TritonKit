import Darwin
import Foundation
import TritonKitShared

func defaultLaunchdDomain() -> String {
    "gui/\(getuid())"
}

func harmonyLaunchctlPrintCommand(domain: String, label: String) -> TKHostCommand {
    TKHostCommand(
        executable: "launchctl",
        arguments: ["print", "\(domain)/\(label)"],
        riskLevel: .readonly,
        requiredConfig: [.timeout]
    )
}

func harmonyLaunchctlBootoutCommand(domain: String, label: String) -> TKHostCommand {
    TKHostCommand(
        executable: "launchctl",
        arguments: ["bootout", "\(domain)/\(label)"],
        riskLevel: .automation,
        requiredConfig: [.timeout, .auditRecord]
    )
}

func harmonyEmulatorStopCommand(hvd: String, deployedPath: String, emulator: String) -> TKHostCommand {
    TKHostCommand(
        executable: emulator,
        arguments: ["-stop", hvd, "-path", deployedPath],
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord]
    )
}

func harmonyEmulatorLicenseAgreementDetected(stdout: String, stderr: String) -> Bool {
    let output = [stdout, stderr].joined(separator: "\n").lowercased()
    return output.contains("please agree to the agreement first")
        || output.contains("confirm whether agree")
        || output.contains("agree to the above agreement")
}

func harmonyEmulatorLicenseAgreementErrorDetail(stdoutLogPath: String?, stderrLogPath: String?) -> TKCLIErrorDetail {
    let artifacts = [
        stdoutLogPath.map { "stdout: \($0)" },
        stderrLogPath.map { "stderr: \($0)" },
    ].compactMap { $0 }.joined(separator: "; ")
    let artifactHint = artifacts.isEmpty ? "" : " Logs: \(artifacts)."
    return TKCLIErrorDetail(
        code: "emulator_license_agreement_required",
        message: "DevEco Emulator requires first-run license agreement before Triton can report the emulator as started.",
        hint: "Open DevEco Emulator once and accept the license agreement interactively, then rerun triton device start --platform harmony --json.\(artifactHint)",
        nextAction: TKCLINextAction(
            command: "device",
            args: ["start", "--platform", "harmony", "--json"],
            category: "retry"
        )
    )
}

func harmonyEmulatorExitedEarlyErrorDetail(stdoutLogPath: String?, stderrLogPath: String?) -> TKCLIErrorDetail {
    let artifacts = [
        stdoutLogPath.map { "stdout: \($0)" },
        stderrLogPath.map { "stderr: \($0)" },
    ].compactMap { $0 }.joined(separator: "; ")
    let artifactHint = artifacts.isEmpty ? "" : " Logs: \(artifacts)."
    return TKCLIErrorDetail(
        code: "emulator_exited_early",
        message: "DevEco Emulator exited before Triton could verify that it remained running.",
        hint: "Inspect the bounded startup logs for EULA, HVD/path, bootmode, or runtime errors, then retry `triton device start --platform harmony --json`.\(artifactHint)",
        nextAction: TKCLINextAction(
            command: "device",
            args: ["list", "--platform", "harmony", "--json"],
            category: "diagnose"
        )
    )
}

func harmonyDetachedProcessExitedEarly(pid: Int32) -> Bool {
    guard pid > 0 else { return true }
    if kill(pid, 0) == 0 { return false }
    return errno == ESRCH
}

func androidEmulatorStartCommand(
    avd: String,
    emulator: String,
    headless: Bool,
    gpu: String?,
    memory: Int?,
    noSnapshotLoad: Bool,
    noAudio: Bool,
    noBootAnim: Bool
) -> TKHostCommand {
    var arguments = ["@\(avd)"]
    if headless {
        arguments.append("-no-window")
    }
    if let gpu, !gpu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        arguments += ["-gpu", gpu]
    }
    if let memory {
        arguments += ["-memory", String(memory)]
    }
    if noSnapshotLoad {
        arguments.append("-no-snapshot-load")
    }
    if noAudio {
        arguments.append("-no-audio")
    }
    if noBootAnim {
        arguments.append("-no-boot-anim")
    }
    return TKHostCommand(
        executable: emulator,
        arguments: arguments,
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord],
        defaultTimeoutSeconds: 5
    )
}

func androidEmulatorStartPlan(
    avd: String,
    emulator: String,
    headless: Bool,
    gpu: String?,
    memory: Int?,
    noSnapshotLoad: Bool,
    noAudio: Bool,
    noBootAnim: Bool,
    adbSerial: String = "emulator-5554"
) throws -> HostDeviceStartPlan {
    let trimmedAVD = avd.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmulator = emulator.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedAVD.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Android device start requires --avd.")
    }
    guard !trimmedEmulator.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Android device start requires --emulator.")
    }
    if let memory, memory <= 0 {
        throw HostDeviceSelectionError.parameterConflict("Android device start requires --memory to be positive when provided.")
    }
    let command = androidEmulatorStartCommand(
        avd: trimmedAVD,
        emulator: trimmedEmulator,
        headless: headless,
        gpu: gpu,
        memory: memory,
        noSnapshotLoad: noSnapshotLoad,
        noAudio: noAudio,
        noBootAnim: noBootAnim
    )
    return HostDeviceStartPlan(
        action: "device.start",
        platform: "android",
        name: trimmedAVD,
        target: adbSerial,
        deployedPath: nil,
        emulator: trimmedEmulator,
        hdc: nil,
        hdcPort: nil,
        commands: [command],
        waitReadyArgs: ["wait-ready", "--platform", "android", "--device", adbSerial, "--json"],
        note: "Android emulator launch is detached. Use the nextAction wait-ready command before app, hierarchy, screenshot, or smoke actions."
    )
}

func harmonyEmulatorStartCommand(
    hvd: String,
    deployedPath: String,
    emulator: String,
    hdcPort: Int,
    bootmode: String
) -> TKHostCommand {
    TKHostCommand(
        executable: emulator,
        arguments: ["-start", hvd, "-path", deployedPath, "-hdcPort", String(hdcPort), "-bootmode", bootmode],
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord],
        defaultTimeoutSeconds: 5
    )
}

func harmonyHDCConnectCommand(hdc: String, hdcPort: Int) -> TKHostCommand {
    TKHostCommand(
        executable: hdc,
        arguments: ["tconn", "127.0.0.1:\(hdcPort)"],
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord],
        defaultTimeoutSeconds: 10
    )
}

func harmonyEmulatorStartPlan(
    hvd: String,
    deployedPath: String,
    emulator: String,
    hdc: String,
    hdcPort: Int,
    bootmode: String,
    connectAfterLaunch: Bool
) throws -> HostDeviceStartPlan {
    let trimmedHVD = hvd.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPath = deployedPath.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmulator = emulator.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedHDC = hdc.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBootmode = bootmode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedHVD.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device start requires --hvd.")
    }
    guard !trimmedPath.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device start requires --path.")
    }
    guard !trimmedEmulator.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device start requires --emulator.")
    }
    guard !trimmedHDC.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device start requires --hdc.")
    }
    guard hdcPort > 0 else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device start requires --hdc-port to be positive.")
    }
    guard !trimmedBootmode.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device start requires --bootmode.")
    }

    var commands = [
        harmonyEmulatorStartCommand(
            hvd: trimmedHVD,
            deployedPath: trimmedPath,
            emulator: trimmedEmulator,
            hdcPort: hdcPort,
            bootmode: trimmedBootmode
        ),
    ]
    if connectAfterLaunch {
        commands.append(harmonyHDCConnectCommand(hdc: trimmedHDC, hdcPort: hdcPort))
    }
    let target = "127.0.0.1:\(hdcPort)"
    return HostDeviceStartPlan(
        action: "device.start",
        platform: "harmony",
        name: trimmedHVD,
        target: target,
        deployedPath: trimmedPath,
        emulator: trimmedEmulator,
        hdc: trimmedHDC,
        hdcPort: hdcPort,
        commands: commands,
        waitReadyArgs: ["wait-ready", "--platform", "harmony", "--device", target, "--json"],
        note: "Harmony emulator launch is detached. If HDC is not connected yet, run the planned hdc tconn command after boot progress, then wait-ready."
    )
}

func harmonyEmulatorStopPlan(
    hvd: String,
    deployedPath: String,
    emulator: String,
    launchdLabel: String,
    launchdDomain: String,
    includeLaunchd: Bool,
    confirmed: Bool
) throws -> HarmonyEmulatorStopPlan {
    guard confirmed else {
        throw HostDeviceSelectionError.parameterConflict("device stop requires --confirm.")
    }
    let trimmedHVD = hvd.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPath = deployedPath.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmulator = emulator.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedHVD.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device stop requires --hvd.")
    }
    guard !trimmedPath.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device stop requires --path.")
    }
    guard !trimmedEmulator.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("Harmony device stop requires --emulator.")
    }

    var commands: [TKHostCommand] = []
    let label = launchdLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    let domain = launchdDomain.trimmingCharacters(in: .whitespacesAndNewlines)
    if includeLaunchd {
        guard !label.isEmpty else {
            throw HostDeviceSelectionError.parameterConflict("Harmony device stop requires --launchd-label unless --skip-launchd is set.")
        }
        guard !domain.isEmpty else {
            throw HostDeviceSelectionError.parameterConflict("Harmony device stop requires --launchd-domain unless --skip-launchd is set.")
        }
        commands.append(harmonyLaunchctlPrintCommand(domain: domain, label: label))
        commands.append(harmonyLaunchctlBootoutCommand(domain: domain, label: label))
    }
    commands.append(harmonyEmulatorStopCommand(hvd: trimmedHVD, deployedPath: trimmedPath, emulator: trimmedEmulator))

    return HarmonyEmulatorStopPlan(
        action: "device.stop",
        platform: "harmony",
        hvd: trimmedHVD,
        deployedPath: trimmedPath,
        emulator: trimmedEmulator,
        launchdLabel: includeLaunchd ? label : nil,
        launchdDomain: includeLaunchd ? domain : nil,
        commands: commands
    )
}
func temporaryHarmonyArtifactPath(prefix: String, extension fileExtension: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString).\(fileExtension)")
        .path
}

func remoteHarmonyArtifactPath(prefix: String, extension fileExtension: String) -> String {
    "/data/local/tmp/\(prefix)-\(UUID().uuidString).\(fileExtension)"
}

struct HarmonyLayoutCapture {
    let localPath: String
    let remotePath: String
    let sourceCommands: [String]
    let data: Data
}

func dumpHarmonyLayout(
    selected: TKHarmonyTarget,
    hdc: String,
    output: String?,
    timeout: Double? = nil,
    commandRunner: (TKHostCommand) throws -> HostProcessResult = { command in
        try runHostCommand(command)
    },
    dataLoader: (String) throws -> Data = { path in
        try Data(contentsOf: URL(fileURLWithPath: path))
    }
) throws -> HarmonyLayoutCapture {
    let localPath = output ?? temporaryHarmonyArtifactPath(prefix: "triton-layout", extension: "json")
    try ensureParentDirectory(for: localPath)
    let deadline = timeout.map { Date().addingTimeInterval($0) }

    var dumpCommand = TKHarmonyHDCCommand.dumpLayout(target: selected.target, executable: hdc)
    if let deadline {
        dumpCommand = dumpCommand.withTimeout(max(0.001, deadline.timeIntervalSinceNow))
    }
    let dumpResult = try commandRunner(dumpCommand)
    let remotePath: String
    do {
        remotePath = try TKHarmonyDumpLayoutParser.remotePath(from: dumpResult.stdout)
    } catch {
        throw HostCommandRunError.layoutPathNotFound
    }
    var recvCommand = TKHarmonyHDCCommand.recvFile(
        target: selected.target,
        remotePath: remotePath,
        localPath: localPath,
        executable: hdc
    )
    if let deadline {
        recvCommand = recvCommand.withTimeout(max(0.001, deadline.timeIntervalSinceNow))
    }
    let recvResult = try commandRunner(recvCommand)
    let data = try dataLoader(localPath)
    return HarmonyLayoutCapture(
        localPath: localPath,
        remotePath: remotePath,
        sourceCommands: [dumpResult.sourceCommand, recvResult.sourceCommand],
        data: data
    )
}

func captureHarmonyScreenshot(
    selected: TKHarmonyTarget,
    hdc: String,
    output: String,
    timeout: Double? = nil
) throws -> (remotePath: String, sourceCommands: [String], format: String) {
    try prepareHostArtifactOutputPath(output)
    let remotePath = remoteHarmonyArtifactPath(prefix: "triton-smoke", extension: "jpeg")
    let rawLocalPath = temporaryHarmonyArtifactPath(prefix: "triton-harmony-screenshot", extension: "jpeg")
    defer { try? FileManager.default.removeItem(atPath: rawLocalPath) }
    let screenshotResult = try runHostCommand(TKHarmonyHDCCommand.screenshot(target: selected.target, remotePath: remotePath, executable: hdc).withTimeout(timeout))
    let recvResult = try runHostCommand(TKHarmonyHDCCommand.recvFile(target: selected.target, remotePath: remotePath, localPath: rawLocalPath, executable: hdc).withTimeout(timeout))
    let data = try Data(contentsOf: URL(fileURLWithPath: rawLocalPath), options: [.mappedIfSafe])
    let extensionName = URL(fileURLWithPath: output).pathExtension.lowercased()
    if extensionName == "png" {
        let normalized = try normalizeRuntimeScreenshotToPNG(data, declaredFormat: "jpeg", outputPath: output)
        try normalized.write(to: URL(fileURLWithPath: output), options: [.atomic])
        return (remotePath, [screenshotResult.sourceCommand, recvResult.sourceCommand], "png")
    }
    try data.write(to: URL(fileURLWithPath: output), options: [.atomic])
    return (remotePath, [screenshotResult.sourceCommand, recvResult.sourceCommand], "jpeg")
}

func captureHostDeviceScreenshot(platform: HostDevicePlatform, target: HostDeviceTarget, selection: HostDeviceSelectionResult? = nil, hdc: String, adb: String = "adb", output: String, timeout: Double? = nil) throws -> HostDeviceArtifactOutput {
    guard target.ready else {
        if platform == .android {
            if target.blockedReasons.contains("unauthorized") {
                throw AndroidDeviceReadinessError.unauthorized(target.target)
            }
            if target.blockedReasons.contains("offline") {
                throw AndroidDeviceReadinessError.offline(target.target)
            }
            if target.blockedReasons.contains("debugging-disabled") {
                throw AndroidDeviceReadinessError.debuggingDisabled(target.target)
            }
        }
        throw HostCommandRunError.deviceNotReady(target: target.target, timeoutSeconds: 0)
    }
    if platform == .ios, target.scope == HostDeviceScope.real.rawValue || target.kind == "real-device" {
        throw HostDeviceScreenshotError.unsupportedIOSRealDevice
    }
    switch platform {
    case .ios:
        try prepareHostArtifactOutputPath(output)
        let result = try runHostCommand(TKSimctlCommand.screenshot(udid: target.target, output: output).withTimeout(timeout))
        return HostDeviceArtifactOutput(
            ok: true,
            action: "screenshot",
            platform: platform.rawValue,
            target: target,
            selection: selection,
            artifact: output,
            format: "png",
            metadata: try makeHostScreenshotArtifactMetadata(outputPath: output),
            sourceCommands: [result.sourceCommand],
            note: "Host-side iOS simulator screenshot was written."
        )
    case .harmony:
        let capture = try captureHarmonyScreenshot(selected: harmonyTarget(from: target), hdc: hdc, output: output, timeout: timeout)
        return HostDeviceArtifactOutput(
            ok: true,
            action: "screenshot",
            platform: platform.rawValue,
            target: target,
            selection: selection,
            artifact: output,
            format: capture.format,
            metadata: try makeHostScreenshotArtifactMetadata(outputPath: output),
            sourceCommands: capture.sourceCommands,
            note: "Host-side Harmony screenshot was captured through snapshot_display using remote artifact \(capture.remotePath)."
        )
    case .android:
        try prepareHostArtifactOutputPath(output)
        let remotePath = "/sdcard/triton-screenshot-\(UUID().uuidString).png"
        let screenshotResult = try runHostCommand(TKAndroidADBCommand.screenshotToFile(serial: target.rawTarget, remotePath: remotePath, executable: adb).withTimeout(timeout))
        let pullResult = try runHostCommand(TKAndroidADBCommand.pullFile(serial: target.rawTarget, remotePath: remotePath, localPath: output, executable: adb).withTimeout(timeout))
        _ = try? runHostCommand(TKAndroidADBCommand.removeFile(serial: target.rawTarget, remotePath: remotePath, executable: adb))
        return HostDeviceArtifactOutput(
            ok: true,
            action: "screenshot",
            platform: platform.rawValue,
            target: target,
            selection: selection,
            artifact: output,
            format: "png",
            metadata: try makeHostScreenshotArtifactMetadata(outputPath: output),
            sourceCommands: [screenshotResult.sourceCommand, pullResult.sourceCommand],
            note: "Host-side Android screenshot was captured through adb screencap and pulled from the emulator."
        )
    }
}
