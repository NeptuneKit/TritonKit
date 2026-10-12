import Foundation
import TritonKitShared

/// Host-only dispatch: this function has no embedded client or service startup path.
func runSimulatorSwipe(
    selected: HostDeviceTarget,
    input: TKInputRequest,
    runner: (String, TKInputRequest) throws -> TKInputResult = { try runWebHostDeviceInput(id: $0, input: $1) }
) throws -> TKInputResult {
    guard selected.platform == "ios", selected.scope == "simulator", selected.ready else {
        return .failure(action: "swipe", message: "A booted local iOS Simulator is required.", error: TKCLIErrorDetail(code: "simulator_not_booted", message: "A booted local iOS Simulator is required."))
    }
    let result: TKInputResult
    do {
        result = try runner(webHostDeviceTargetID(selected), input)
    } catch HostCommandRunError.launchFailed {
        return unavailableSimulatorSwipeAdapter()
    } catch HostCommandRunError.nonZeroExit(_, let process) where process.exitCode == 127 {
        return unavailableSimulatorSwipeAdapter()
    }
    guard result.ok else { return result }
    return .success(
        action: "swipe",
        message: result.message,
        strategy: result.strategy,
        source: result.source,
        verification: TKInputVerificationBoundary(
            hint: "Host HID acknowledgement is submission-only; inspect the settled UI using host AX or screenshot before claiming business completion.",
            suggestedCommands: [
                "triton sim ax --device \(selected.rawTarget) --json",
                "triton sim screenshot --simulator \(selected.rawTarget) --output <new-path> --json",
            ]
        ),
        sourceCommands: result.sourceCommands
    )
}

private func unavailableSimulatorSwipeAdapter() -> TKInputResult {
    .unsupported(action: "swipe", message: "The host HID adapter is unavailable.", error: TKCLIErrorDetail(code: "unsupported_host_input", message: "The host HID adapter is unavailable.", hint: "Install or configure Baguette with TRITONKIT_BAGUETTE_BIN, then retry; no embedded fallback was attempted."))
}
