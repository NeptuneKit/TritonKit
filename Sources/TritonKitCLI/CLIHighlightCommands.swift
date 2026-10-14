import ArgumentParser
import Foundation
import TritonKitShared

struct Highlight: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "highlight",
        abstract: "Temporarily highlight App nodes through an optional writable provider",
        discussion: "Independent of screenshots. No provider is installed automatically. CLI exit leaves the session active until clear or TTL cleanup.",
        subcommands: [HighlightApply.self, HighlightStatus.self, HighlightClear.self, HighlightCapabilities.self]
    )
}

struct HighlightOptions: ParsableArguments {
    @Option(help: "Target id from triton list") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(name: .customLong("runtime-instance-id"), help: "Expected App runtime instance; stale instances are rejected") var runtimeInstanceID: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
}

struct HighlightApply: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", abstract: "Save original attributes and temporarily apply outline highlighting")
    @OptionGroup var options: HighlightOptions
    @Option(help: "Highlight spec as JSON, file path or @path. P0 UIKit selectors: oid|identifier and optional withinOID; text/role are unsupported") var spec: String
    @Option(help: "Session lifetime in seconds, 1–300") var ttl: Int = 30
    @Option(name: .customLong("operation-id"), help: "Idempotency key; generated when omitted. Query a lost response using status --operation") var operationID: String?

    func makeRequest() throws -> TKHighlightApplyRequest {
        let request = TKHighlightApplyRequest(
            operationID: operationID ?? UUID().uuidString,
            runtimeInstanceID: options.runtimeInstanceID,
            ttlSeconds: ttl,
            spec: try decodeHighlightSpec(spec)
        )
        try request.validate()
        return request
    }

    func run() async throws {
        try await runHighlightCommand(options: options) {
            let request = try makeRequest()
            let summary = try await resolveTarget(options.target, host: options.host, port: options.port)
            let client = TritonKitHTTPClient(host: options.host, port: options.port, target: summary.id)
            return try await executeHighlightApply(request, host: options.host, port: options.port) { type, payload in
                try await client.request(type: type, payload: payload)
            }
        }
    }
}

struct HighlightStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Read a highlight receipt by session or operation; does not renew TTL")
    @OptionGroup var options: HighlightOptions
    @Option(help: "Session id returned by apply") var session: String?
    @Option(help: "Operation id used by apply; mutually exclusive with --session") var operation: String?

    func makeRequest() throws -> TKHighlightStatusRequest {
        let request = TKHighlightStatusRequest(sessionID: session, operationID: operation, runtimeInstanceID: options.runtimeInstanceID)
        try request.validate()
        return request
    }

    func run() async throws {
        try await runHighlightCommand(options: options) {
            let request = try makeRequest()
            let summary = try await resolveTarget(options.target, host: options.host, port: options.port)
            let client = TritonKitHTTPClient(host: options.host, port: options.port, target: summary.id)
            return try await executeHighlightRequest(type: "highlightStatus", payload: JSONEncoder().encode(request)) { type, payload in
                try await client.request(type: type, payload: payload)
            }
        }
    }
}

struct HighlightClear: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clear", abstract: "Restore unchanged highlight attributes for a session or selected marks")
    @OptionGroup var options: HighlightOptions
    @Option(help: "Session id returned by apply") var session: String
    @Option(name: .customLong("mark"), parsing: .singleValue, help: "Mark id to clear; repeat for a subset. Omit to clear all") var marks: [String] = []

    func makeRequest() throws -> TKHighlightClearRequest {
        let request = TKHighlightClearRequest(sessionID: session, markIDs: marks, runtimeInstanceID: options.runtimeInstanceID)
        try request.validate()
        return request
    }

    func run() async throws {
        try await runHighlightCommand(options: options) {
            let request = try makeRequest()
            let summary = try await resolveTarget(options.target, host: options.host, port: options.port)
            let client = TritonKitHTTPClient(host: options.host, port: options.port, target: summary.id)
            return try await executeHighlightRequest(type: "highlightClear", payload: JSONEncoder().encode(request)) { type, payload in
                try await client.request(type: type, payload: payload)
            }
        }
    }
}

struct HighlightCapabilities: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "capabilities", abstract: "Probe an optional writable highlight provider without changing App attributes")
    @OptionGroup var options: HighlightOptions

    func run() async throws {
        try await runHighlightCommand(options: options) {
            let request = TKHighlightCapabilitiesRequest(runtimeInstanceID: options.runtimeInstanceID)
            try request.validate()
            let summary = try await resolveTarget(options.target, host: options.host, port: options.port)
            let client = TritonKitHTTPClient(host: options.host, port: options.port, target: summary.id)
            return try await executeHighlightCapabilities(request) { type, payload in
                try await client.request(type: type, payload: payload)
            }
        }
    }
}
