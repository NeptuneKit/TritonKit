import CoreFoundation
import Darwin
import Foundation
import TritonKitShared

struct IOSSimulatorResizeSession: Equatable, Encodable {
    let displayUniqueID: String
    let width: Double
    let height: Double
}

enum IOSSimulatorResizeUnknownReason: String, Equatable, Encodable {
    case invalidResponse, identityMismatch, outputTooLarge, jsonMissing, queryFailed, queryTimedOut, unsupportedQuery, unsupportedDevice

    var recoveryHint: String? {
        guard self == .unsupportedDevice else { return nil }
        return "The selected Xcode backend explicitly reports that this target does not support Resizable App Management. Repeating the same doctor query will not enable that capability. Use a target/toolchain with verified appResize support, or an explicitly connected embedded runtime for App-only observation. For a single verified primary LCD still image only, explicitly use triton sim screenshot --simulator <UUID> --primary-framebuffer --output <new-path.png> --json; it preserves Resize unknown and cannot authorize input. None of these is evidence that this target's host capture or input is safe."
    }
}

enum IOSSimulatorResizeState: Equatable {
    case active(IOSSimulatorResizeSession)
    case inactive
    case unknown(IOSSimulatorResizeUnknownReason)
}

/// A target-bound capability rejection proves that Resize Mode cannot be
/// active on this target. It remains `unknown(.unsupportedDevice)` in the
/// diagnostic model so callers can preserve the native reason, but host
/// coordinate input may continue through its independent HID/display guards.
func iosSimulatorResizeAllowsHostInput(_ state: IOSSimulatorResizeState) -> Bool {
    switch state {
    case .inactive, .unknown(.unsupportedDevice): return true
    case .active, .unknown: return false
    }
}

typealias IOSSimulatorResizeProbe = (String, [String: String]) -> IOSSimulatorResizeState

enum IOSSimulatorResizeError: Error, Equatable, LocalizedError {
    case activeSession
    case stateUnknown(IOSSimulatorResizeUnknownReason)
    case invalidTarget

    var errorDescription: String? { detail.message }

    var detail: TKCLIErrorDetail {
        switch self {
        case .activeSession:
            return TKCLIErrorDetail(code: "ios_simulator_resize_touch_unroutable", message: "Resize Mode is active; the host touch adapter cannot route input to the Resizable display. No new gesture was sent.", hint: "End the Resize Mode session in Device Hub, then retry the complete gesture. Keyboard input remains subject to its own backend capability.")
        case .stateUnknown(let reason):
            return TKCLIErrorDetail(code: "ios_simulator_resize_state_unknown", message: "Resize Mode state could not be verified (\(reason.rawValue)); no new gesture was sent.", hint: reason.recoveryHint ?? "Run triton device doctor --platform ios --scope simulator --json with the selected Xcode. The appResize query must be available and return target-bound JSON; an older Xcode version is not evidence of an inactive session.")
        case .invalidTarget:
            return TKCLIErrorDetail(code: "ios_simulator_resize_target_invalid", message: "Touch protection requires one exact resolved Simulator UUID.", hint: "Resolve the simulator through Triton device discovery before dispatching a touch gesture.")
        }
    }
}

private func resizeNumber(_ value: Any?) -> Double? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
    let number = value.doubleValue
    return number.isFinite ? number : nil
}

