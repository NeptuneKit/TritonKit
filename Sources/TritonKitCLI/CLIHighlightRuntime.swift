import ArgumentParser
import Darwin
import Foundation
import TritonKitShared

/// The transport is injectable for request-order and zero-write tests. No CLI cleanup hook exists:
/// the App owns the session and its original attributes after this process exits.
typealias HighlightRequestTransport = (String, Data) async throws -> Data

func decodeHighlightSpec(_ input: String) throws -> TKHighlightSpec {
    let maximumBytes = 65_536
    let data: Data
    do {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") || (!trimmed.hasPrefix("{") && !trimmed.hasPrefix("[")) {
            let path = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
            guard !path.isEmpty else { throw TKHighlightError(code: "validation_failed", message: "--spec @path requires a file path") }
            let url = URL(fileURLWithPath: path)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber, size.intValue <= maximumBytes else {
                throw TKHighlightError(code: "validation_failed", message: "Highlight spec exceeds 65536 bytes")
            }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        } else {
            data = Data(input.utf8)
        }
        guard data.count <= maximumBytes else { throw TKHighlightError(code: "validation_failed", message: "Highlight spec exceeds 65536 bytes") }
        let spec = try JSONDecoder().decode(TKHighlightSpec.self, from: data)
        try spec.validate()
        return spec
    } catch let error as TKHighlightError {
        throw error
    } catch {
        throw TKHighlightError(code: "validation_failed", message: "Cannot read highlight spec: \(error)")
    }
}

func executeHighlightApply(_ request: TKHighlightApplyRequest, host: String = "127.0.0.1", port: Int = 19421, transport: HighlightRequestTransport) async throws -> Data {
    try request.validate()
    try await validateHighlightProviderManifest(transport: transport)
    let capabilityPayload = try JSONEncoder().encode(TKHighlightCapabilitiesRequest(runtimeInstanceID: request.runtimeInstanceID))
    let data = try await requestHighlightData(type: "highlightCapabilities", payload: capabilityPayload, transport: transport)
    if let error = highlightErrorInResponse(data) { throw error }
    let response = try JSONDecoder().decode(TKHighlightCapabilitiesResponse.self, from: data)
    guard response.ok, response.capability.supported else {
        throw TKHighlightError(code: "highlight_unsupported", message: response.capability.reason ?? "Target has no writable highlight provider")
    }
    // Bind the preflight's runtime identity, so a restart between preflight and apply cannot
    // accidentally address a new object with an old OID.
    let boundRequest = TKHighlightApplyRequest(
        operationID: request.operationID,
        runtimeInstanceID: request.runtimeInstanceID ?? response.runtimeInstanceID,
        ttlSeconds: request.ttlSeconds,
        spec: request.spec
    )
    let applyPayload = try JSONEncoder().encode(boundRequest)
    do {
        let data = try await requestHighlightData(type: "highlightApply", payload: applyPayload, transport: transport)
        // Only a complete typed receipt can establish the provider's write/cleanup outcome.
        // A generic error envelope after dispatch is uncertain and needs the recovery key.
        if (try? JSONDecoder().decode(TKHighlightReceipt.self, from: data)) != nil { return data }
        if let error = highlightErrorInResponse(data) { throw error }
        throw RuntimeError("Apply response did not contain a typed highlight receipt")
    } catch {
        // After dispatch, transport failure cannot establish that no properties were written.
        // Preserve the generated operation key so a caller can query the original attempt.
        let detail = cliErrorDetail(for: error, endpoint: "/request", host: host, port: port)
        let recoveryError = (error as? TKHighlightError) ?? TKHighlightError(code: detail.code, message: detail.message)
        return try JSONEncoder().encode(TKHighlightReceipt(
            ok: false,
            runtimeInstanceID: boundRequest.runtimeInstanceID ?? response.runtimeInstanceID,
            operationID: boundRequest.operationID,
            cleanupComplete: false,
            restorationVerified: false,
            residualState: .unknown,
            reason: "apply_response_unavailable_query_operation",
            error: recoveryError
        ))
    }
}

func executeHighlightRequest(type: String, payload: Data, transport: HighlightRequestTransport) async throws -> Data {
    try await validateHighlightProviderManifest(requiresEnabled: false, transport: transport)
    return try await requestHighlightData(type: type, payload: payload, transport: transport)
}

private func validateHighlightProviderManifest(requiresEnabled: Bool = true, transport: HighlightRequestTransport) async throws {
    // Existing runtimeManifest is understood by older providers. Never send a newly introduced
    // message type to a legacy runtime which may silently discard an unknown enum case.
    let manifest = try await highlightProviderManifest(transport: transport)
    guard manifest.ok,
          let capability = manifest.capabilities.first(where: { $0.name == "highlight" }),
          capability.supported, (!requiresEnabled || (manifest.enabled && capability.enabled)) else {
        let reason = manifest.capabilities.first(where: { $0.name == "highlight" })?.reason
        throw TKHighlightError(code: "highlight_unsupported", message: reason ?? "Target does not advertise a writable highlight provider")
    }
}

func executeHighlightCapabilities(_ request: TKHighlightCapabilitiesRequest, transport: HighlightRequestTransport) async throws -> Data {
    try request.validate()
    let manifest = try await highlightProviderManifest(transport: transport)
    guard manifest.ok, manifest.enabled,
          let capability = manifest.capabilities.first(where: { $0.name == "highlight" }),
          capability.supported, capability.enabled else {
        let reason = manifest.capabilities.first(where: { $0.name == "highlight" })?.reason
        // Legacy manifests have no runtime instance field. Do not manufacture an App identity.
        return try JSONEncoder().encode(TKHighlightCapabilitiesResponse(runtimeInstanceID: "unavailable", capability: .unsupported(reason: reason ?? "Target does not advertise a writable highlight provider")))
    }
    return try await requestHighlightData(type: "highlightCapabilities", payload: JSONEncoder().encode(request), transport: transport)
}

private func highlightProviderManifest(transport: HighlightRequestTransport) async throws -> TKRuntimeManifestResponse {
    let data = try await transport("runtimeManifest", Data())
    if let error = highlightErrorInResponse(data) { throw error }
    return try JSONDecoder().decode(TKRuntimeManifestResponse.self, from: data)
}

private func requestHighlightData(type: String, payload: Data, transport: HighlightRequestTransport) async throws -> Data {
    let data: Data
    do {
        data = try await transport(type, payload)
    } catch let error as CLIHTTPError {
        if type != "highlightCapabilities", (try? JSONDecoder().decode(TKHighlightReceipt.self, from: error.data)) != nil {
            return error.data
        }
        // A receipt may contain useful partial-write/cleanup evidence even on a non-2xx reply.
        if let code = highlightErrorInResponse(error.data)?.code {
            if legacyHighlightUnsupportedCodes.contains(code) {
                throw TKHighlightError(code: "highlight_unsupported", message: "Target does not expose a writable highlight provider")
            }
            return error.data
        }
        throw error
    }
    if type != "highlightCapabilities", (try? JSONDecoder().decode(TKHighlightReceipt.self, from: data)) != nil {
        return data
    }
    if let error = highlightErrorInResponse(data), legacyHighlightUnsupportedCodes.contains(error.code) {
        throw TKHighlightError(code: "highlight_unsupported", message: error.message)
    }
    let succeeded = try highlightResponseSucceeded(data)
    if succeeded || highlightErrorInResponse(data) == nil {
        if type == "highlightCapabilities" {
            _ = try JSONDecoder().decode(TKHighlightCapabilitiesResponse.self, from: data)
        } else {
            _ = try JSONDecoder().decode(TKHighlightReceipt.self, from: data)
        }
    }
    return data
}

private let legacyHighlightUnsupportedCodes: Set<String> = [
    "unknown_request", "unknown_request_type", "unsupported_request", "unsupported_request_type",
    "unsupported_capability", "unsupported_runtime_scope",
]

func highlightErrorInResponse(_ data: Data) -> TKHighlightError? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let error = object["error"] as? [String: Any],
          let code = error["code"] as? String,
          let message = error["message"] as? String else { return nil }
    return TKHighlightError(code: code, message: message)
}

