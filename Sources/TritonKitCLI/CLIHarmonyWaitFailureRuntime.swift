import ArgumentParser
import Foundation
import TritonKitShared

/// Keep the host adapter's known cause and configured executable separate from
/// embedded /request failures. This function never performs recovery actions.
func harmonyWaitFailureDetail(_ error: Error, hdc: String) -> TKCLIErrorDetail? {
    let discovery = TKCLINextAction(command: "device", args: ["list", "--platform", "harmony", "--hdc", hdc, "--json"], category: "diagnose")
    let toolCheck = TKCLINextAction(command: "device", args: ["doctor", "--platform", "harmony", "--hdc", hdc, "--json"], category: "diagnose")
    func missingTool() -> TKCLIErrorDetail {
        TKCLIErrorDetail(
            code: "harmony_hdc_not_found",
            message: "The configured HDC executable was not found: \(hdc)",
            hint: "Set --hdc to an existing DevEco/HarmonyOS HDC executable, or make that executable available on PATH. The failing configuration is --hdc \(shellEscaped(hdc)); this is not a Triton server failure.",
            nextAction: toolCheck
        )
    }
    switch error {
    case HostDeviceRunError.targetNotFound:
        return TKCLIErrorDetail(code: "target_not_found", message: "\(error)", hint: "List Harmony targets with the configured --hdc, then pass an explicit --target or --device from that result.", nextAction: discovery)
    case HostDeviceRunError.ambiguousTarget:
        return TKCLIErrorDetail(code: "ambiguous_target", message: "\(error)", hint: "List Harmony targets and select one explicitly with --target or --device; no target is selected automatically.", nextAction: discovery)
    case HostDeviceRunError.targetOffline(let target):
        return TKCLIErrorDetail(code: "target_offline", message: "\(error)", hint: "Check readiness of the same Harmony target; the wait did not change or start a target.", nextAction: TKCLINextAction(command: "device", args: ["wait-ready", "--platform", "harmony", "--device", target, "--hdc", hdc, "--json"], category: "diagnose"))
    case HostCommandRunError.launchFailed:
        if hdc.contains("/"), !FileManager.default.fileExists(atPath: hdc) { return missingTool() }
        return TKCLIErrorDetail(code: "host_action_failed", message: "\(error)", hint: "Check that the configured --hdc \(shellEscaped(hdc)) can be launched and has executable permissions; no runtime server request was made.", nextAction: toolCheck)
    case HostCommandRunError.nonZeroExit(let command, let result):
        // Bare executable names are launched through /usr/bin/env. Status 127
        // alone can also be a remote-shell error and must not imply a missing HDC.
        let diagnostic = result.stderr.lowercased()
        if command.executable == hdc, !hdc.contains("/"), result.exitCode == 127,
           diagnostic.hasPrefix("env: \(hdc.lowercased()):"),
           diagnostic.contains("no such file") || diagnostic.contains("not found") {
            return missingTool()
        }
        return nil
    default:
        return nil
    }
}

func failWaitCommand(_ error: Error, platform: HostPlatform?, hdc: String, outputFormat: ClientOutputFormat, host: String, port: Int) throws -> Never {
    if error is ExitCode { throw error }
    guard platform == .harmony else {
        try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
    }
    // Genuine transport/server errors retain their endpoint and recovery data.
    if error is CLIHTTPError || error is URLError || error is RuntimeRequestTimeoutError {
        try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
    }
    guard let detail = harmonyWaitFailureDetail(error, hdc: hdc) else {
        try failHostCommand(error, outputFormat: outputFormat)
    }
    switch outputFormat {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        print("\(detail.code): \(detail.message)")
        if let hint = detail.hint { print("hint: \(hint)") }
        if let next = detail.nextAction { print("next: " + (["triton", next.command] + next.args).map(shellEscaped).joined(separator: " ")) }
    }
    throw ExitCode.failure
}
