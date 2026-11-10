import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct WebViewSnapshotTransportTests {
    @Test func directRuntimeFailureKeepsRequestEndpointAndPlatform() async throws {
        let socket = try UnavailableRuntimeSocket()
        defer { socket.close() }
        for platform: ObservationPlatform in [.harmony, .ios] {
            let output = try await capture {
                try await snapshot(platform: platform, runtimeBaseURL: socket.url + "/ignored/base?ignored=1")
            }
            #expect(output.failure is ExitCode)
            let response = try #require(JSONSerialization.jsonObject(with: Data(output.text.utf8)) as? [String: Any])
            let error = try #require(response["error"] as? [String: Any])
            #expect(response["action"] as? String == "webview.snapshot")
            #expect(response["platform"] as? String == platform.rawValue)
            #expect(response["target"] as? String == "__isolated_fixture__")
            #expect(error["code"] as? String == "server_unavailable")
            #expect(error["endpoint"] as? String == socket.url + "/v2/runtime/webview/snapshot")
            #expect(error["nextAction"] == nil)
            #expect((error["hint"] as? String)?.contains("--runtime-base-url") == true)
            #expect((error["hint"] as? String)?.contains("connect the iOS app") == false)
        }
    }

    @Test func endpointURLPreservesAbsoluteHTTPURLAndRelativeServerRoutes() {
        let absolute = "https://127.0.0.1:41234/v2/runtime/webview/snapshot"
        #expect(endpointURL(absolute, host: "server.invalid", port: 19421) == absolute)
        #expect(endpointURL("/request", host: "127.0.0.1", port: 19421) == "http://127.0.0.1:19421/request")
        #expect(endpointURL("request", host: "127.0.0.1", port: 19421) == "http://127.0.0.1:19421/request")
    }

    @Test func defaultServerTransportRecoveryRemainsUnchanged() {
        let detail = cliErrorDetail(for: URLError(.cannotConnectToHost), endpoint: "/request", host: "127.0.0.1", port: 19422)
        #expect(detail.endpoint == "http://127.0.0.1:19422/request")
        #expect(detail.code == "server_unavailable")
        #expect(detail.nextAction?.command == "serve")
        #expect(detail.nextAction?.args == ["--host", "127.0.0.1", "--port", "19422"])
    }

    @Test func missingHarmonyRuntimeURLRemainsAnExplicitRequirement() async throws {
        let output = try await capture { try await snapshot(platform: .harmony, runtimeBaseURL: nil) }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.text.utf8))
        #expect(output.failure is ExitCode)
        #expect(response.error.message.contains("requires --runtime-base-url"))
        #expect(response.error.endpoint == nil)
        #expect(response.error.nextAction?.command != "serve")
    }

    @Test func nonSuccessHTTPPreservesCompleteProviderEnvelope() throws {
        let provider = TKWebViewErrorResponse(
            action: "webview.snapshot", platform: "harmony", target: "provider-target",
            error: TKCLIErrorDetail(code: "webview_provider_unavailable", message: "No provider", hint: "Provider-specific recovery"),
            candidates: [], outcome: "not_started",
            uiHealth: TKRuntimeUIHealthSnapshot(state: .busy, allowsUIRequests: false, inflight: nil, consecutiveTimeouts: 0, failureThreshold: 3, timeoutMilliseconds: 500, lastCompletion: nil)
        )
        let data = try JSONEncoder().encode(provider)
        let response = webViewSnapshotRuntimeErrorResponse(CLIHTTPError(statusCode: 503, data: data), platform: .harmony, target: "request-target", runtimeBaseURL: "http://127.0.0.1:41234")
        #expect(response == provider)
        if case .error(let decoded) = try decodeWebViewSnapshotRuntimeResult(data) { #expect(decoded == provider) }
        else { Issue.record("Expected reachable provider error") }
    }

    @Test func directRuntimeNonTransportFailuresRetainTheirClassification() throws {
        let endpoint = "http://127.0.0.1:41234/v2/runtime/webview/snapshot"
        let errors: [Error] = [RuntimeError("Invalid provider response"), CLIHTTPError(statusCode: 502, data: Data("invalid gateway".utf8)), CancellationError(), URLError(.cancelled)]
        for error in errors {
            let response = webViewSnapshotRuntimeErrorResponse(error, platform: .harmony, target: "fixture", runtimeBaseURL: "http://127.0.0.1:41234")
            #expect(response.error.code == "request_failed")
            #expect(response.error.endpoint == endpoint)
            #expect(response.error.nextAction == nil)
        }
        let detail = TKCLIErrorDetail(code: "runtime_ui_busy", message: "Busy", hint: "Wait for completion")
        let encoded = try JSONEncoder().encode(TKCLIErrorResponse(error: detail))
        let structured = webViewSnapshotRuntimeErrorResponse(CLIHTTPError(statusCode: 503, data: encoded), platform: .harmony, target: "fixture", runtimeBaseURL: "http://127.0.0.1:41234")
        #expect(structured.error == detail)
    }

    @Test func directRuntimeRouteResolutionMatchesExistingAbsolutePathSemantics() throws {
        let client = try EmbeddedRuntimeHTTPClient(baseURL: "https://127.0.0.1:41234/base?ignored=1#ignored")
        #expect(try client.requestURL(.webViewSnapshot).absoluteString == "https://127.0.0.1:41234/v2/runtime/webview/snapshot")
        #expect(try client.requestURL(.webViewSnapshot, queryItems: [URLQueryItem(name: "key", value: "a b")]).absoluteString == "https://127.0.0.1:41234/v2/runtime/webview/snapshot?key=a%20b")
        #expect(throws: RuntimeError.self) { try EmbeddedRuntimeHTTPClient(baseURL: "not a URL") }
    }

    @Test func invalidDirectRuntimeURLDoesNotSuggestServerStartup() async throws {
        let output = try await capture { try await snapshot(platform: .harmony, runtimeBaseURL: "not a URL") }
        #expect(output.failure is ExitCode)
        let response = try JSONDecoder().decode(TKWebViewErrorResponse.self, from: Data(output.text.utf8))
        #expect(response.error.code == "request_failed")
        #expect(response.error.message.contains("Invalid embedded runtime base URL"))
        #expect(response.error.endpoint == "not a URL")
        #expect(response.platform == "harmony")
        #expect(response.error.nextAction == nil)
    }

    @Test func textDirectRuntimeErrorAvoidsServerOnlyLocalization() async throws {
        let socket = try UnavailableRuntimeSocket()
        defer { socket.close() }
        let output = try await capture(stream: STDERR_FILENO) {
            try await snapshot(platform: .harmony, runtimeBaseURL: socket.url, format: .text)
        }
        #expect(output.failure is ExitCode)
        #expect(output.text.contains("harmony"))
        #expect(output.text.contains("--runtime-base-url"))
        #expect(output.text.contains(socket.url + "/v2/runtime/webview/snapshot"))
        #expect(!output.text.contains("iOS"))
        #expect(!output.text.contains("triton serve"))
    }

    @Test func androidRemainsUnsupportedBeforeAnyRuntimeRequest() async throws {
        let output = try await capture { try await snapshot(platform: .android, runtimeBaseURL: "not a URL") }
        #expect(output.failure is ExitCode)
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.text.utf8))
        #expect(response.error.code == "unsupported_capability")
    }

    private func snapshot(platform: ObservationPlatform, runtimeBaseURL: String?, format: ClientOutputFormat = .json) async throws {
        try await runWebViewSnapshot(platform: platform, target: "__isolated_fixture__", host: "127.0.0.1", port: 41001, runtimeBaseURL: runtimeBaseURL, webViewID: nil, pageSessionID: nil, include: "metadata,text", maxDOMNodes: nil, maxTextBytes: nil, format: format, json: format == .json)
    }

    private func capture(stream: Int32 = STDOUT_FILENO, _ operation: () async throws -> Void) async throws -> (text: String, failure: Error?) {
        let pipe = Pipe()
        let original = dup(stream)
        fflush(nil)
        dup2(pipe.fileHandleForWriting.fileDescriptor, stream)
        var failure: Error?
        do { try await operation() } catch { failure = error }
        fflush(nil)
        dup2(original, stream)
        Darwin.close(original)
        try pipe.fileHandleForWriting.close()
        return (String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), failure)
    }
}

private final class UnavailableRuntimeSocket {
    private let descriptor: Int32
    let url: String

    init() throws {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw RuntimeError("Unable to create isolated socket") }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard result == 0 else { Darwin.close(descriptor); throw RuntimeError("Unable to bind isolated socket") }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        guard named == 0 else { Darwin.close(descriptor); throw RuntimeError("Unable to inspect isolated socket") }
        self.descriptor = descriptor
        url = "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))"
    }

    func close() { Darwin.close(descriptor) }
}
