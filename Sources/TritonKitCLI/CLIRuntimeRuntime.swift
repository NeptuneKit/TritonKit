import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

func runSemanticSelectorAction(
    action: TKSemanticActionType,
    sourceCommand: String,
    selector: String,
    target: String,
    host: String,
    port: Int,
    text: String? = nil,
    secure: Bool = false,
    segmentTitle: String? = nil,
    segmentIndex: Int? = nil,
    switchValue: String? = nil,
    index: Int? = nil,
    within: String? = nil,
    at: String? = nil,
    runtimeBaseURL: String? = nil,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        if within != nil && at != nil {
            if outputFormat == .json {
                try printValidationError("--within and --at cannot be used together")
                throw ExitCode.failure
            }
            throw RuntimeError("--within and --at cannot be used together")
        }
        let bounds = try within.map(parseBounds)
        let point = try at.map(parsePoint)
        if let runtimeBaseURL {
            let request = TKSemanticActionRequest(
                action: action,
                selector: selector,
                sourceCommand: sourceCommand,
                strategy: "app-provider-selector",
                targetOID: nil,
                x: point?.x,
                y: point?.y,
                text: text,
                secure: secure,
                segmentTitle: segmentTitle,
                segmentIndex: segmentIndex,
                switchValue: switchValue
            )
            try await runSemanticActionRequest(request, runtimeBaseURL: runtimeBaseURL, format: outputFormat)
        } else {
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let resolution = try await resolveTapTarget(
                selector,
                client: client,
                width: nil,
                height: nil,
                duration: nil,
                index: index,
                within: bounds,
                at: point
            )
            let request = TKSemanticActionRequest(
                action: action,
                selector: selector,
                sourceCommand: sourceCommand,
                strategy: "selector-\(resolution.strategy)",
                targetOID: resolution.request.targetOID,
                x: resolution.request.x,
                y: resolution.request.y,
                text: text,
                secure: secure,
                segmentTitle: segmentTitle,
                segmentIndex: segmentIndex,
                switchValue: switchValue
            )
            try await runSemanticActionRequest(request, client: client, format: outputFormat)
        }
    } catch {
        if error is ExitCode { throw error }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func runSemanticActionRequest(
    _ request: TKSemanticActionRequest,
    host: String,
    port: Int,
    format: ClientOutputFormat
) async throws {
    try await runSemanticActionRequest(request, client: TritonKitHTTPClient(host: host, port: port), format: format)
}

func runSemanticActionRequest(
    _ request: TKSemanticActionRequest,
    client: TritonKitHTTPClient,
    format: ClientOutputFormat
) async throws {
    let payload = try JSONEncoder().encode(request)
    let data = try await client.request(type: "semanticAction", payload: payload)
    let result = try JSONDecoder().decode(TKSemanticActionResponse.self, from: data)
    try printSemanticAction(result, format: format)
    if !result.ok {
        throw RuntimeError(result.message ?? result.error?.message ?? "Semantic action failed")
    }
}

func runSemanticActionRequest(
    _ request: TKSemanticActionRequest,
    runtimeBaseURL: String,
    format: ClientOutputFormat
) async throws {
    let payload = try JSONEncoder().encode(request)
    let data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.semanticAction, body: payload)
    let result = try JSONDecoder().decode(TKSemanticActionResponse.self, from: data)
    try printSemanticAction(result, format: format)
    if !result.ok {
        throw RuntimeError(result.message ?? result.error?.message ?? "Semantic action failed")
    }
}

func printRawJSONData(_ data: Data, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(String(data: data, encoding: .utf8) ?? "{}")
    case .text:
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: pretty, encoding: .utf8) {
            print(text)
        } else {
            print(String(data: data, encoding: .utf8) ?? "")
        }
    }
}

func printSemanticAction(_ result: TKSemanticActionResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeCompactJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("action: \(result.action.rawValue)")
        print("strategy: \(result.strategy)")
        if let targetOID = result.targetOID { print("targetOID: \(targetOID)") }
        if let targetClassName = result.targetClassName { print("targetClassName: \(targetClassName)") }
        print("elapsedMs: \(result.elapsedMs)")
        if let message = result.message { print("message: \(message)") }
        if let error = result.error { print("error: \(error.code) \(error.message)") }
    }
}

func printLedger(_ response: TKRuntimeLedgerResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeCompactJSON(response))
    case .text:
        for entry in response.entries {
            let status = entry.ok ? "ok" : "failed"
            print("#\(entry.id) \(entry.timestamp) \(entry.requestType) \(entry.action ?? "-") \(status) \(entry.elapsedMs)ms")
            if let message = entry.message { print("  \(message)") }
        }
    }
}
