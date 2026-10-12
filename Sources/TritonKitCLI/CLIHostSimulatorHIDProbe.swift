import ArgumentParser
import Foundation
import TritonKitShared
#if os(macOS)
import Darwin
#endif

/// The host tap adapter is coupled to a private SimulatorKit client.  A
/// readable simulator inventory or framebuffer does not prove that this
/// client can deliver touch events, so the probe is deliberately independent
/// from both of those surfaces.
struct IOSHostHIDProbe: Encodable, Equatable {
    let target: String
    let compatible: Bool
    let available = false
    let verification = "framework-compatibility-only"
    let inputDispatchVerified = false
    let code: String
    let message: String
    let hint: String
    let backend: String
    let frameworkLayout: String?
    let sourceCommands: [String]
    var toolchainSource: String? = nil

    var errorDetail: TKCLIErrorDetail {
        TKCLIErrorDetail(
            code: code,
            message: message,
            hint: hint,
            nextAction: TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--device", target, "--json"], category: "diagnose"),
            suggestedCommands: [
                "triton device doctor --platform ios --device \(target) --json",
                "triton observe tree --platform ios --device \(target) --json",
            ]
        )
    }
}

struct IOSHostHIDFrameworkLoadResult: Codable, Equatable {
    let loaded: Bool
    let legacyClientAvailable: Bool
    let modernClientAvailable: Bool
    let error: String?
}

typealias IOSHostHIDFrameworkLoader = (String) -> IOSHostHIDFrameworkLoadResult

func simulatorKitFrameworkCandidates(developerDirectory: String) -> [(path: String, layout: String)] {
    let raw = developerDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    guard raw.hasPrefix("/") else { return [] }
    let selected = URL(fileURLWithPath: raw, isDirectory: true)
    let developer = selected.pathExtension == "app" ? selected.appendingPathComponent("Contents/Developer") : selected
    let contents: URL
    if developer.pathExtension == "app" {
        contents = developer.appendingPathComponent("Contents", isDirectory: true)
    } else if developer.lastPathComponent == "Developer" {
        contents = developer.deletingLastPathComponent()
    } else {
        contents = developer
    }
    let developerPrivate = developer.appendingPathComponent("Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit").path
    let developerVersioned = developer.appendingPathComponent("Library/PrivateFrameworks/SimulatorKit.framework/Versions/A/SimulatorKit").path
    let shared = contents.appendingPathComponent("SharedFrameworks/SimulatorKit.framework/SimulatorKit").path
    // Keep the selected Xcode first.  The shared-framework location is used by
    // newer Xcodes while the developer-private locations cover older layouts.
    return [
        (shared, "contents-shared-frameworks"),
        (contents.appendingPathComponent("SharedFrameworks/SimulatorKit.framework/Versions/A/SimulatorKit").path, "contents-shared-frameworks-versioned"),
        (developerPrivate, "developer-private-frameworks"),
        (developerVersioned, "developer-private-frameworks-versioned"),
    ]
}

func probeIOSHostHIDFramework(
    developerDirectory: String?,
    fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
    loader: IOSHostHIDFrameworkLoader = loadIOSHostHIDFramework
) -> IOSHostHIDProbe {
    guard let developerDirectory,
          !developerDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
        return IOSHostHIDProbe(
            target: "",
            compatible: false,
            code: "ios_host_hid_toolchain_unavailable",
            message: "The selected Xcode developer directory is unavailable, so the iOS Simulator HID backend was not probed.",
            hint: "Select an Xcode toolchain and retry the selected-device HID probe. Inventory and layout availability do not establish input compatibility.",
            backend: "SimulatorKit.SimDeviceLegacyHIDClient",
            frameworkLayout: nil,
            sourceCommands: []
        )
    }
    let candidates = simulatorKitFrameworkCandidates(developerDirectory: developerDirectory)
    guard let candidate = candidates.first(where: { fileExists($0.path) }) else {
        return IOSHostHIDProbe(
            target: "",
            compatible: false,
            code: "ios_host_hid_simulator_kit_unavailable",
            message: "SimulatorKit was not found in the selected Xcode framework layout; the iOS Simulator HID backend is unavailable.",
            hint: "Use the selected Xcode's SimulatorKit layout or install a compatible host HID adapter. Do not infer touch support from simulator inventory or framebuffer access.",
            backend: "SimulatorKit.SimDeviceLegacyHIDClient",
            frameworkLayout: nil,
            sourceCommands: []
        )
    }
    let result = loader(candidate.path)
    if result.loaded, result.legacyClientAvailable {
        return IOSHostHIDProbe(
            target: "",
            compatible: true,
            code: "ios_host_hid_framework_compatible",
            message: "The selected SimulatorKit exposes the legacy HID class; device input dispatch has not been tested.",
            hint: "Host HID acknowledgement is submission-only; verify the settled business state separately.",
            backend: "SimulatorKit.SimDeviceLegacyHIDClient",
            frameworkLayout: candidate.layout,
            sourceCommands: []
        )
    }
    let code = !result.loaded ? "ios_host_hid_simulator_kit_load_failed"
        : result.modernClientAvailable ? "ios_host_hid_modern_backend_unsupported"
        : "ios_host_hid_legacy_backend_unavailable"
    let message = result.loaded && result.modernClientAvailable
        ? "The selected SimulatorKit exposes a modern HID client, but the current adapter only supports the legacy client contract."
        : (!result.loaded ? "SimulatorKit could not be loaded from the selected Xcode." : "SimulatorKit loaded without a compatible legacy HID client; the input backend is unavailable.")
    return IOSHostHIDProbe(
        target: "",
        compatible: false,
        code: code,
        message: message,
        hint: "Keep the action fail-closed and use an app-owned public control or embedded semantic action. Do not retry through inventory or layout readiness.",
        backend: "SimulatorKit.SimDeviceLegacyHIDClient",
        frameworkLayout: candidate.layout,
        sourceCommands: []
    )
}

