import Foundation
import TritonKitShared

struct SimulatorDoctorProbeStatus: Encodable, Equatable {
    let state: String
    let reason: String?
    let hint: String?

    init(state: String, reason: String?, hint: String? = nil) {
        self.state = state
        self.reason = reason
        self.hint = hint
    }
}

/// Independent readonly snapshots, not a capability grant or a capture/input test.
struct SimulatorDoctorDiagnostics: Encodable {
    let target: String
    let resize: SimulatorDoctorProbeStatus
    let display: SimulatorDoctorProbeStatus
    let verification = "readonly-target-bound-snapshots"
    let inputDispatchVerified = false
    let captureVerified = false
    let sourceCommands: [String]
    let nextAction: TKCLINextAction
}

func simulatorDiagnosticNextAction(target: String) -> TKCLINextAction {
    .init(command: "device", args: ["doctor", "--platform", "ios", "--scope", "simulator", "--device", "sim:" + target, "--json"], category: "diagnose")
}

func simulatorDoctorDiagnostics(
    target: String?, environment: [String: String] = [:],
    resizeProbe: IOSSimulatorResizeProbe = { probeIOSSimulatorResize(target: $0, environment: $1) },
    displayProbe: IOSSimulatorDisplayProbe = { probeIOSSimulatorDisplay(target: $0, environment: $1) }
) -> SimulatorDoctorDiagnostics? {
    guard let target, UUID(uuidString: target) != nil else { return nil }
    let resize: SimulatorDoctorProbeStatus
    switch resizeProbe(target, environment) {
    case .inactive: resize = .init(state: "inactive", reason: nil)
    case .active: resize = .init(state: "active", reason: nil)
    case .unknown(let reason): resize = .init(state: "unknown", reason: reason.rawValue, hint: reason.recoveryHint)
    }
    let display: SimulatorDoctorProbeStatus
    switch displayProbe(target, environment) {
    case .primary: display = .init(state: "primary", reason: nil)
    case .unknown(let reason): display = .init(state: "unknown", reason: reason.rawValue)
    }
    return .init(target: "sim:" + target, resize: resize, display: display,
        sourceCommands: ["xcrun devicectl device info appResize --device <selected-simulator> --json-output <private-json> --log-output <private-log> --timeout 5 --quiet", "xcrun devicectl device info displays --device <selected-simulator> --json-output <private-json> --log-output <private-log> --timeout 5 --quiet"],
        nextAction: simulatorDiagnosticNextAction(target: target))
}

struct SimulatorTargetDiagnosticError: Error {
    let detail: TKCLIErrorDetail
}

/// Only exact Simulator UUIDs may be reflected into executable recovery argv.
func simulatorTargetBoundDetail(_ detail: TKCLIErrorDetail, target: String) -> TKCLIErrorDetail {
    guard UUID(uuidString: target) != nil else { return detail }
    return TKCLIErrorDetail(code: detail.code, message: detail.message,
        hint: (detail.hint ?? "") + " Inspect simulatorDiagnostics.resize and simulatorDiagnostics.display in selected-target doctor; tool availability alone does not prove either state. Do not replay an action with unknown delivery.",
        nextAction: simulatorDiagnosticNextAction(target: target))
}

func withSimulatorDiagnosticTarget<T>(_ target: String, operation: () throws -> T) throws -> T {
    do { return try operation() }
    catch let error as IOSSimulatorDisplayError { throw SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(error.detail, target: target)) }
    catch let error as IOSSimulatorResizeError { throw SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(error.detail, target: target)) }
    catch let error as IOSSimulatorResizeCaptureError { throw SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(error.detail, target: target)) }
}
