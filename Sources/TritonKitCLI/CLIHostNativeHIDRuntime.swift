import CoreGraphics
import Foundation
import TritonKitShared

/// Apple's tools are OS/toolchain resources; no third-party executable is used.
struct NativeHIDControlError: Error {
    let code: String
    let probeDiagnostic: TKCLIHostProbeDiagnostic?
    let recoveryHint: String?

    init(code: String, probeDiagnostic: TKCLIHostProbeDiagnostic? = nil, recoveryHint: String? = nil) {
        self.code = code
        self.probeDiagnostic = probeDiagnostic
        self.recoveryHint = recoveryHint
    }

    static func display(stage: String = "hid-screen-enumeration", reason: String, hint: String) -> Self {
        Self(code: "ios_host_hid_display_unsupported",
             probeDiagnostic: .init(stage: stage, exitCode: nil, nativeErrorDomain: nil, nativeErrorCode: nil, reason: reason),
             recoveryHint: hint)
    }

    var detail: TKCLIErrorDetail {
        let message: String
        switch code {
        case "ios_host_hid_device_hub_attached":
            message = "The selected Simulator reports an active DTUHID daemon. Legacy input is refused; no gesture was sent."
        case "ios_host_hid_attachment_unknown":
            message = "Device Hub HID ownership could not be verified; no gesture was sent."
        case "ios_host_hid_display_unsupported":
            message = "Native HID requires one unambiguous primary integrated portrait screen; no gesture was sent."
        case "ios_host_hid_helper_failed":
            message = "The isolated native HID helper failed. Delivery may be unknown; do not replay automatically."
        case "ios_host_hid_surface_changed":
            message = "The Simulator input surface changed or could not be reverified after submission. A partial gesture may already have reached the guest; do not replay automatically."
        default:
            message = "Native HID accepts only finite in-bounds Simulator tap or swipe coordinates and a duration greater than zero and at most 10 seconds."
        }
        let boundaryHint = "Run selected-device doctor and re-observe the Simulator. Tap/swipe use the built-in adapter, without Baguette or AX fallback. Device Hub ownership may require a deliberate simulator restart or a compatible input surface; Triton does not restart SpringBoard, kill the app, or heal automatically. Screenshots and AX activation are not HID proof."
        return TKCLIErrorDetail(code: code, message: message,
            hint: [recoveryHint, boundaryHint].compactMap { $0 }.joined(separator: " "),
            nextAction: .init(command: "device", args: ["doctor", "--platform", "ios", "--scope", "simulator", "--device", "<simulator>", "--json"], category: "diagnose"),
            probeDiagnostic: probeDiagnostic)
    }
}

struct NativeHIDScreen: Equatable {
    let pointSize: CGSize
    var dtuhidActive: Bool = false
}

/// This reads the guest notify state, never the host's similarly named key.
func nativeHIDDTUHIDActive(_ text: String) throws -> Bool {
    let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
    guard words.count == 2, words[0] == "com.apple.coredevice.dtuhidd.active", ["0", "1"].contains(words[1]) else {
        throw NativeHIDControlError(code: "ios_host_hid_attachment_unknown")
    }
    return words[1] == "1"
}

func classifyNativeHIDAttachment(_ text: String) throws {
    if try nativeHIDDTUHIDActive(text) { throw NativeHIDControlError(code: "ios_host_hid_device_hub_attached") }
}

