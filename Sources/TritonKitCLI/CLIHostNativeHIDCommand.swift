import ArgumentParser
import Foundation
import TritonKitShared

/// Internal process boundary, shipped in triton itself. No external HID binary.
struct DeviceNativeHIDInput: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "hid-input", abstract: "Internal isolated native Simulator HID adapter", shouldDisplay: false)
    @Option var device: String
    @Option var request: String
    @Flag var preflightOnly = false

    func run() throws {
        let input: TKInputRequest
        do { input = try JSONDecoder().decode(TKInputRequest.self, from: Data(request.utf8)) }
        catch {
            print(try encodeJSON(TKInputResult.failure(action: "input", message: "Invalid native input request.", error: NativeHIDControlError(code: "validation_failed").detail)))
            throw ExitCode.failure
        }
        do {
            guard UUID(uuidString: device) != nil, input.type == .tap || input.type == .swipe,
                  let developer = selectedXcodeDeveloperDirectory(environment: ProcessInfo.processInfo.environment) else {
                throw NativeHIDControlError(code: "validation_failed")
            }
            let environment = ["DEVELOPER_DIR": developer]
            let screen = try nativeHIDGuardSnapshot(target: device, environment: environment)
            let sequence = try nativeHIDContacts(input: input, screen: screen)
            if preflightOnly {
                print(try encodeJSON(NativeHIDPreflightOutput(ok: true, inputDispatchVerified: false, inputSent: false)))
                return
            }
            let driver = try NativeSimulatorDigitizer(target: device, developerDirectory: developer)
            guard abs(driver.pointSize.width - screen.pointSize.width) < 0.01,
                  abs(driver.pointSize.height - screen.pointSize.height) < 0.01 else {
                throw NativeHIDControlError(code: "ios_host_hid_display_unsupported")
            }
            try executeGuardedNativeHIDGesture(expectedScreen: screen, snapshot: {
                try nativeHIDGuardSnapshot(target: device, environment: environment)
            }) {
                try executeNativeHIDContacts(sequence.contacts, cadence: sequence.cadence) { contact in
                    try driver.send(point: contact.point, phase: contact.phase, identifier: 1)
                }
            }
            print(try encodeJSON(TKInputResult.success(action: input.type.rawValue,
                message: "The built-in native Simulator HID adapter completed transport submission; guest touch delivery and business state require separate verification.",
                strategy: input.type == .tap ? "host-hid-coordinate-tap" : "host-hid-swipe", source: "host-hid",
                verification: .init(hint: "Transport completion only; verify the same Simulator's UI and business postcondition. Do not equate AX activation or framebuffer readability with physical touch.", suggestedCommands: ["triton sim ax --device <simulator> --json", "triton sim screenshot --simulator <simulator> --output <new-path> --json"]),
                sourceCommands: ["triton device hid-input --device <simulator> --request <coordinate-gesture>"])))
        } catch {
            let detail: TKCLIErrorDetail
            switch error {
            case let failure as NativeHIDDeliveryError: detail = failure.detail
            case let failure as NativeHIDControlError: detail = failure.detail
            case let failure as NativeDigitizerError: detail = failure.detail
            case let failure as IOSSimulatorResizeError: detail = failure.detail
            default: detail = NativeHIDControlError(code: "ios_host_hid_helper_failed").detail
            }
            print(try encodeJSON(TKInputResult.failure(action: input.type.rawValue, message: detail.message, error: detail)))
            throw ExitCode.failure
        }
    }
}

private struct NativeHIDPreflightOutput: Encodable {
    let ok: Bool
    let inputDispatchVerified: Bool
    let inputSent: Bool
}
