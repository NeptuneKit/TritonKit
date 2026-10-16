import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct ServerResponseLoggingTests {
    @Test func unknownJSONDoesNotDiscloseKeysOrMultibyteValues() throws {
        let secret = "private-unknown-secret"
        let data = try JSONSerialization.data(withJSONObject: [
            "type": "unknown-\(secret)", "id": 71,
            "private-field-\(secret)": ["token": secret, "value": String(repeating: "私密🔐", count: 10_000)],
        ])
        let captured = try captureResponseStreams {
            handleResponse(data: data, store: DataStore(), targetState: TargetState())
        }
        #expect(!captured.stderr.contains(secret))
        #expect(!captured.stderr.contains("私密"))
        #expect(captured.stderr.utf8.count <= 512)
        #expect(!captured.stderr.isEmpty)
        #expect(captured.stdout.isEmpty)
    }

    @Test func responsePayloadRemainsExactWhileLogsOmitNestedSecrets() async throws {
        let secret = "private-response-secret"
        let payload = try JSONSerialization.data(withJSONObject: [
            "ok": false, "error": ["code": secret, "message": secret, "hint": secret],
            "metadata": ["authorization": ["token": secret]],
            "text": String(repeating: "敏感🔐", count: 20_000),
        ])
        let state = TargetState()
        let wire = try JSONEncoder().encode(TKMessage(id: 42, type: .input, payload: payload))
        let captured = try captureResponseStreams {
            handleResponse(data: wire, store: DataStore(), targetState: state)
        }
        #expect(!captured.stderr.contains(secret))
        #expect(!captured.stderr.contains("敏感"))
        #expect(captured.stderr.utf8.count <= 512)
        #expect(captured.stdout.isEmpty)
        let returned = await state.waitForResponse(id: 42, attempts: 1)
        #expect(returned == payload)
    }

    @Test func hierarchyAndAppMetadataStayOutOfLogsAndRemainAvailable() async throws {
        let secret = "private-hierarchy-secret"
        let info = ["appName": secret, "appBundleIdentifier": secret, "deviceDescription": secret, "osDescription": secret]
        let hierarchy = try JSONSerialization.data(withJSONObject: [
            "displayItems": [["customDisplayTitle": secret, "viewObject": ["classChainList": [secret]]]],
            "appInfo": info,
        ])
        let appInfo = try JSONSerialization.data(withJSONObject: info)
        let state = TargetState()
        let captured = try captureResponseStreams {
            for (id, type, payload) in [(1, TKRequestType.hierarchy, hierarchy), (2, .appInfo, appInfo)] {
                handleResponse(data: try JSONEncoder().encode(TKMessage(id: id, type: type, payload: payload)), store: DataStore(), targetState: state)
            }
        }
        #expect(!captured.stderr.contains(secret))
        #expect(captured.stderr.split(separator: "\n").count <= 2)
        #expect(captured.stdout.isEmpty)
        #expect(state.latestHierarchy == hierarchy)
        #expect(state.summary(connected: true, connectionID: 1)?.appName == secret)
        let returned = await state.waitForResponse(id: 2, attempts: 1)
        #expect(returned == appInfo)
    }

    @Test func healthyPingsAggregateAndFailureRetainsCountsAndBytes() async throws {
        let sink = ResponseLogSink()
        let logger = ServerResponseLogger(sink: sink.append)
        let state = TargetState()
        let healthy = try JSONEncoder().encode(TKRuntimePingResponse(pong: true, timestamp: 1))
        for id in 1...250 {
            try receive(.ping, id: id, payload: healthy, state: state, logger: logger)
        }
        #expect(sink.lines.count == 3)
        #expect(sink.lines.last?.contains("healthyPings=200") == true)
        let failure = try JSONEncoder().encode(TKErrorPayload(message: "private-ping-token", code: -1))
        try receive(.ping, id: 251, payload: failure, state: state, logger: logger)
        let line = try #require(sink.lines.last)
        #expect(line.contains("outcome=remote_failure"))
        #expect(line.contains("received=251 failures=1 healthyPings=250"))
        #expect(!line.contains("private-ping-token"))
        let returned = await state.waitForResponse(id: 251, attempts: 1)
        #expect(returned == failure)
    }

    @Test func unhealthyOrMalformedPingsAreNeverSuppressed() throws {
        let sink = ResponseLogSink()
        let logger = ServerResponseLogger(sink: sink.append)
        let state = TargetState()
        for healthState in [TKRuntimeUIHealthState.busy, .timedOut, .circuitOpen] {
            let health = TKRuntimeUIHealthSnapshot(state: healthState, allowsUIRequests: false,
                inflight: .init(token: "private-health-token", requestID: 7, requestType: "private-type", elapsedMilliseconds: 1, timedOut: true),
                consecutiveTimeouts: 1, failureThreshold: 3, timeoutMilliseconds: 2000, lastCompletion: nil)
            let payload = try JSONEncoder().encode(TKRuntimePingResponse(pong: true, timestamp: 1, uiHealth: health))
            try receive(.ping, payload: payload, state: state, logger: logger)
        }
        try receive(.ping, payload: Data(#"{"pong":true,"timestamp":1,"uiHealth":{"state":"private-new-state"}}"#.utf8), state: state, logger: logger)
        try receive(.ping, payload: Data(#"{"pong":false,"timestamp":1}"#.utf8), state: state, logger: logger)
        #expect(sink.lines.count == 5)
        #expect(sink.lines.prefix(3).allSatisfy { $0.contains("outcome=unhealthy_ping") })
        #expect(sink.lines[3].contains("outcome=invalid_ping"))
        #expect(sink.lines[4].contains("failures=5"))
        #expect(sink.lines.allSatisfy { !$0.contains("private-") })
    }

    @Test func invalidFramesAndMissingPayloadsRemainObservable() throws {
        let sink = ResponseLogSink()
        let logger = ServerResponseLogger(sink: sink.append)
        let state = TargetState()
        for raw in [Data([0xff, 0x00]), Data(#"{"type":"private-type","id":8}"#.utf8)] {
            handleResponse(data: raw, store: DataStore(), targetState: state, responseLogger: logger)
        }
        try receive(.input, payload: nil, state: state, logger: logger)
        try receive(.input, payload: Data("private-invalid-json".utf8), state: state, logger: logger)
        #expect(sink.lines.count == 4)
        #expect(sink.lines[0].contains("type=unknown id=none"))
        #expect(sink.lines[1].contains("outcome=invalid_message"))
        #expect(sink.lines[3].contains("outcome=invalid_payload"))
        #expect(sink.lines[3].contains("failures=4"))
        #expect(sink.lines.allSatisfy { !$0.contains("private-") })
    }

    @Test func manifestRejectsRemainVisibleWithoutLoggingSDKVersion() throws {
        let secret = "private-sdk-version"
        let sink = ResponseLogSink()
        let logger = ServerResponseLogger(sink: sink.append)
        let state = TargetState()
        let accepted = TKRuntimeManifestResponse.debugDefault(sdkVersion: secret)
        try receive(.runtimeManifest, payload: JSONEncoder().encode(accepted), state: state, logger: logger)
        #expect(state.registrationDecision.accepted)
        #expect(state.registrationDecision.sdkVersion == secret)
        let rejected = TKRuntimeManifestResponse(ok: true, platform: secret, enabled: true, sdkVersion: secret, buildConfiguration: secret, capabilities: [])
        try receive(.runtimeManifest, payload: JSONEncoder().encode(rejected), state: state, logger: logger)
        #expect(!state.registrationDecision.accepted)
        #expect(sink.lines.last?.contains("outcome=registration_rejected") == true)
        #expect(sink.lines.allSatisfy { !$0.contains(secret) })
    }

    @Test func everyKnownTypeUsesMetadataOnlyAndPreservesPayload() async throws {
        let sink = ResponseLogSink()
        let logger = ServerResponseLogger(sink: sink.append)
        let state = TargetState()
        let payload = Data(#"{"ok":false,"error":{"code":"private-code","message":"private-message"},"arbitrary":{"private-key":["private-token"]}}"#.utf8)
        for (index, type) in TKRequestType.allCases.enumerated() {
            try receive(type, id: index + 1, payload: payload, state: state, logger: logger)
            let returned = await state.waitForResponse(id: index + 1, attempts: 1)
            #expect(returned == payload)
        }
        #expect(sink.lines.count == TKRequestType.allCases.count)
        #expect(sink.lines.allSatisfy { !$0.contains("private-") && $0.contains("outcome=remote_failure") && $0.utf8.count + 1 <= 512 })
    }

    @Test func errorsAndBooleanTypesAreClassifiedConservatively() throws {
        let sink = ResponseLogSink()
        let logger = ServerResponseLogger(sink: sink.append)
        let state = TargetState()
        for raw in [#"{"ok":0}"#, #"{"ok":1}"#, #"{"ok":true,"error":null}"#,
                    #"{"ok":true,"errors":[{"code":"private-code"}]}"#, #"{"error":"private-error"}"#] {
            try receive(.input, payload: Data(raw.utf8), state: state, logger: logger)
        }
        #expect(sink.lines[0].contains("outcome=received"))
        #expect(sink.lines[1].contains("outcome=received"))
        #expect(sink.lines[2].contains("outcome=success"))
        #expect(sink.lines[4].contains("failures=2"))
        #expect(sink.lines.allSatisfy { !$0.contains("private-") })
    }

    @Test func maximumIntegerMetadataAndConcurrentCountsAreBounded() {
        let sink = ResponseLogSink()
        let logger = ServerResponseLogger(sink: sink.append)
        let payload = Data(#"{"ok":false}"#.utf8)
        let message = TKMessage(id: Int.min, type: .modifyRecognizerEnable, payload: payload)
        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            logger.record(message: message, frameBytes: Int.max, json: ["ok": false])
        }
        #expect(sink.lines.count == 200)
        #expect(sink.lines.last?.contains("received=200 failures=200") == true)
        #expect(sink.lines.allSatisfy { $0.utf8.count + 1 <= ServerResponseLogger.maximumLineBytes && !$0.contains("\n") })
    }

    private func receive(_ type: TKRequestType, id: Int = 1, payload: Data?, state: TargetState, logger: ServerResponseLogger) throws {
        let data = try JSONEncoder().encode(TKMessage(id: id, type: type, payload: payload))
        handleResponse(data: data, store: DataStore(), targetState: state, responseLogger: logger)
    }

    @Test func backgroundPingRemainsSilent() throws {
        let wire = try JSONEncoder().encode(TKMessage(id: 0, type: .ping, payload: Data(#"{"pong":true}"#.utf8)))
        let captured = try captureResponseStreams {
            handleResponse(data: wire, store: DataStore(), targetState: TargetState())
        }
        #expect(captured.stderr.isEmpty)
        #expect(captured.stdout.isEmpty)
    }
}

// Files avoid a pipe's capacity limit when proving the old implementation dumps large payloads.
private func captureResponseStreams(_ body: () throws -> Void) throws -> (stdout: String, stderr: String) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let stdoutURL = directory.appendingPathComponent("stdout")
    let stderrURL = directory.appendingPathComponent("stderr")
    FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
    FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
    let out = try FileHandle(forWritingTo: stdoutURL)
    let err = try FileHandle(forWritingTo: stderrURL)
    defer { try? out.close(); try? err.close() }
    fflush(stdout)
    fflush(stderr)
    let originalOut = dup(STDOUT_FILENO)
    let originalErr = dup(STDERR_FILENO)
    defer { close(originalOut); close(originalErr) }
    dup2(out.fileDescriptor, STDOUT_FILENO)
    dup2(err.fileDescriptor, STDERR_FILENO)
    do {
        try body()
    } catch {
        fflush(stdout); fflush(stderr)
        dup2(originalOut, STDOUT_FILENO)
        dup2(originalErr, STDERR_FILENO)
        throw error
    }
    fflush(stdout); fflush(stderr)
    dup2(originalOut, STDOUT_FILENO)
    dup2(originalErr, STDERR_FILENO)
    return (try String(contentsOf: stdoutURL, encoding: .utf8), try String(contentsOf: stderrURL, encoding: .utf8))
}

private final class ResponseLogSink: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var lines: [String] { lock.withLock { storage } }
    func append(_ line: String) { lock.withLock { storage.append(line) } }
}