/// Refuse unknown, multiple integrated, resizable-only, folded or rotated geometry.
/// Only Connected Screens metadata participates, never the largest framebuffer.
func nativeHIDScreen(_ text: String) throws -> NativeHIDScreen {
    var inScreens = false
    var screens: [[String: String]] = []
    for raw in text.split(whereSeparator: \.isNewline) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line == "Connected Screens:" { inScreens = true; continue }
        if inScreens && line == "Port:" { inScreens = false }
        guard inScreens else { continue }
        if line.first == "(", line.contains(")"), line.hasSuffix(":") { screens.append([:]); continue }
        guard !screens.isEmpty, let colon = line.firstIndex(of: ":") else { continue }
        let key = String(line[..<colon])
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard screens[screens.count - 1][key] == nil else {
            throw NativeHIDControlError.display(reason: "duplicate-screen-metadata", hint: "The selected toolchain returned duplicate screen metadata. Capture the failing action receipt to diagnose the toolchain output.")
        }
        screens[screens.count - 1][key] = value
    }
    let integrated = screens.filter { $0["Screen Type"] == "Integrated" }
    guard integrated.count == 1, let screen = integrated.first else {
        throw NativeHIDControlError.display(reason: "integrated-screen-count", hint: "Use a Simulator configuration with one integrated screen, then capture a fresh observation.")
    }
    guard screen["Device Name"] == "primary", screen["Screen ID"] == "1" else {
        throw NativeHIDControlError.display(reason: "primary-screen-identity", hint: "The input preflight could not bind the integrated screen to the expected primary identity. Capture the failing action receipt.")
    }
    guard screen["UI Orientation"] == "Portrait" else {
        throw NativeHIDControlError.display(reason: "portrait-required", hint: "Verify that the selected Simulator is in portrait orientation, then capture a fresh observation.")
    }
    guard let scale = screen["Preferred UI Scale"].flatMap(Double.init), scale.isFinite, scale > 0 else {
        throw NativeHIDControlError.display(reason: "invalid-screen-scale", hint: "The selected toolchain did not report a valid UI scale for the primary screen. Capture the failing action receipt.")
    }
    let geometryFailure = NativeHIDControlError.display(reason: "invalid-screen-dimensions", hint: "The selected toolchain did not report usable primary-screen dimensions. Capture the failing action receipt.")
    guard let pixels = screen["Pixel Size"], pixels.hasPrefix("{"), pixels.hasSuffix("}") else {
        throw geometryFailure
    }
    let components = pixels.dropFirst().dropLast().split(separator: ",", omittingEmptySubsequences: false)
    guard components.count == 2,
          let width = Double(components[0].trimmingCharacters(in: .whitespaces)),
          let height = Double(components[1].trimmingCharacters(in: .whitespaces)),
          [width, height].allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 16384 }) else {
        throw geometryFailure
    }
    let size = CGSize(width: width / scale, height: height / scale)
    guard AXFrameTransform.valid(size) else { throw geometryFailure }
    return .init(pointSize: size)
}

func nativeHIDGuardSnapshot(
    target: String,
    environment: [String: String],
    allowActiveDTUHID: Bool = false,
    resizeProbe: IOSSimulatorResizeProbe? = nil,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0, maximumOutputBytes: 65_536) }
) throws -> NativeHIDScreen {
    guard UUID(uuidString: target) != nil else { throw IOSSimulatorResizeError.invalidTarget }
    let resize = try resizeStateForOperation(target: target, environment: environment, probe: resizeProbe, allowsUnsupported: true)
    if !iosSimulatorResizeAllowsHostInput(resize) {
        switch resize {
        case .active: throw IOSSimulatorResizeError.activeSession
        case .unknown(let reason): throw IOSSimulatorResizeError.stateUnknown(reason)
        case .inactive: break
        }
    }
    func query(_ arguments: [String], failure: String, stage: String) throws -> String {
        let command = TKHostCommand(executable: "/usr/bin/xcrun", arguments: arguments, environment: environment, defaultTimeoutSeconds: 8, sensitiveOutput: true)
        func queryFailure(reason: String, exitCode: Int32? = nil) -> NativeHIDControlError {
            NativeHIDControlError(code: failure,
                probeDiagnostic: .init(stage: stage, exitCode: exitCode, nativeErrorDomain: nil, nativeErrorCode: nil, reason: reason),
                recoveryHint: "Check the selected Xcode and Simulator connection. Keep this request's probe diagnostic if the problem recurs.")
        }
        let result: HostProcessResult
        do {
            result = try runner(command)
        } catch HostCommandRunError.nonZeroExit(_, let terminated) {
            throw queryFailure(reason: "probe-nonzero-exit", exitCode: terminated.exitCode)
        } catch HostCommandRunError.timeout {
            throw queryFailure(reason: "probe-timeout")
        } catch {
            throw queryFailure(reason: "probe-unavailable")
        }
        guard result.exitCode == 0 else { throw queryFailure(reason: "probe-nonzero-exit", exitCode: result.exitCode) }
        guard !result.stdoutTruncated else { throw queryFailure(reason: "probe-output-truncated", exitCode: result.exitCode) }
        return result.stdout
    }
    let attachment = try query(["simctl", "spawn", target, "notifyutil", "-g", "com.apple.coredevice.dtuhidd.active"], failure: "ios_host_hid_attachment_unknown", stage: "hid-ownership")
    let active = try nativeHIDDTUHIDActive(attachment)
    guard allowActiveDTUHID || !active else { throw NativeHIDControlError(code: "ios_host_hid_device_hub_attached") }
    var screen = try nativeHIDScreen(query(["simctl", "io", target, "enumerate"], failure: "ios_host_hid_display_unsupported", stage: "hid-screen-enumeration"))
    screen.dtuhidActive = active
    return screen
}

