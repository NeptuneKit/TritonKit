import ArgumentParser
import Foundation
import TritonKitShared

struct DebugUIHealth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ui-health", abstract: "Probe runtime transport and UI admission independently of UI work")

    @Option(help: "Runtime target id from triton list") var target = TKLocalTargetID
    @Option(help: "Server host") var host = "127.0.0.1"
    @Option(help: "Server port") var port = 19421
    @Option(help: "Total probe deadline in seconds, including target selection (0.05...30)") var timeout: Double = 2
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func validate() throws {
        try validateRuntimeUIHealthOptions(host: host, port: port, timeout: timeout)
    }

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try await probeRuntimeUIHealth(target: target, host: host, port: port, timeout: timeout)
            switch outputFormat {
            case .json: print(try encodeJSON(result))
            case .text:
                print("target: \(result.target)")
                print("pong: \(result.pong)")
                print("uiState: \(result.uiState)")
                if let allowed = result.allowsUIRequests { print("allowsUIRequests: \(allowed)") }
                print("businessVerified: false")
                if let hint = result.uiHealth?.recoveryHint { print("recovery: \(hint)") }
            }
            if !result.ok { throw ExitCode.failure }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct RuntimeUIHealthOutput: Codable, Equatable {
    /// Transport pong acknowledgement, never UI or business success.
    let ok: Bool
    let action: String
    let target: String
    let pong: Bool
    let timestamp: TimeInterval
    let uiState: String
    let allowsUIRequests: Bool?
    let uiHealth: TKRuntimeUIHealthSnapshot?
    let businessVerified: Bool
}

func runtimeUIHealthOutput(data: Data, target: String) throws -> RuntimeUIHealthOutput {
    let pong = try JSONDecoder().decode(TKRuntimePingResponse.self, from: data)
    return RuntimeUIHealthOutput(ok: pong.pong, action: "debug.ui-health", target: target, pong: pong.pong, timestamp: pong.timestamp, uiState: pong.uiHealth?.state.rawValue ?? "unknown", allowsUIRequests: pong.uiHealth?.allowsUIRequests, uiHealth: pong.uiHealth, businessVerified: false)
}

private func validateRuntimeUIHealthOptions(host: String, port: Int, timeout: Double) throws {
    guard timeout.isFinite, (0.05...30).contains(timeout) else {
        throw ValidationError("--timeout must be finite and between 0.05 and 30 seconds")
    }
    guard (1...65535).contains(port), !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ValidationError("--host must be nonempty and --port must be between 1 and 65535")
    }
    var components = URLComponents()
    components.scheme = "http"
    components.host = host
    components.port = port
    components.path = "/targets"
    guard components.url != nil else { throw ValidationError("--host is not a valid HTTP host") }
}

/// An independent URLSession and one absolute deadline cover discovery and ping together.
/// The deadline resumes independently and cancels only this probe's read-only HTTP work.
func probeRuntimeUIHealth(target: String, host: String, port: Int, timeout: Double, sessionConfiguration: URLSessionConfiguration? = nil) async throws -> RuntimeUIHealthOutput {
    try validateRuntimeUIHealthOptions(host: host, port: port, timeout: timeout)
    let deadline = DispatchTime.now() + timeout
    let configuration = (sessionConfiguration?.copy() as? URLSessionConfiguration) ?? .ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.waitsForConnectivity = false
    configuration.urlCache = nil
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RuntimeUIHealthOutput, Error>) in
        let completion = RuntimeUIHealthProbeCompletion(continuation)
        let expiry = DispatchWorkItem {
            completion.finish(.failure(URLError(.timedOut)))
            session.invalidateAndCancel()
        }
        completion.setDeadline(expiry)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline, execute: expiry)
        Task.detached {
            do {
                guard DispatchTime.now() < deadline else { throw URLError(.timedOut) }
                var client = TritonKitHTTPClient(host: host, port: port, session: session)
                let inventory: TKTargetsResponse = try await client.getJSON("/targets")
                let selected = try TKResolveTargetSummary(target, in: inventory.targets)
                guard DispatchTime.now() < deadline else { throw URLError(.timedOut) }
                client.target = selected.id
                let data = try await client.request(type: "ping")
                let output = try runtimeUIHealthOutput(data: data, target: selected.id)
                guard DispatchTime.now() < deadline else { throw URLError(.timedOut) }
                completion.finish(.success(output))
            } catch {
                completion.finish(.failure(DispatchTime.now() >= deadline ? URLError(.timedOut) : error))
            }
        }
    }
}

private final class RuntimeUIHealthProbeCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<RuntimeUIHealthOutput, Error>?
    private var deadline: DispatchWorkItem?
    init(_ continuation: CheckedContinuation<RuntimeUIHealthOutput, Error>) { self.continuation = continuation }
    func setDeadline(_ item: DispatchWorkItem) { lock.withLock { deadline = item } }
    func finish(_ result: Result<RuntimeUIHealthOutput, Error>) {
        let callback = lock.withLock { () -> CheckedContinuation<RuntimeUIHealthOutput, Error>? in
            deadline?.cancel()
            deadline = nil
            defer { continuation = nil }
            return continuation
        }
        callback?.resume(with: result)
    }
}
