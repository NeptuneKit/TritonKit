import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Network capture integrity")
struct NetworkCaptureIntegrityTests {
    @Test("malformed, empty, partial, unknown, and oversized captures fail before export")
    func rejectsIncompleteCaptures() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.ndjson")
        #expect(throws: (any Error).self) { try readValidatedNetworkCapture(sourceURL: root) }
        let output = root.appendingPathComponent("result.har")
        let valid = try captureLine()
        try Data("preserved".utf8).write(to: output)
        try Data("broken\n".utf8).write(to: source)
        #expect(throws: (any Error).self) { try exportNetworkProxyCaptureArtifact(sourceURL: source, outputURL: output) }
        #expect(try String(contentsOf: output, encoding: .utf8) == "preserved")
        try FileManager.default.removeItem(at: output)
        for data in [Data(), Data([0xff, 0x0a]), Data("{bad}\n".utf8), Data(valid.dropLast().utf8), Data("{\"schemaVersion\":\"future\"}\n".utf8)] {
            try data.write(to: source)
            #expect(throws: (any Error).self) { try exportNetworkProxyCaptureArtifact(sourceURL: source, outputURL: output) }
            #expect(!FileManager.default.fileExists(atPath: output.path))
            #expect(throws: (any Error).self) { try summarizeNetworkProxyCaptureArtifact(sourceURL: source) }
        }
        try Data(valid.utf8).write(to: source)
        #expect(throws: (any Error).self) { try readValidatedNetworkCapture(sourceURL: source, maximumBytes: 8) }
        #expect(throws: (any Error).self) { try readValidatedNetworkCapture(sourceURL: source, maximumLineBytes: 8) }
        let failed = try JSONDecoder().decode(NetworkProxyServeEvent.self, from: Data(valid.utf8))
        var payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(failed)) as! [String: Any]
        payload["schemaVersion"] = "triton.proxy.capture.future"
        let unknown = try JSONSerialization.data(withJSONObject: payload) + Data("\n".utf8)
        try unknown.write(to: source)
        #expect(throws: (any Error).self) { try summarizeNetworkProxyCaptureArtifact(sourceURL: source) }
        let link = root.appendingPathComponent("link.ndjson")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        #expect(throws: (any Error).self) { try readValidatedNetworkCapture(sourceURL: link) }
        try Data((valid + valid).utf8).write(to: source)
        #expect(throws: (any Error).self) { try readValidatedNetworkCapture(sourceURL: source, maximumRecords: 1) }
    }

    @Test("old capture exports strip query and credentials consistently from NDJSON and HAR")
    func redactsOldCaptureOnExport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.ndjson")
        try Data(try captureLine().utf8).write(to: source)
        let summary = try summarizeNetworkProxyCaptureArtifact(sourceURL: source)
        #expect(summary.requestCount == 1)
        #expect(summary.eventCount == 1)
        #expect(summary.redaction.contains("url-credentials-query-removed"))
        for ext in ["har", "ndjson"] {
            let output = root.appendingPathComponent("out.\(ext)")
            _ = try exportNetworkProxyCaptureArtifact(sourceURL: source, outputURL: output)
            let text = try String(contentsOf: output, encoding: .utf8)
            #expect(!text.contains("secret"))
            #expect(!text.contains("token="))
            #expect(!text.contains("private-user"))
            if ext == "har" {
                let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
                let log = object?["log"] as? [String: Any]
                let integrity = log?["_triton"] as? [String: Any]
                #expect(integrity?["requestCount"] as? Int == summary.requestCount)
                #expect(integrity?["truncation"] as? String == summary.truncation)
                #expect((log?["entries"] as? [Any])?.count == summary.requestCount)
            }
        }
    }

    @Test("capture writer strips URL secrets and refuses capacity overflow without modifying capture")
    func writerIsBoundedAndRedacted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("capture.ndjson")
        let raw = try JSONDecoder().decode(NetworkProxyServeEvent.self, from: Data(try captureLine().utf8))
        #expect(raw.url?.contains("token=secret") == true)
        try appendNetworkProxyCaptureEvent(raw, captureURL: source)
        let before = try Data(contentsOf: source)
        let text = String(decoding: before, as: UTF8.self)
        #expect(!text.contains("secret"))
        #expect(!text.contains("private-user"))
        #expect(throws: (any Error).self) { try appendNetworkProxyCaptureEvent(raw, captureURL: source, maximumBytes: before.count) }
        #expect(try Data(contentsOf: source) == before)
        #expect(throws: (any Error).self) { try summarizeNetworkProxyCaptureArtifact(sourceURL: source) }
    }

    @Test("valid zero-observation placeholder does not invent observed requests")
    func placeholderIsExplicitlyNotObserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.ndjson")
        let payload = #"{"schemaVersion":"triton.network.v1","platform":"ios","target":"fixture","requestCount":0,"eventCount":0,"failureCount":0,"redaction":"default","visibility":"partial","events":[]}"# + "\n"
        try Data(payload.utf8).write(to: source)
        let summary = try summarizeNetworkProxyCaptureArtifact(sourceURL: source)
        #expect(summary.requestCount == 0)
        #expect(summary.truncation == "not-observed")
    }

    private func captureLine() throws -> String {
        let request = Data("GET http://private-user:secret@example.test/path?token=secret#secret HTTP/1.1\r\nHost: example.test\r\nAuthorization: secret\r\n\r\n".utf8)
        let event = try parseNetworkProxyHTTPHeader(request, listen: "127.0.0.1:19431", capturePath: "fixture", connectionIndex: 1)
        return try encodeCompactJSON(event) + "\n"
    }
}