func probeIOSHostHID(
    selectedDevice: String,
    developerDirectory: String? = nil,
    fileExists: @escaping (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
    loader: @escaping IOSHostHIDFrameworkLoader = loadIOSHostHIDFramework
) -> IOSHostHIDProbe {
    let trimmed = selectedDevice.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return IOSHostHIDProbe(
            target: selectedDevice,
            compatible: false,
            code: "ios_host_hid_selected_device_missing",
            message: "A selected simulator device is required before probing host HID.",
            hint: "Resolve one booted simulator explicitly; inventory readiness alone is not an input probe.",
            backend: "SimulatorKit.SimDeviceLegacyHIDClient",
            frameworkLayout: nil,
            sourceCommands: []
        )
    }
    let environment = ProcessInfo.processInfo.environment
    let selectionSource = developerDirectory != nil ? "provided" : (environment["DEVELOPER_DIR"] == nil ? "xcode-select" : "DEVELOPER_DIR")
    let selectedDirectory = developerDirectory ?? baguetteDeveloperDirectory(environment: environment)
    let framework = probeIOSHostHIDFramework(developerDirectory: selectedDirectory, fileExists: fileExists, loader: loader)
    var commands = selectionSource == "xcode-select" ? ["xcode-select -p"] : []
    if framework.frameworkLayout != nil { commands.append("triton device hid-bootstrap --framework <selected-SimulatorKit>") }
    return IOSHostHIDProbe(
        target: trimmed,
        compatible: framework.compatible,
        code: framework.code,
        message: framework.message,
        hint: framework.hint,
        backend: framework.backend,
        frameworkLayout: framework.frameworkLayout,
        sourceCommands: commands,
        toolchainSource: selectionSource
    )
}

/// Runs private framework loading only in a bounded child process. ObjC classes
/// must never pollute a long-lived CLI/HTTP server or another selected Xcode.
private func loadIOSHostHIDFramework(path: String) -> IOSHostHIDFrameworkLoadResult {
    let environment = ProcessInfo.processInfo.environment
    let childEnvironment = baguetteFrameworkEnvironment(executable: "baguette", environment: environment, developerDirectory: baguetteDeveloperDirectory(environment: environment))
    let command = TKHostCommand(executable: CommandLine.arguments[0], arguments: ["device", "hid-bootstrap", "--framework", path], environment: childEnvironment, defaultTimeoutSeconds: 15)
    do {
        let result = try runHostCommand(command, maximumOutputBytes: 16384)
        return try JSONDecoder().decode(IOSHostHIDFrameworkLoadResult.self, from: result.stdoutData)
    } catch {
        return .init(loaded: false, legacyClientAvailable: false, modernClientAvailable: false, error: "bootstrap_probe_failed")
    }
}

struct DeviceHIDBootstrap: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "hid-bootstrap", abstract: "Internal isolated HID framework compatibility probe", shouldDisplay: false)
    @Option var framework: String

    func run() throws {
        let loaded = dlopen(framework, RTLD_LAZY | RTLD_LOCAL) != nil
        let legacy = loaded && (NSClassFromString("SimulatorKit.SimDeviceLegacyHIDClient") != nil || NSClassFromString("SimDeviceLegacyHIDClient") != nil)
        let modern = loaded && (NSClassFromString("SimulatorKit.SimDeviceHIDClient") != nil || NSClassFromString("SimDeviceHIDClient") != nil)
        print(try encodeJSON(IOSHostHIDFrameworkLoadResult(loaded: loaded, legacyClientAvailable: legacy, modernClientAvailable: modern, error: loaded ? nil : "dlopen_failed")))
    }
}

func iosHostHIDFailureCode(stderr: String) -> String? {
    let text = stderr.lowercased()
    if text.contains("simdevicelegacyhidclient") && (text.contains("class not found") || text.contains("not found")) {
        return "ios_host_hid_legacy_backend_unavailable"
    }
    if text.contains("simulatorkit") && (text.contains("dlopen") || text.contains("image not found") || text.contains("library not loaded")) {
        return "ios_host_hid_simulator_kit_load_failed"
    }
    return nil
}
