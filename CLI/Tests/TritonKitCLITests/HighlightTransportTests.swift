import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Highlight HTTP request transport", .serialized)
struct HighlightTransportTests {
    @Test("apply traverses existing /request with target and bound runtime identity, without clear on exit")
    func applyRoundTrip() async throws {
        HighlightFixtureURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HighlightFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = TritonKitHTTPClient(host: "127.0.0.1", port: 19421, target: "app-a", session: session)
        let request = TKHighlightApplyRequest(operationID: "op-a", ttlSeconds: 19, spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(oid: 42))]))
        let data = try await executeHighlightApply(request) { type, payload in
            try await client.request(type: type, payload: payload)
        }
        let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: data)
        #expect(receipt.ok)
        #expect(receipt.state == .active)
        #expect(receipt.sessionID == "s-a")
        let commands = HighlightFixtureURLProtocol.commands
        #expect(commands.map(\.type) == ["runtimeManifest", "highlightCapabilities", "highlightApply"])
        #expect(commands.allSatisfy { $0.target == "app-a" })
        let apply = try JSONDecoder().decode(TKHighlightApplyRequest.self, from: #require(commands.last?.payload))
        #expect(apply.runtimeInstanceID == "r-a")
        #expect(apply.ttlSeconds == 19)
        #expect(apply.operationID == "op-a")
    }

    @Test("lost apply response preserves generated recovery key and unknown residue")
    func lostApplyResponse() async throws {
        let request = TKHighlightApplyRequest(operationID: "op-recover", spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(oid: 42))]))
        let data = try await executeHighlightApply(request) { type, _ in
            if type == "runtimeManifest" { return try highlightSupportedManifestData() }
            if type == "highlightCapabilities" {
                return try JSONEncoder().encode(TKHighlightCapabilitiesResponse(runtimeInstanceID: "r-a", capability: TKHighlightCapability(supported: true)))
            }
            throw URLError(.timedOut)
        }
        let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: data)
        #expect(!receipt.ok)
        #expect(receipt.operationID == "op-recover")
        #expect(receipt.runtimeInstanceID == "r-a")
        #expect(receipt.residualState == .unknown)
        #expect(!receipt.cleanupComplete)
    }

    @Test("unsupported or unknown response after dispatch retains recovery identity and unknown residue", arguments: ["unknown_request", "unsupported_capability"])
    func ambiguousApplyReply(code: String) async throws {
        let request = TKHighlightApplyRequest(operationID: "op-dispatched", spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(oid: 42))]))
        let data = try await executeHighlightApply(request) { type, _ in
            if type == "runtimeManifest" { return try highlightSupportedManifestData() }
            if type == "highlightCapabilities" {
                return try JSONEncoder().encode(TKHighlightCapabilitiesResponse(runtimeInstanceID: "r-a", capability: TKHighlightCapability(supported: true)))
            }
            return try JSONEncoder().encode(TKCLIErrorResponse(error: TKCLIErrorDetail(code: code, message: "No supported reply after dispatch")))
        }
        let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: data)
        #expect(!receipt.ok)
        #expect(receipt.operationID == "op-dispatched")
        #expect(receipt.runtimeInstanceID == "r-a")
        #expect(receipt.residualState == .unknown)
        #expect(!receipt.cleanupComplete)
        #expect(!receipt.restorationVerified)
    }

    @Test("typed apply error after dispatch retains generated recovery identity")
    func typedDispatchedError() async throws {
        let request = TKHighlightApplyRequest(operationID: "op-thrown", spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(oid: 42))]))
        let data = try await executeHighlightApply(request) { type, _ in
            if type == "runtimeManifest" { return try highlightSupportedManifestData() }
            if type == "highlightCapabilities" {
                return try JSONEncoder().encode(TKHighlightCapabilitiesResponse(runtimeInstanceID: "r-a", capability: TKHighlightCapability(supported: true)))
            }
            throw TKHighlightError(code: "highlight_unsupported", message: "Provider reply lost after dispatch")
        }
        let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: data)
        #expect(receipt.operationID == "op-thrown")
        #expect(receipt.runtimeInstanceID == "r-a")
        #expect(receipt.residualState == .unknown)
        #expect(receipt.error?.code == "highlight_unsupported")
    }

    @Test("valid typed apply receipt is preserved verbatim even with an unsupported error code")
    func typedReceiptPreserved() async throws {
        let receipt = TKHighlightReceipt(ok: false, runtimeInstanceID: "r-a", operationID: "op-typed", cleanupComplete: true, restorationVerified: false, residualState: .none, error: TKHighlightError(code: "unsupported_capability", message: "Provider verified zero writes"))
        let original = try JSONEncoder().encode(receipt)
        let request = TKHighlightApplyRequest(operationID: "op-typed", spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(oid: 42))]))
        let data = try await executeHighlightApply(request) { type, _ in
            if type == "runtimeManifest" { return try highlightSupportedManifestData() }
            if type == "highlightCapabilities" {
                return try JSONEncoder().encode(TKHighlightCapabilitiesResponse(runtimeInstanceID: "r-a", capability: TKHighlightCapability(supported: true)))
            }
            throw CLIHTTPError(statusCode: 409, data: original)
        }
        #expect(data == original)
    }

    @Test("non-2xx partial clear receipt is preserved, and failed restore is non-success")
    func partialClearReceipt() async throws {
        let receipt = TKHighlightReceipt(ok: false, runtimeInstanceID: "r-a", sessionID: "s-a", state: .needsAttention, marks: [TKHighlightMarkReceipt(markID: "a", outcome: .conflict)], cleanupComplete: false, restorationVerified: false, residualState: .possible, error: TKHighlightError(code: "highlight_restore_conflict", message: "Business modified the border"))
        let data = try JSONEncoder().encode(receipt)
        let output = try await executeHighlightRequest(type: "highlightClear", payload: JSONEncoder().encode(TKHighlightClearRequest(sessionID: "s-a"))) { type, _ in
            if type == "runtimeManifest" { return try highlightSupportedManifestData() }
            throw CLIHTTPError(statusCode: 409, data: data)
        }
        #expect(output == data)
        #expect(try !highlightResponseSucceeded(output))
        #expect(try JSONDecoder().decode(TKHighlightReceipt.self, from: output).marks.first?.outcome == .conflict)
    }

    @Test("clear remains available when new highlights are disabled")
    func disabledFeatureStillClears() async throws {
        let disabled = TKRuntimeManifestResponse(enabled: false, sdkVersion: "fixture", buildConfiguration: "debug", capabilities: [TKRuntimeCapabilityDetail(name: "highlight", supported: true, enabled: false, scope: "embedded", boundary: "app-process")])
        let receipt = TKHighlightReceipt(ok: true, runtimeInstanceID: "r-a", sessionID: "s-a", state: .closed, cleanupComplete: true, restorationVerified: true)
        let data = try await executeHighlightRequest(type: "highlightClear", payload: JSONEncoder().encode(TKHighlightClearRequest(sessionID: "s-a"))) { type, _ in
            if type == "runtimeManifest" { return try JSONEncoder().encode(disabled) }
            #expect(type == "highlightClear")
            return try JSONEncoder().encode(receipt)
        }
        #expect(try highlightResponseSucceeded(data))
    }

    @Test("status observing needs_attention is successful without claiming restoration")
    func statusStateIsSeparate() throws {
        let receipt = TKHighlightReceipt(ok: true, runtimeInstanceID: "r-a", sessionID: "s-a", state: .needsAttention, cleanupComplete: false, restorationVerified: false, residualState: .possible)
        #expect(try highlightResponseSucceeded(JSONEncoder().encode(receipt)))
    }

    @Test("spec file accepts regular and @ paths, retaining default style")
    func fileSpec() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("highlight-spec-\(UUID().uuidString).json")
        try Data(#"{"items":[{"markID":"a","selector":{"oid":42}}]}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try decodeHighlightSpec(url.path).color == "#FF453A")
        #expect(try decodeHighlightSpec("@" + url.path).width == 3)
    }
}

