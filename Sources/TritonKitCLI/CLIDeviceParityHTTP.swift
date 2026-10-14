import Darwin
import Foundation
import Hummingbird
import NIOCore
import NIOFoundationCompat
import TritonKitShared

/// Uses the same installed executable and argument parser as CLI, with an explicit
/// local target and closed device command allowlist. No shell, MCP or Web write bridge.
func registerDeviceParityRoutes<Context: RequestContext>(on router: Router<Context>) {
    registerDeviceParityRoutes(on: router, execute: executeDeviceParityHTTPArguments)
}

func registerDeviceParityRoutes<Context: RequestContext>(
    on router: Router<Context>,
    execute: @escaping @Sendable ([String]) throws -> Data
) {
    router.post("/v1/device/command") { request, _ -> Response in
        var data = Data()
        do {
            for try await buffer in request.body {
                guard buffer.readableBytes <= 65536 - data.count else {
                    return deviceParityHTTPResponse(deviceParityHTTPError("device_command_payload_limit", "Device command body exceeds 64KiB"), .contentTooLarge)
                }
                data.append(Data(buffer: buffer))
            }
            let arguments = try deviceParityHTTPArguments(data)
            let output = try await Task.detached { try execute(arguments) }.value
            guard let envelope = try? JSONSerialization.jsonObject(with: output) as? [String: Any],
                  let ok = envelope["ok"] as? Bool else {
                return deviceParityHTTPResponse(deviceParityHTTPError("device_command_invalid_response", "CLI did not return one JSON envelope"), .internalServerError)
            }
            return deviceParityHTTPResponse(output, ok ? .ok : .conflict)
        } catch let failure as DeviceParityHTTPValidation {
            return deviceParityHTTPResponse(deviceParityHTTPError("device_command_invalid_request", failure.message), .badRequest)
        } catch {
            return deviceParityHTTPResponse(deviceParityHTTPError("device_command_failed", "Device command failed; inspect private CLI diagnostics before retrying"), .internalServerError)
        }
    }
}

struct DeviceParityHTTPValidation: Error { let message: String }
func deviceParityHTTPArguments(_ data: Data) throws -> [String] {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          Set(object.keys) == ["arguments"], let args = object["arguments"] as? [String],
          !args.isEmpty, args.count <= 80,
          args.allSatisfy({ !$0.contains("\0") && $0.utf8.count <= 8192 }) else {
        throw DeviceParityHTTPValidation(message: "A bounded arguments array is required")
    }
    let allowed = ["orientation", "fold", "location", "clipboard", "foreground", "recording", "logs", "crashes", "tap", "double-tap", "press", "swipe"]
    guard allowed.contains(args[0]), !args.contains("_worker"), !args.contains("--help"), !args.contains("-h"),
          !args.contains("--jsonl"), !args.contains("--format"), !args.contains(where: { $0.hasPrefix("--format=") }),
          let index = args.firstIndex(of: "--device"), args.indices.contains(index + 1),
          !args[index + 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !args[index + 1].hasPrefix("--"), args[index + 1] != "all" else {
        throw DeviceParityHTTPValidation(message: "Select a supported device command and one explicit --device; JSON output is required")
    }
    return ["device"] + args.filter { $0 != "--json" } + ["--json"]
}

private func executeDeviceParityHTTPArguments(_ arguments: [String]) throws -> Data {
    let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
    let timeout: Double = arguments.contains("logs") ? 125 : arguments.contains("stop") ? 185 : 45
    let command = TKHostCommand(executable: executable, arguments: arguments, defaultTimeoutSeconds: timeout)
    let result: HostProcessResult
    do { result = try runHostCommand(command, maximumOutputBytes: 1_048_576) }
    catch HostCommandRunError.nonZeroExit(_, let failed) {
        // A CLI failure normally contains the authoritative JSON error envelope.
        // Preserve it instead of erasing its code in a second HTTP wrapper.
        result = failed
    }
    guard !result.stdoutTruncated else { throw DeviceParityHTTPValidation(message: "CLI response exceeds HTTP byte budget") }
    return result.stdoutData
}
private func deviceParityHTTPError(_ code: String, _ message: String) -> Data {
    (try? JSONSerialization.data(withJSONObject: ["ok": false, "error": ["code": code, "message": message]], options: [.sortedKeys])) ?? Data("{\"ok\":false}".utf8)
}
private func deviceParityHTTPResponse(_ data: Data, _ status: HTTPResponse.Status) -> Response {
    Response(status: status, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(data: data)))
}