struct NativeHIDContact {
    let point: CGPoint
    let phase: NativeDigitizerPhase
}

/// All validation precedes contact-down; coordinates stay in the supplied point space.
func nativeHIDContacts(input: TKInputRequest, screen: NativeHIDScreen) throws -> (contacts: [NativeHIDContact], cadence: Double) {
    guard input.type == .tap || input.type == .swipe,
          (input.width == nil) == (input.height == nil) else { throw NativeHIDControlError(code: "validation_failed") }
    let width = input.width ?? screen.pointSize.width
    let height = input.height ?? screen.pointSize.height
    guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw NativeHIDControlError(code: "validation_failed") }
    func point(_ x: Double?, _ y: Double?) throws -> CGPoint {
        guard let x, let y, x.isFinite, y.isFinite, x >= 0, y >= 0, x <= width, y <= height else { throw NativeHIDControlError(code: "validation_failed") }
        return CGPoint(x: x / width, y: y / height)
    }
    if input.type == .tap {
        guard input.duration == nil else { throw NativeHIDControlError(code: "validation_failed") }
        let at = try point(input.x, input.y)
        return ([.init(point: at, phase: .down), .init(point: at, phase: .up)], 0.05)
    }
    let duration = input.duration ?? 0.25
    guard duration.isFinite, duration > 0, duration <= 10 else { throw NativeHIDControlError(code: "validation_failed") }
    let start = try point(input.startX, input.startY), end = try point(input.endX, input.endY)
    var contacts = [NativeHIDContact(point: start, phase: .down)]
    for index in 1...10 {
        let fraction = Double(index) / 10
        contacts.append(.init(point: CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction), phase: .move))
    }
    contacts.append(.init(point: end, phase: .up))
    return (contacts, duration / 11)
}

/// One client and touch id for the complete gesture. On failure release once at
/// the last attempted point, then preserve the original uncertainty; never replay.
func executeNativeHIDContacts(_ contacts: [NativeHIDContact], cadence: Double,
    sleep: (Double) -> Void = { Thread.sleep(forTimeInterval: $0) },
    sender: (NativeHIDContact) throws -> Void) throws {
    guard let first = contacts.first, first.phase == .down, contacts.last?.phase == .up else { throw NativeHIDControlError(code: "validation_failed") }
    var last = first
    var attemptedDown = false
    do {
        for (index, contact) in contacts.enumerated() {
            if index > 0 { sleep(cadence) }
            last = contact
            attemptedDown = true
            try sender(contact)
        }
    } catch {
        if attemptedDown && last.phase != .up { try? sender(.init(point: last.point, phase: .up)) }
        throw error
    }
}

