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

func captureHostDeviceScreenshot(platform: HostDevicePlatform, target: HostDeviceTarget, selection: HostDeviceSelectionResult? = nil, hdc: String, adb: String = "adb", output: String) throws -> HostDeviceArtifactOutput {
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
    case .android:
        try prepareHostArtifactOutputPath(output)
        let command = TKAndroidADBCommand.screenshot(serial: target.rawTarget, executable: adb)
        let result = try runHostCommandWritingStdoutArtifact(command, outputPath: output)
        return HostDeviceArtifactOutput(
            ok: true,
            action: "screenshot",
            platform: platform.rawValue,
            target: target,
            selection: selection,
            artifact: output,
            sourceCommands: [result.sourceCommand],
            note: "Host-side Android screenshot was captured through adb screencap."
        )
    }
}