/// File JSON must echo the exact requested target. No state is inferred from exit zero alone.
func classifyIOSSimulatorResize(data: Data, target: String, exitCode: Int32) -> IOSSimulatorResizeState {
    guard data.count <= 1_048_576 else { return .unknown(.outputTooLarge) }
    guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let info = root["info"] as? [String: Any],
          info["commandType"] as? String == "devicectl.device.info.appResize",
          let arguments = info["arguments"] as? [String] else { return .unknown(.invalidResponse) }
    let selectors = arguments.indices.filter { arguments[$0] == "--device" || arguments[$0].hasPrefix("--device=") }
    guard selectors.count == 1, let index = selectors.first, arguments[index] == "--device",
          arguments.indices.contains(index + 1), arguments[index + 1] == target else { return .unknown(.identityMismatch) }
    if root["errors"] != nil || (root["result"] != nil && root["error"] != nil) { return .unknown(.invalidResponse) }
    if let error = root["error"] as? [String: Any] {
        guard info["outcome"] as? String == "failed", exitCode != 0,
              error["domain"] as? String == "com.apple.dt.CoreDeviceError" else { return .unknown(.queryFailed) }
        if resizeNumber(error["code"]) == 24004 { return .inactive }
        if resizeNumber(error["code"]) == 1001, resizeCapabilityRejected(error, target: target) {
            return .unknown(.unsupportedDevice)
        }
        return .unknown(.queryFailed)
    }
    guard exitCode == 0, info["outcome"] as? String == "success",
          let result = root["result"] as? [String: Any],
          let identifier = result["deviceIdentifier"] as? String else { return .unknown(.invalidResponse) }
    guard identifier == target || (UUID(uuidString: target) != nil && UUID(uuidString: identifier) == UUID(uuidString: target)) else { return .unknown(.identityMismatch) }
    guard let display = result["displayUniqueId"] as? String, UUID(uuidString: display) != nil,
          result["displayName"] as? String == "Resizable",
          let size = result["preferredSize"] as? [Any], size.count == 2,
          let width = resizeNumber(size[0]), let height = resizeNumber(size[1]),
          width > 0, height > 0, width <= 16384, height <= 16384 else { return .unknown(.invalidResponse) }
    return .active(IOSSimulatorResizeSession(displayUniqueID: display, width: width, height: height))
}

/// Recognize only the observed, target-bound capability rejection, never arbitrary
/// nested 1001 errors or localized descriptions. Unsupported is still unknown state.
private func resizeCapabilityRejected(_ error: [String: Any], target: String) -> Bool {
    guard Set(error.keys).isSubset(of: ["domain", "code", "userInfo"]),
          let info = error["userInfo"] as? [String: Any],
          Set(info.keys).isSubset(of: ["CapabilityFeatureIdentifier", "CapabilityName", "DeviceIdentifier", "NSLocalizedDescription", "NSLocalizedFailureReason"]),
          let feature = info["CapabilityFeatureIdentifier"] as? [String: Any], feature.count == 1,
          feature["string"] as? String == "com.apple.coredevice.feature.resizableappmanagement",
          let device = info["DeviceIdentifier"] as? [String: Any], device.count == 1,
          device["string"] as? String == target else { return false }
    return true
}

func iosSimulatorResizeQueryCommand(target: String, json: String, log: String, environment: [String: String]) -> TKHostCommand {
    TKHostCommand(executable: "xcrun", arguments: [
        "devicectl", "device", "info", "appResize", "--device", target,
        "--json-output", json, "--log-output", log, "--timeout", "5", "--quiet"
    ], environment: environment, redactedArgumentIndexes: [5, 7, 9], defaultTimeoutSeconds: 6, capturesArtifacts: true, sensitiveOutput: true)
}

/// Fresh request for every complete gesture; no TTL, version bypass, disable switch or retry.
func probeIOSSimulatorResize(
    target: String,
    environment: [String: String] = [:],
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0, maximumOutputBytes: 16_384) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON
) -> IOSSimulatorResizeState {
    probeIOSSimulatorResizeReport(target: target, environment: environment, artifactProvider: artifactProvider, runner: runner, reader: reader).state
}

typealias IOSSimulatorResizeProbeDiagnostic = TKCLIHostProbeDiagnostic

struct IOSSimulatorResizeProbeReport {
    let state: IOSSimulatorResizeState
    let diagnostic: IOSSimulatorResizeProbeDiagnostic
}

