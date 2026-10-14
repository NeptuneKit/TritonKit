import Foundation
import Hummingbird
import NIOCore
import NIOFoundationCompat

/// The execute closure receives the same host payload as CLI; no embedded runtime is involved.
func registerIOSRunnerRoutes<Context: RequestContext>(
    on router: Router<Context>,
    service: IOSRunnerService = IOSRunnerService()
) {
    registerIOSRunnerRoutes(on: router, execute: { operation, payload in try service.execute(operation: operation, payload: payload) })
}

func registerIOSRunnerRoutes<Context: RequestContext>(
    on router: Router<Context>,
    execute: @escaping @Sendable (String, Data) throws -> Data
) {
    for operation in ["doctor", "prepare", "start", "status", "stop", "request", "receipt"] {
        router.post("/v1/device/runner/\(operation)") { request, _ -> Response in
            var data = Data()
            do {
                for try await chunk in request.body {
                    guard chunk.readableBytes <= 65536 - data.count else {
                        return iosRunnerHTTPResponse(iosRunnerErrorEnvelope(code: "ios_runner_payload_too_large", message: "Runner payload exceeds 64KiB"), status: .contentTooLarge)
                    }
                    data.append(Data(buffer: chunk))
                }
            } catch {
                return iosRunnerHTTPResponse(iosRunnerErrorEnvelope(code: "ios_runner_invalid_payload", message: "Unable to read Runner payload"), status: .badRequest)
            }
            return await iosRunnerHTTPExecute(operation: operation, payload: data, execute: execute)
        }
    }
    for operation in ["doctor", "status"] {
        router.get("/v1/device/runner/\(operation)") { request, _ -> Response in
            var payload: [String: Any] = [:]
            for name in ["device", "sessionRoot"] {
                if let value = request.uri.queryParameters[Substring(name)] { payload[name] = String(value) }
            }
            if let raw = request.uri.queryParameters["timeout"] {
                guard let timeout = Double(raw), timeout.isFinite, timeout >= 1, timeout <= 3600 else {
                    return iosRunnerHTTPResponse(iosRunnerErrorEnvelope(code: "ios_runner_invalid_payload", message: "timeout must be 1...3600 seconds"), status: .badRequest)
                }
                payload["timeout"] = timeout
            }
            let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
            return await iosRunnerHTTPExecute(operation: operation, payload: data, execute: execute)
        }
    }
}

private func iosRunnerHTTPExecute(operation: String, payload: Data, execute: @escaping @Sendable (String, Data) throws -> Data) async -> Response {
    guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
          let device = object["device"] as? String, !device.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return iosRunnerHTTPResponse(iosRunnerErrorEnvelope(code: "ios_runner_invalid_payload", message: "An explicit device is required in a JSON object"), status: .badRequest)
    }
    let output: Data
    do {
        output = try await Task.detached { try execute(operation, payload) }.value
    } catch {
        return iosRunnerHTTPResponse(iosRunnerErrorEnvelope(code: "ios_runner_operation_failed", message: "Runner operation failed; inspect private session diagnostics"), status: .internalServerError)
    }
    guard let envelope = try? JSONSerialization.jsonObject(with: output) as? [String: Any], let ok = envelope["ok"] as? Bool else {
        return iosRunnerHTTPResponse(iosRunnerErrorEnvelope(code: "ios_runner_invalid_response", message: "Runner returned an invalid response"), status: .internalServerError)
    }
    return iosRunnerHTTPResponse(output, status: ok ? .ok : .conflict)
}

private func iosRunnerHTTPResponse(_ data: Data, status: HTTPResponse.Status) -> Response {
    Response(status: status, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(data: data)))
}
