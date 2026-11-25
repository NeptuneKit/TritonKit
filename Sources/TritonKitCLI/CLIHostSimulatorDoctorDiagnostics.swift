import Foundation
import TritonKitShared

struct SimulatorDoctorProbeStatus: Encodable, Equatable {
    let state: String
    let reason: String?
    let hint: String?
    let diagnostic: IOSSimulatorResizeProbeDiagnostic?

    init(state: String, reason: String?, hint: String? = nil, diagnostic: IOSSimulatorResizeProbeDiagnostic? = nil) {
        self.state = state
        self.reason = reason
        self.hint = hint
        self.diagnostic = diagnostic
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
    resizeProbe: IOSSimulatorResizeProbe? = nil,
    displayProbe: IOSSimulatorDisplayProbe = { probeIOSSimulatorDisplay(target: $0, environment: $1) }
) -> SimulatorDoctorDiagnostics? {
    guard let target, UUID(uuidString: target) != nil else { return nil }
    let report = resizeProbe.map { IOSSimulatorResizeProbeReport(state: $0(target, environment), diagnostic: .init(stage: "injected-probe", exitCode: nil, nativeErrorDomain: nil, nativeErrorCode: nil)) }
        ?? probeIOSSimulatorResizeReport(target: target, environment: environment)
    let resize: SimulatorDoctorProbeStatus
    switch report.state {
    case .inactive: resize = .init(state: "inactive", reason: nil, diagnostic: report.diagnostic)
    case .active: resize = .init(state: "active", reason: nil, diagnostic: report.diagnostic)
    case .unknown(let reason): resize = .init(state: "unknown", reason: reason.rawValue, hint: reason.recoveryHint, diagnostic: report.diagnostic)
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
    let diagnosis = detail.code.hasPrefix("ios_host_hid_")
        ? " Inspect hidCompatibility.inputSurfaceCode and inputSurfaceDiagnostic for a fresh preflight. Doctor's primary display snapshot cannot establish why this HID request failed."
        : " Inspect simulatorDiagnostics.resize and simulatorDiagnostics.display in selected-target doctor; tool availability alone does not prove either state."
    return TKCLIErrorDetail(code: detail.code, message: detail.message,
        hint: (detail.hint ?? "") + diagnosis + " Do not replay an action with unknown delivery.",
        nextAction: simulatorDiagnosticNextAction(target: target), probeDiagnostic: detail.probeDiagnostic)
}

func withSimulatorDiagnosticTarget<T>(_ target: String, operation: () throws -> T) throws -> T {
    do { return try operation() }
    catch let error as IOSSimulatorDisplayError { throw SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(error.detail, target: target)) }
    catch let error as IOSSimulatorResizeError { throw SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(error.detail, target: target)) }
    catch let error as IOSSimulatorResizeCaptureError { throw SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(error.detail, target: target)) }
}