/// Preserve the exact failing probe's facts; a later doctor observation is independent.
func resizeStateForOperation(target: String, environment: [String: String] = [:], probe: IOSSimulatorResizeProbe? = nil,
    capture: Bool = false, allowsUnsupported: Bool = false,
    reportProbe: ((String, [String: String]) -> IOSSimulatorResizeProbeReport)? = nil
) throws -> IOSSimulatorResizeState {
    if let probe { return probe(target, environment) }
    let report = reportProbe?(target, environment) ?? probeIOSSimulatorResizeReport(target: target, environment: environment)
    if case .unknown(let reason) = report.state, !(allowsUnsupported && reason == .unsupportedDevice) {
        let base = capture ? IOSSimulatorResizeCaptureError.stateUnknown(reason).detail : IOSSimulatorResizeError.stateUnknown(reason).detail
        let detail = TKCLIErrorDetail(code: base.code, message: base.message, hint: base.hint, probeDiagnostic: report.diagnostic)
        throw SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(detail, target: target))
    }
    return report.state
}

func probeIOSSimulatorResizeReport(
    target: String, environment: [String: String] = [:],
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0, maximumOutputBytes: 16_384) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON
) -> IOSSimulatorResizeProbeReport {
    var preserveArtifacts = false
    var artifactPaths: [String] = []
    func report(_ state: IOSSimulatorResizeState, _ stage: String, exit: Int32? = nil, domain: String? = nil, code: Int? = nil) -> IOSSimulatorResizeProbeReport {
        let reason: String?
        if case .unknown(let failure) = state {
            preserveArtifacts = true
            reason = failure.rawValue
        } else {
            reason = nil
        }
        let retained = preserveArtifacts ? artifactPaths.filter { FileManager.default.fileExists(atPath: $0) } : []
        return .init(state: state, diagnostic: .init(stage: stage, exitCode: exit, nativeErrorDomain: domain, nativeErrorCode: code, artifactPaths: retained.isEmpty ? nil : retained, reason: reason))
    }
    guard UUID(uuidString: target) != nil else { return report(.unknown(.identityMismatch), "target-validation") }
    let paths: (json: String, log: String)
    do { paths = try artifactProvider("simulator-resize") }
    catch { return report(.unknown(.queryFailed), "artifact-creation") }
    let processPath = paths.json + ".process.json"
    artifactPaths = [paths.json, paths.log, processPath]
    // Failed probes retain owner-only original diagnostics; public sharing is separate.
    defer { if !preserveArtifacts {
        for path in artifactPaths { try? FileManager.default.removeItem(atPath: path) }
        _ = rmdir(URL(fileURLWithPath: paths.json).deletingLastPathComponent().path)
    } }
    func saveProcess(_ value: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           FileManager.default.fileExists(atPath: URL(fileURLWithPath: processPath).deletingLastPathComponent().path) {
            _ = FileManager.default.createFile(atPath: processPath, contents: data, attributes: [.posixPermissions: 0o600])
        }
    }
    let command = iosSimulatorResizeQueryCommand(target: target, json: paths.json, log: paths.log, environment: environment)
    let result: HostProcessResult
    do { result = try runner(command) }
    catch let error as HostCommandRunError {
        if case .nonZeroExit(_, let failure) = error { result = failure }
        else {
            saveProcess(["error": String(describing: error)])
            if case .timeout = error { return report(.unknown(.queryTimedOut), "process") }
            return report(.unknown(.queryFailed), "process")
        }
    }
    catch { saveProcess(["error": String(describing: error)]); return report(.unknown(.queryFailed), "process") }
    saveProcess(["exitCode": result.exitCode, "stdout": result.stdout, "stderr": result.stderr,
        "stdoutTruncated": result.stdoutTruncated, "stderrTruncated": result.stderrTruncated])
    let data: Data
    do { data = try reader(paths.json, 1_048_576) }
    catch HostDeviceFilesError.limitExceeded { return report(.unknown(.outputTooLarge), "json-read", exit: result.exitCode) }
    catch {
        let stderr = result.stderr.lowercased()
        if result.exitCode == 64 && !result.stderrTruncated,
           stderr.contains("appresize"),
           (stderr.contains("unrecognized subcommand") || stderr.contains("unknown subcommand")) { return report(.unknown(.unsupportedQuery), "json-read", exit: result.exitCode) }
        return report(.unknown(.jsonMissing), "json-read", exit: result.exitCode)
    }
    guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let info = root["info"] as? [String: Any], info["arguments"] as? [String] == command.arguments else { return report(.unknown(.identityMismatch), "receipt-validation", exit: result.exitCode) }
    let state = classifyIOSSimulatorResize(data: data, target: target, exitCode: result.exitCode)
    let error = root["error"] as? [String: Any]
    // Only a fully command-bound known native domain is public diagnostic metadata.
    // Localized text, device identities, logs, and arbitrary error domains are not echoed.
    let knownDomain = info["commandType"] as? String == "devicectl.device.info.appResize" && info["outcome"] as? String == "failed" && result.exitCode != 0 && error?["domain"] as? String == "com.apple.dt.CoreDeviceError"
    let number = knownDomain ? resizeNumber(error?["code"]) : nil
    let code = number.flatMap { $0 >= Double(Int.min) && $0 < Double(Int.max) && $0.rounded() == $0 ? Int($0) : nil }
    return report(state, "native-result", exit: result.exitCode, domain: knownDomain ? "com.apple.dt.CoreDeviceError" : nil, code: code)
}