struct NativeHIDDeliveryError: Error {
    let detail: TKCLIErrorDetail
    init(_ error: Error) {
        let base: TKCLIErrorDetail
        if let error = error as? NativeDigitizerError { base = error.detail }
        else { base = NativeHIDControlError(code: "ios_host_hid_helper_failed").detail }
        detail = TKCLIErrorDetail(code: base.code,
            message: base.message + " A partial gesture may already have reached the guest; release was best effort. Do not replay automatically.",
            hint: "Re-observe the selected Simulator and verify the business postcondition before planning another action.",
            nextAction: .init(command: "device", args: ["doctor", "--platform", "ios", "--scope", "simulator", "--device", "<simulator>", "--json"], category: "diagnose"))
    }
}

/// Refresh after client initialization and after the complete gesture. These
/// observations cannot lock Device Hub ownership during transport submission.
func executeGuardedNativeHIDGesture(expectedScreen: NativeHIDScreen,
    snapshot: () throws -> NativeHIDScreen, operation: () throws -> Void) throws {
    let current = try snapshot()
    guard current == expectedScreen else {
        throw NativeHIDControlError.display(stage: "hid-pre-dispatch", reason: current.dtuhidActive != expectedScreen.dtuhidActive ? "ownership-changed" : "screen-geometry-changed",
            hint: "Allow the Simulator surface to settle, then capture a fresh observation.")
    }
    do { try operation() }
    catch { throw NativeHIDDeliveryError(error) }
    let currentAfterDispatch = try? snapshot()
    guard currentAfterDispatch == expectedScreen else {
        throw NativeHIDControlError(code: "ios_host_hid_surface_changed",
            probeDiagnostic: .init(stage: "hid-post-dispatch", exitCode: nil, nativeErrorDomain: nil, nativeErrorCode: nil,
                                   reason: currentAfterDispatch == nil ? "surface-unverified" : "surface-changed"),
            recoveryHint: "Verify the business postcondition on the selected Simulator before planning another action.")
    }
}

func nativeHIDHelperCommand(target: String, input: TKInputRequest, executable: String = currentExecutablePath(), developerDirectory: String?) throws -> TKHostCommand {
    var environment: [String: String] = [:]
    if let developerDirectory { environment["DEVELOPER_DIR"] = developerDirectory }
    environment = selectedSimulatorFrameworkEnvironment(environment: environment, developerDirectory: developerDirectory)
    // Three bounded snapshots (66s), 12 sends plus best-effort release (26s),
    // maximum gesture cadence (10s), and client/helper startup headroom (48s).
    return TKHostCommand(executable: executable, arguments: ["device", "hid-input", "--device", target, "--request", try encodeJSON(input)], environment: environment, redactedArgumentIndexes: [3, 5], defaultTimeoutSeconds: 150, sensitiveOutput: true)
}

func runNativeSimulatorInput(target: String, input: TKInputRequest,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0, maximumOutputBytes: 65_536) }) throws -> TKInputResult {
    let command = try nativeHIDHelperCommand(target: target, input: input, developerDirectory: selectedXcodeDeveloperDirectory(environment: ProcessInfo.processInfo.environment))
    let result: HostProcessResult
    do { result = try runner(command) }
    catch HostCommandRunError.nonZeroExit(_, let failure) { result = failure }
    catch { throw NativeHIDControlError(code: "ios_host_hid_helper_failed") }
    guard !result.stdoutTruncated,
          let output = try? JSONDecoder().decode(TKInputResult.self, from: result.stdoutData),
          output.action == input.type.rawValue, output.ok == (result.exitCode == 0),
          (!output.ok || (output.source == "host-hid" && output.verification?.required == true)) else {
        throw NativeHIDControlError(code: "ios_host_hid_helper_failed")
    }
    return output
}
