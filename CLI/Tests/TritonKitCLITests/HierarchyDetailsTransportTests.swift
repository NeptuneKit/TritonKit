import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKit
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized) struct HierarchyDetailsTransportTests {
    @Test func optionsProduceTypedBoundedRequest() throws {
        let command = try HierarchyDetails.parse(["--device", "fixture", "--id", "12", "--oid", "13", "--screenshots", "group", "--no-include-attributes", "--max-pixel-count", "2048", "--lang", "en"])
        let request = try command.makeRequest()
        #expect(command.target == "fixture")
        #expect(request.oids == [12, 13])
        #expect(request.screenshots == .group)
        #expect(!request.includeAttributes)
        #expect(request.maxPixelCount == 2048)
        let defaults = try HierarchyDetails.parse(["--oid", "1"]).makeRequest()
        #expect(defaults.screenshots == .both)
        #expect(defaults.includeAttributes)
        #expect(defaults.maxPixelCount == 262_144)
    }

    @Test func invalidOptionsNeverReachTransport() {
        for arguments in [[], ["--oid", "0"], ["--oid", "1", "--oid", "1"],
                          ["--oid", "1", "--screenshots", "crop"], ["--oid", "1", "--max-pixel-count", "0"],
                          ["--oid", "1", "--max-pixel-count", "1048577"], ["--oid", "1", "--port", "0"],
                          ["--oid", "1", "--host", ""], (1...9).flatMap { ["--oid", String($0)] }] {
            #expect(throws: (any Error).self) { _ = try HierarchyDetails.parse(arguments) }
        }
    }

    @Test func compactSchemaCarriesTypedOptionsAndFailureContract() throws {
        let compact = try buildCompactSchemaResponse(command: "debug.details")
        #expect(compact.command == "debug.details")
        #expect(compact.sideEffect == "temporary_layer_visibility_for_capture")
        #expect(compact.options.first { $0.name.contains("--oid") }?.required == true)
        #expect(compact.options.first { $0.name == "--screenshots" }?.defaultValue == "both")
        #expect(compact.options.first { $0.name == "--max-pixel-count" }?.defaultValue == "262144")
        #expect(compact.failureCodes.contains("details_partial"))
        #expect(compact.outputContracts.contains { $0.selector == "hierarchy.details" })
    }

    @Test func selectedTargetAndPayloadReachHTTP() async throws {
        let expected = TKHierarchyDetailsRequest(oids: [31, 32], screenshots: .none, includeAttributes: false, maxPixelCount: 64)
        DetailsURLProtocol.reset(response: Data(#"{"ok":false,"partial":false,"details":[],"error":{"code":"runtime_disabled","message":"disabled"}}"#.utf8))
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DetailsURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let client = TritonKitHTTPClient(host: "fixture.invalid", port: 19421, target: "fixture-target", session: session)
        let response = try await requestHierarchyDetails(expected, client: client)
        #expect(!response.isEmpty)
        let recorded = try #require(DetailsURLProtocol.recordedRequest)
        #expect(recorded.type == "hierarchyDetails")
        #expect(recorded.target == "fixture-target")
        let payload = try #require(recorded.payload)
        #expect(try JSONDecoder().decode(TKHierarchyDetailsRequest.self, from: payload) == expected)
        #expect(DetailsURLProtocol.path == "/request")
    }

    @Test func successfulDetailsAndPartialFailureEachEmitOneEnvelope() throws {
        let succeeded = TKDisplayItemDetail(displayItemOid: 7, soloScreenshot: Data([1, 2, 3]))
        let success = TKHierarchyDetailsResponse(ok: true, details: [succeeded])
        let successfulOutput = try captureDetailsOutput { try emitHierarchyDetails(JSONEncoder().encode(success), requestedOIDs: [7], outputFormat: .json) }
        #expect(successfulOutput.error == nil)
        let successJSON = try #require(JSONSerialization.jsonObject(with: successfulOutput.data) as? [String: Any])
        #expect(successJSON["ok"] as? Bool == true)
        let failed = TKDisplayItemDetail(displayItemOid: 8, failureCode: 1, failureReason: "object_not_found")
        let partial = TKHierarchyDetailsResponse(ok: false, partial: true, details: [succeeded, failed], error: .init(code: "details_partial", message: "One object disappeared"))
        let failedOutput = try captureDetailsOutput { try emitHierarchyDetails(JSONEncoder().encode(partial), requestedOIDs: [7, 8], outputFormat: .json) }
        #expect((failedOutput.error as? ExitCode) == .failure)
        let partialJSON = try #require(JSONSerialization.jsonObject(with: failedOutput.data) as? [String: Any])
        #expect(partialJSON["partial"] as? Bool == true)
        #expect((partialJSON["details"] as? [Any])?.count == 2)
    }

    @Test func capabilityFailureRetainsOriginalErrorEnvelope() throws {
        let data = try JSONEncoder().encode(TKCLIErrorResponse(error: .init(code: "capability_disabled", message: "Runtime disabled", hint: "Use Debug")))
        let output = try captureDetailsOutput { try emitHierarchyDetails(data, requestedOIDs: [7], outputFormat: .json) }
        #expect((output.error as? ExitCode) == .failure)
        let failure = try JSONDecoder().decode(TKCLIErrorResponse.self, from: output.data)
        #expect(failure.error.code == "capability_disabled")
        #expect(failure.error.hint == "Use Debug")
    }

    @Test func malformedAndContradictorySuccessDoNotPrintSuccess() throws {
        let missing = TKHierarchyDetailsResponse(ok: true, details: [])
        let wrongOID = TKHierarchyDetailsResponse(ok: true, details: [.init(displayItemOid: 8)])
        for data in [Data([0xff, 0x00]), Data("[]".utf8), Data(#"{"ok":true}"#.utf8), try JSONEncoder().encode(missing), try JSONEncoder().encode(wrongOID)] {
            let output = try captureDetailsOutput {
                do { try emitHierarchyDetails(data, requestedOIDs: [7], outputFormat: .json) }
                catch {
                    if error is ExitCode { throw error }
                    try failCommand(error, outputFormat: .json, endpoint: "/request", host: "fixture.invalid", port: 19421)
                }
            }
            #expect((output.error as? ExitCode) == .failure)
            let failure = try JSONDecoder().decode(TKCLIErrorResponse.self, from: output.data)
            #expect(!failure.ok)
            #expect(failure.error.code == "request_failed")
        }
    }
}

private func captureDetailsOutput(_ operation: () throws -> Void) throws -> (data: Data, error: Error?) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("triton-details-\(UUID().uuidString).stdout")
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw RuntimeError("Unable to create test output") }
    defer { try? FileManager.default.removeItem(at: url) }
    let file = try FileHandle(forWritingTo: url)
    defer { try? file.close() }
    fflush(stdout)
    let saved = dup(STDOUT_FILENO)
    guard saved >= 0 else { throw RuntimeError("Unable to duplicate stdout") }
    defer { close(saved) }
    guard dup2(file.fileDescriptor, STDOUT_FILENO) >= 0 else { throw RuntimeError("Unable to redirect stdout") }
    let caught: Error?
    do { try operation(); caught = nil } catch { caught = error }
    fflush(stdout)
    dup2(saved, STDOUT_FILENO)
    return (try Data(contentsOf: url), caught)
}

private final class DetailsURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var response = Data()
    private static var recorded: TKCLICommandRequest?
    private static var requestPath: String?
    static var recordedRequest: TKCLICommandRequest? { lock.withLock { recorded } }
    static var path: String? { lock.withLock { requestPath } }
    static func reset(response: Data) { lock.withLock { self.response = response; recorded = nil; requestPath = nil } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readBody) ?? Data()
        let response = Self.lock.withLock { () -> Data in
            Self.recorded = try? JSONDecoder().decode(TKCLICommandRequest.self, from: body)
            Self.requestPath = request.url?.path
            return Self.response
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    private static func readBody(_ stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
