import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct XcodeBoundedDiagnosticsTests {
    private let fatal = "fatal error: file '<generated-modulemap>' has been modified since the precompiled header '<precompiled-header>' was built"

    private func result(_ text: String, log: String? = nil, truncated: Bool = false, bytes: Int? = nil, exit: Int32 = 65) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(text.utf8), stderrData: Data(), exitCode: exit,
            sourceCommand: "xcodebuild build", stdoutTruncated: truncated, stderrTruncated: false,
            stdoutLogPath: log, stderrLogPath: nil, stdoutBytes: bytes ?? text.utf8.count, stderrBytes: 0)
    }

    @Test func fatalBeyondInlinePrefixIsIncludedInFinalDiagnostics() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("stdout.log")
        let prefix = String(repeating: "Compile fixture\n", count: 100_000)
        let log = prefix + fatal + "\n** BUILD FAILED **\n"
        try Data(log.utf8).write(to: path)
        let value = result(String(prefix.prefix(1_048_576)), log: path.path, truncated: true, bytes: log.utf8.count)
        let diagnostic = try #require(xcodeBuildOutputDiagnostics(value)?.first)
        #expect(diagnostic.kind == "compiler-fatal-error")
        #expect(diagnostic.samples.first?.message.contains("precompiled header") == true)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(diagnostic)) as? [String: Any])
        let coverage = try #require(object["coverage"] as? [String: Any])
        #expect(coverage["complete"] as? Bool == true)
        #expect((coverage["bytesScanned"] as? Int ?? 0) > 1_048_576)
        #expect(xcodeBuildFailureCode(ok: false, diagnostics: [diagnostic]) == "xcodebuild_failed")
    }

    @Test func failedBuildAlwaysExplainsUnavailableDiagnostics() throws {
        let diagnostics = try #require(xcodeBuildOutputDiagnostics(result("** BUILD FAILED **")))
        #expect(diagnostics.first?.kind == "diagnostics-unavailable")
        #expect(diagnostics.first?.message.contains("No supported diagnostic") == true)
        #expect(diagnostics.first?.samples.isEmpty == true)
        #expect(xcodeBuildOutputDiagnostics(result("Build succeeded", exit: 0)) == nil)
    }

    @Test func missingTruncatedArtifactDoesNotClaimCompleteCoverage() throws {
        let diagnostic = try #require(xcodeBuildOutputDiagnostics(result("prefix", log: "/nonexistent/sp259/stdout.log", truncated: true, bytes: 2_000_000))?.first)
        #expect(diagnostic.kind == "diagnostics-unavailable")
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(diagnostic)) as? [String: Any])
        let coverage = try #require(object["coverage"] as? [String: Any])
        #expect(coverage["complete"] as? Bool == false)
        #expect(coverage["truncated"] as? Bool == true)
    }

    @Test func diagnosticSamplesAndLinesAreBounded() throws {
        let log = (0..<30).map { "fatal error: fixture-\($0) " + String(repeating: "x", count: 10_000) }.joined(separator: "\n")
        let diagnostic = try #require(xcodeBuildOutputDiagnostics(result(log))?.first)
        #expect(diagnostic.samples.count <= 5)
        #expect(diagnostic.samples.allSatisfy { $0.message.utf8.count <= 8_192 })
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(diagnostic)) as? [String: Any])
        let coverage = try #require(object["coverage"] as? [String: Any])
        #expect(coverage["truncated"] as? Bool == true)
        #expect(diagnostic.matchCount == 30)
    }

    @Test func scanLimitPreservesPrefixAndReportsPartialCoverage() throws {
        let log = "fatal error: first diagnostic\n" + String(repeating: "ordinary\n", count: 100) + "fatal error: beyond budget\n"
        let diagnostic = try #require(xcodeBoundedBuildOutputDiagnostics(result(log), maximumBytesPerStream: 128)?.first)
        #expect(diagnostic.kind == "compiler-fatal-error")
        #expect(diagnostic.samples.first?.message == "fatal error: first diagnostic")
        #expect(diagnostic.matchCount == 1)
        #expect(diagnostic.coverage?.bytesScanned == 128)
        #expect(diagnostic.coverage?.observedBytes == log.utf8.count)
        #expect(diagnostic.coverage?.complete == false)
        #expect(diagnostic.coverage?.truncated == true)
    }

    @Test func crossChunkUTF8LineAndUnterminatedTailSurvive() throws {
        let prefix = String(repeating: " ", count: 65_521) + "\n"
        let message = "fatal error: 模块 'fixture' rejected"
        let diagnostic = try #require(xcodeBuildOutputDiagnostics(result(prefix + message))?.first)
        #expect(diagnostic.kind == "compiler-fatal-error")
        #expect(diagnostic.samples.first?.message == message)
        // Oversized routine lines are conservatively marked partial too.
        #expect(diagnostic.coverage?.linesTruncated == true)
    }

    @Test func clippedSecretIsNeverPublished() throws {
        let secret = "PRIVATE_TOKEN_VALUE"
        let command = TKHostCommand(arguments: [secret], redactedArgumentIndexes: [0])
        let prefix = "fatal error: " + String(repeating: "x", count: 8_192 - 13 - 8)
        let diagnostic = try #require(xcodeBuildOutputDiagnostics(result(prefix + secret), redacting: command)?.first)
        let json = String(decoding: try JSONEncoder().encode(diagnostic), as: UTF8.self)
        #expect(!json.contains("PRIVATE"))
        #expect(diagnostic.coverage?.linesTruncated == true)
        #expect(diagnostic.samples.first?.path == "<truncated>")
    }

    @Test func supportedSpecializedDiagnosticAndFatalBothRemainVisible() throws {
        let log = "Stale file '/tmp/repo/.triton/DerivedData/Build/old.o' is located outside of the allowed root paths.\n" + fatal
        let diagnostics = try #require(xcodeBuildOutputDiagnostics(result(log)))
        #expect(Set(diagnostics.map(\.kind)) == ["compiler-fatal-error", "stale-derived-data-outside-root"])
        #expect(diagnostics.allSatisfy { $0.coverage?.complete == true })
    }

    @Test func missingCoverageRemainsBackwardDecodable() throws {
        let json = #"{"kind":"old","message":"old","matchCount":0,"samples":[],"recovery":"old","nextAction":{"command":"schema","args":[]}}"#
        let diagnostic = try JSONDecoder().decode(TKXcodeOutputDiagnostic.self, from: Data(json.utf8))
        #expect(diagnostic.coverage == nil)
    }

    @Test func multilineSensitiveArgumentNeverLeaksInEncodedDiagnosticBytes() throws {
        let secret = "PRIVATE_FIRST\nPRIVATE_SECOND"
        let command = TKHostCommand(arguments: [secret], redactedArgumentIndexes: [0])
        let diagnostic = try #require(xcodeBuildOutputDiagnostics(result("fatal error: " + secret + "\n"), redacting: command)?.first)
        let bytes = try JSONEncoder().encode(diagnostic)
        #expect(bytes.range(of: Data("PRIVATE_FIRST".utf8)) == nil)
        #expect(bytes.range(of: Data("PRIVATE_SECOND".utf8)) == nil)
    }

    @Test func carriageReturnDiagnosticsPreserveSamplesAndTruncation() throws {
        for separator in ["\r", "\r\n"] {
            let log = (1...6).map { "fatal error: fixture-\($0)" }.joined(separator: separator)
            let diagnostic = try #require(xcodeBuildOutputDiagnostics(result(log))?.first)
            #expect(diagnostic.matchCount == 6)
            #expect(diagnostic.samples.count == 5)
            #expect(diagnostic.coverage?.samplesTruncated == true)
        }
    }

    @Test func artifactMutationOrReplacementCannotClaimCompleteCoverage() throws {
        for replace in [false, true] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let path = directory.appendingPathComponent("stdout.log")
            let original = Data("fatal error: original\n".utf8)
            let changed = Data("fatal error: modified\n".utf8)
            #expect(original.count == changed.count)
            try original.write(to: path)
            var mutations = 0
            let diagnostic = try #require(xcodeBoundedBuildOutputDiagnostics(
                result("prefix", log: path.path, truncated: true, bytes: original.count),
                artifactReadObserver: { _ in
                    guard mutations == 0 else { return }
                    mutations += 1
                    if replace {
                        try? changed.write(to: path, options: .atomic)
                    } else {
                        if let handle = try? FileHandle(forWritingTo: path) {
                            try? handle.write(contentsOf: changed)
                            try? handle.close()
                        }
                        try? FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 42)], ofItemAtPath: path.path)
                    }
                }
            )?.first)
            #expect(mutations == 1)
            #expect(try Data(contentsOf: path) == changed)
            #expect(diagnostic.coverage?.complete == false)
            #expect(diagnostic.coverage?.unavailableStreams == ["stdout"])
        }
    }
}
