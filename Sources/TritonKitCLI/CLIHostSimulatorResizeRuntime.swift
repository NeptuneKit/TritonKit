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
    case invalidResponse, identityMismatch, outputTooLarge, jsonMissing, queryFailed, queryTimedOut, unsupportedQuery
}

enum IOSSimulatorResizeState: Equatable {
    case active(IOSSimulatorResizeSession)
    case inactive
    case unknown(IOSSimulatorResizeUnknownReason)
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
            return TKCLIErrorDetail(code: "ios_simulator_resize_state_unknown", message: "Resize Mode state could not be verified (\(reason.rawValue)); no new gesture was sent.", hint: "Run triton device doctor --platform ios --scope simulator --json with the selected Xcode. The appResize query must be available and return target-bound JSON; an older Xcode version is not evidence of an inactive session.")
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
    if root["result"] != nil && root["error"] != nil { return .unknown(.invalidResponse) }
    if let error = root["error"] as? [String: Any] {
        guard info["outcome"] as? String == "failed", exitCode != 0,
              error["domain"] as? String == "com.apple.dt.CoreDeviceError", resizeNumber(error["code"]) == 24004 else { return .unknown(.queryFailed) }
        return .inactive
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
    guard UUID(uuidString: target) != nil else { return .unknown(.identityMismatch) }
    let paths: (json: String, log: String)
    do { paths = try artifactProvider("simulator-resize") }
    catch { return .unknown(.queryFailed) }
    // Probe artifacts are ephemeral and private, never returned as inline Apple output.
    defer { for path in [paths.json, paths.log] { try? FileManager.default.removeItem(atPath: path) }
        _ = rmdir(URL(fileURLWithPath: paths.json).deletingLastPathComponent().path) }
    let command = iosSimulatorResizeQueryCommand(target: target, json: paths.json, log: paths.log, environment: environment)
    let result: HostProcessResult
    do { result = try runner(command) }
    catch HostCommandRunError.timeout { return .unknown(.queryTimedOut) }
    catch HostCommandRunError.nonZeroExit(_, let failure) { result = failure }
    catch { return .unknown(.queryFailed) }
    let data: Data
    do { data = try reader(paths.json, 1_048_576) }
    catch HostDeviceFilesError.limitExceeded { return .unknown(.outputTooLarge) }
    catch {
        let stderr = result.stderr.lowercased()
        if result.exitCode == 64 && !result.stderrTruncated,
           stderr.contains("appresize"),
           (stderr.contains("unrecognized subcommand") || stderr.contains("unknown subcommand")) { return .unknown(.unsupportedQuery) }
        return .unknown(.jsonMissing)
    }
    guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let info = root["info"] as? [String: Any], info["arguments"] as? [String] == command.arguments else { return .unknown(.identityMismatch) }
    return classifyIOSSimulatorResize(data: data, target: target, exitCode: result.exitCode)
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
            return TKCLIErrorDetail(code: "ios_simulator_resize_capture_state_unknown", message: "Resize Mode state could not be verified (\(reason.rawValue)); capture was not started.", hint: "Run triton device doctor --platform ios --scope simulator --json with the selected Xcode and verify the appResize query before capture.")
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