func highlightResponseSucceeded(_ data: Data) throws -> Bool {
    struct Envelope: Decodable { let ok: Bool }
    // Decode a JSON Bool strictly, rather than allowing Foundation's NSNumber bridging.
    // Status.ok means a successful observation, regardless of its reported session state.
    return try JSONDecoder().decode(Envelope.self, from: data).ok
}

func runHighlightCommand(options: HighlightOptions, operation: () async throws -> Data) async throws {
    let format = effectiveFormat(options.format, json: options.json)
    do {
        let data = try await operation()
        let succeeded = try highlightResponseSucceeded(data)
        if format == .json {
            print(String(decoding: data, as: UTF8.self))
        } else {
            let object = try JSONSerialization.jsonObject(with: data)
            let pretty = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: pretty, as: UTF8.self))
        }
        if !succeeded { throw ExitCode.failure }
    } catch let exit as ExitCode {
        throw exit
    } catch let error as TKHighlightError {
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(code: error.code, message: error.message, endpoint: "/request"))
        if format == .json { print(try encodeJSON(response)) }
        else { fputs("\(error.code): \(error.message)\n", stderr) }
        throw ExitCode.failure
    } catch {
        try failCommand(error, outputFormat: format, endpoint: "/request", host: options.host, port: options.port)
    }
}
