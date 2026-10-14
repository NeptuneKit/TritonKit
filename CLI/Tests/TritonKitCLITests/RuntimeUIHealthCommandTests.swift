import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized) struct RuntimeUIHealthCommandTests {
    @Test func commandParsesUnderDebugWithBoundedDefaults() throws {
        let command = try #require(TritonKitCLI.parseAsRoot(["debug", "ui-health"]) as? DebugUIHealth)
        #expect(command.target == TKLocalTargetID)
        #expect(command.host == "127.0.0.1")
        #expect(command.port == 19421)
        #expect(command.timeout == 2)
        let explicit = try DebugUIHealth.parse(["--target", "fixture", "--host", "localhost", "--port", "19421", "--timeout", "0.05", "--format", "text", "--json"])
        #expect(explicit.target == "fixture")
        #expect(explicit.timeout == 0.05)
        #expect(effectiveFormat(explicit.format, json: explicit.json) == .json)
    }

    @Test func invalidTimeoutsAreRejected() {
        for value in ["0", "0.049", "30.001", "nan", "inf"] {
            #expect(throws: (any Error).self) { _ = try DebugUIHealth.parse(["--timeout", value]) }
        }
    }

    @Test func probeSelectsTargetBeforePing() async throws {
        UIHealthProbeProtocol.configure(delayed: false)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UIHealthProbeProtocol.self]
        let result = try await probeRuntimeUIHealth(target: "fixture", host: "127.0.0.1", port: 19421, timeout: 1, sessionConfiguration: configuration)
        #expect(result.target == "fixture")
        #expect(result.action == "debug.ui-health")
        #expect(result.ok)
        #expect(result.uiState == "unknown")
        #expect(UIHealthProbeProtocol.paths == ["/targets", "/request"])
        #expect(UIHealthProbeProtocol.pingTarget == "fixture")
        #expect(UIHealthProbeProtocol.pingType == "ping")
    }

    @Test func totalDeadlineBoundsSetupAndPingTogether() async throws {
        UIHealthProbeProtocol.configure(delayed: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UIHealthProbeProtocol.self]
        let start = ContinuousClock.now
        do {
            _ = try await probeRuntimeUIHealth(target: "fixture", host: "127.0.0.1", port: 19421, timeout: 0.06, sessionConfiguration: configuration)
            Issue.record("Expected bounded probe deadline")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        }
        #expect(start.duration(to: .now) < .seconds(1))
    }

    @Test func legacyPingDoesNotClaimUIReadiness() throws {
        let output = try runtimeUIHealthOutput(data: Data(#"{"pong":true,"timestamp":1}"#.utf8), target: "fixture")
        #expect(output.ok)
        #expect(output.uiState == "unknown")
        #expect(output.allowsUIRequests == nil)
        #expect(!output.businessVerified)
    }

    @Test func timedOutHealthPreservesUnknownExecution() throws {
        let health = TKRuntimeUIHealthSnapshot(state: .timedOut, allowsUIRequests: false,
            inflight: .init(token: "fixture", requestID: 1, requestType: "input", elapsedMilliseconds: 2000, timedOut: true),
            consecutiveTimeouts: 1, failureThreshold: 3, timeoutMilliseconds: 2000, lastCompletion: nil)
        let ping = TKRuntimePingResponse(pong: true, timestamp: 1, uiHealth: health)
        let output = try runtimeUIHealthOutput(data: JSONEncoder().encode(ping), target: "fixture")
        #expect(output.ok)
        #expect(output.uiState == "timed_out")
        #expect(output.allowsUIRequests == false)
        #expect(output.uiHealth == health)
    }
}

private final class UIHealthProbeProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var shouldDelay = false
    private static var recordedPaths: [String] = []
    private static var recordedTarget: String?
    private static var recordedType: String?
    static var paths: [String] { lock.withLock { recordedPaths } }
    static var pingTarget: String? { lock.withLock { recordedTarget } }
    static var pingType: String? { lock.withLock { recordedType } }
    private let loadingLock = NSLock()
    private var stopped = false
    private var delayedResponse: DispatchWorkItem?
    static func configure(delayed: Bool) {
        lock.withLock { shouldDelay = delayed; recordedPaths = []; recordedTarget = nil; recordedType = nil }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.lock.withLock { Self.recordedPaths.append(path) }
        let data: Data
        if path == "/targets" {
            data = try! JSONEncoder().encode(TKTargetsResponse(targets: [TKTargetSummary(id: "fixture", connected: true, latestHierarchyAvailable: false)]))
        } else {
            if let body = request.httpBody ?? request.httpBodyStream.map(Self.readBody),
               let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                Self.lock.withLock { Self.recordedTarget = object["target"] as? String; Self.recordedType = object["type"] as? String }
            }
            data = Data(#"{"pong":true,"timestamp":1}"#.utf8)
        }
        if Self.lock.withLock({ Self.shouldDelay }) {
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.loadingLock.withLock({ self.stopped }) else { return }
                self.respond(data)
            }
            loadingLock.withLock { delayedResponse = work }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.04, execute: work)
        } else {
            respond(data)
        }
    }
    private func respond(_ data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { loadingLock.withLock { stopped = true; delayedResponse?.cancel(); delayedResponse = nil } }
    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 512)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            body.append(contentsOf: buffer.prefix(count))
        }
        return body
    }
}