struct IOSSimulatorResizeAdvisory: Encodable, Equatable {
    let code: String
    let requestedSceneWidth: Double?
    let requestedSceneHeight: Double?
    let pointHitTestingReliable: Bool
    let message: String
}

func iosSimulatorResizeAdvisory(_ state: IOSSimulatorResizeState) -> IOSSimulatorResizeAdvisory? {
    switch state {
    case .inactive: return nil
    case .active(let session): return IOSSimulatorResizeAdvisory(code: "resizable_app_session", requestedSceneWidth: session.width, requestedSceneHeight: session.height, pointHitTestingReliable: false, message: "Resize Mode is active. Scene dimensions are requested sizes; main-display hit testing and orientation calibration do not prove app geometry.")
    case .unknown: return IOSSimulatorResizeAdvisory(code: "resizable_app_session_unknown", requestedSceneWidth: nil, requestedSceneHeight: nil, pointHitTestingReliable: false, message: "Resize Mode state is unknown; absence of an active-session observation does not establish main-display routing.")
    }
}

/// Optional display selection for simctl screenshot, not permission to route touch/video.
func iosSimulatorResizeScreenshotDisplay(_ state: IOSSimulatorResizeState) throws -> String? {
    switch state {
    case .inactive: return nil
    case .active(let session): return session.displayUniqueID
    case .unknown(let reason): throw IOSSimulatorResizeCaptureError.stateUnknown(reason)
    }
}

enum IOSSimulatorResizeCaptureError: Error, Equatable, LocalizedError {
    case activeSession
    case stateUnknown(IOSSimulatorResizeUnknownReason)

    var errorDescription: String? { detail.message }

    var detail: TKCLIErrorDetail {
        switch self {
        case .activeSession:
            return TKCLIErrorDetail(code: "ios_simulator_resize_capture_unroutable", message: "Resize Mode is active; this video/framebuffer capture does not route to the Resizable display. Capture was not started.", hint: "Use triton sim screenshot for a display-bound still image, or end the Resize Mode session before video capture.")
        case .stateUnknown(let reason):
            return TKCLIErrorDetail(code: "ios_simulator_resize_capture_state_unknown", message: "Resize Mode state could not be verified (\(reason.rawValue)); capture was not started.", hint: reason.recoveryHint ?? "Run triton device doctor --platform ios --scope simulator --json with the selected Xcode and verify the appResize query before capture.")
        }
    }
}

/// Main-framebuffer video has no verified Resizable route. Screenshot uses its separate display helper.
func assertIOSSimulatorResizeCaptureAllowed(
    target: String,
    environment: [String: String] = [:],
    probe: IOSSimulatorResizeProbe = { probeIOSSimulatorResize(target: $0, environment: $1) }
) throws {
    switch probe(target, environment) {
    case .inactive: return
    case .active: throw IOSSimulatorResizeCaptureError.activeSession
    case .unknown(let reason): throw IOSSimulatorResizeCaptureError.stateUnknown(reason)
    }
}
