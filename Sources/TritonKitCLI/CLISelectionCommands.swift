import ArgumentParser
import Foundation
import TritonKitShared

struct SelectionOptions: ParsableArguments {
    @Option(help: "Embedded runtime target id from triton list") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(name: .customLong("runtime-instance-id"), help: "Expected runtime process identity") var runtimeInstanceID: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
}

struct InspectSelection: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "selection", abstract: "Read the floating picker's current selection and validity")
    @OptionGroup var options: SelectionOptions
    func run() async throws { try await runSelectionCommand(type: "selectionStatus", options: options) }
}

struct InspectSelectionClear: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clear", abstract: "Clear the floating picker's current selection")
    @OptionGroup var options: SelectionOptions
    func run() async throws { try await runSelectionCommand(type: "selectionClear", options: options) }
}

struct InspectSelectionCapabilities: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "capabilities", abstract: "Probe the explicitly enabled SDK floating picker")
    @OptionGroup var options: SelectionOptions
    func run() async throws { try await runSelectionCommand(type: "selectionCapabilities", options: options) }
}

func executeSelectionRequest(
    type: String,
    request: TKSelectionRequest,
    send: (String, Data) async throws -> Data
) async throws -> TKSelectionResponse {
    if let runtime = request.runtimeInstanceID, runtime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw TKSelectionError(code: "validation_failed", message: "--runtime-instance-id must not be empty.")
    }
    let data = try await send(type, JSONEncoder().encode(request))
    return try JSONDecoder().decode(TKSelectionResponse.self, from: data)
}

private func runSelectionCommand(type: String, options: SelectionOptions) async throws {
    let format = effectiveFormat(options.format, json: options.json)
    do {
        if let runtime = options.runtimeInstanceID, runtime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TKSelectionError(code: "validation_failed", message: "--runtime-instance-id must not be empty.")
        }
        let (_, client) = try await resolveRuntimeClient(target: options.target, host: options.host, port: options.port, jsonError: format == .json)
        let result = try await executeSelectionRequest(type: type, request: TKSelectionRequest(runtimeInstanceID: options.runtimeInstanceID)) { type, payload in
            try await client.request(type: type, payload: payload)
        }
        if format == .json { print(try encodeJSON(result)) }
        else { print("\(result.state): \(result.selection?.id ?? "none") (revision \(result.revision))") }
        if !result.ok { throw ExitCode.failure }
    } catch let error as TKSelectionError {
        try failHostValidation(code: error.code, message: error.message, hint: "Use a current runtime identity from inspect selection.", outputFormat: format)
    } catch {
        if error is ExitCode { throw error }
        try failCommand(error, outputFormat: format, endpoint: "/request", host: options.host, port: options.port)
    }
}

extension Tap {
    /// Build a single guarded runtime input. Never resolve a selection to a bare OID on the CLI.
    func makeSelectionInputRequest() throws -> TKInputRequest? {
        guard selection != nil || selectionRevision != nil || runtimeInstanceID != nil else { return nil }
        guard let selection, let selectionRevision, let runtimeInstanceID else {
            throw TKSelectionError(code: "validation_failed", message: "--selection, --selection-revision and --runtime-instance-id must be supplied together.")
        }
        let guardValue = TKSelectionGuard(runtimeInstanceID: runtimeInstanceID, selectionID: selection, revision: selectionRevision)
        try guardValue.validate()
        guard query == nil, text == nil, oid == nil, axOID == nil, axLabel == nil,
              x == nil, y == nil, at == nil, width == nil, height == nil,
              strategy == nil, index == nil, within == nil, platform == nil,
              !webViewAware, selector == nil, webViewID == nil, pageSessionID == nil, expectText == nil,
              !allowHostHIDFallback, adb == "adb", hdc == "hdc", timeout == 3 else {
            throw TKSelectionError(code: "validation_failed", message: "Selection taps cannot combine text, OID, coordinate, host, WebView, strategy or fallback options.")
        }
        return TKInputRequest(type: .tap, selection: guardValue)
    }

    func runSelectionTap(_ request: TKInputRequest, outputFormat: ClientOutputFormat) async throws {
        do {
            let (runtimeTarget, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            if let leaseID {
                try await enforceTargetLease(host: host, port: port, target: runtimeTarget.simulatorUDID ?? runtimeTarget.id, leaseID: leaseID)
            }
            try await runInputRequest(request, client: client, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}