private final class HighlightFixtureURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [TKCLICommandRequest] = []
    static var commands: [TKCLICommandRequest] { lock.withLock { recorded } }
    static func reset() { lock.withLock { recorded = [] } }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.path == "/request" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        do {
            let body: Data
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var output = Data()
                var bytes = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    guard count > 0 else { break }
                    output.append(contentsOf: bytes.prefix(count))
                }
                body = output
            } else { body = request.httpBody ?? Data() }
            let command = try JSONDecoder().decode(TKCLICommandRequest.self, from: body)
            Self.lock.withLock { Self.recorded.append(command) }
            let data: Data
            if command.type == "runtimeManifest" {
                data = try highlightSupportedManifestData()
            } else if command.type == "highlightCapabilities" {
                data = try JSONEncoder().encode(TKHighlightCapabilitiesResponse(runtimeInstanceID: "r-a", capability: TKHighlightCapability(supported: true, provider: "fixture", presets: ["outline"])))
            } else if command.type == "highlightApply" {
                data = try JSONEncoder().encode(TKHighlightReceipt(ok: true, runtimeInstanceID: "r-a", operationID: "op-a", sessionID: "s-a", state: .active, marks: [TKHighlightMarkReceipt(markID: "a", targetOID: 42, outcome: .applied)]))
            } else { throw RuntimeError("Unexpected request: \(command.type)") }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
}
