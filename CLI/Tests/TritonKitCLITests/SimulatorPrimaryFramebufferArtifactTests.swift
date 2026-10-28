import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct SimulatorPrimaryFramebufferArtifactTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    let display = "11111111-2222-3333-4444-555555555555"
    let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lz6ERwAAAABJRU5ErkJggg==")!
    func result(_ command: TKHostCommand, exit: Int32 = 0) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: exit, sourceCommand: hostSourceCommand(command), stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
    }
    func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("triton-primary-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
    @Test func validatesNewPNGAndPublishesPrivatelyWithoutOverwriting() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("capture.png")
        var staging: String?
        let captured = try captureIOSSimulatorPrimaryFramebuffer(simulator: target, outputPath: output.path,
            resizeProbe: { _, _ in .unknown(.unsupportedDevice) }, displayProbe: { _, _ in .display(display) }, runner: { command in
                staging = command.arguments.last
                #expect(command.arguments.contains("--display=" + display))
                #expect(command.arguments.contains("--type=png"))
                try png.write(to: URL(fileURLWithPath: command.arguments.last!))
                return result(command)
            })
        #expect(captured.width == 1 && captured.height == 1)
        #expect(captured.evidence.resizeState == "unknown" && !captured.evidence.resizeVerified)
        #expect(try Data(contentsOf: output) == png)
        let attrs = try FileManager.default.attributesOfItem(atPath: output.path)
        #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(!FileManager.default.fileExists(atPath: try #require(staging)))
        var calls = 0
        #expect(throws: (any Error).self) {
            _ = try captureIOSSimulatorPrimaryFramebuffer(simulator: target, outputPath: output.path,
                resizeProbe: { _, _ in calls += 1; return .inactive }, runner: { command in calls += 1; return result(command) })
        }
        #expect(calls == 0)
        #expect(try Data(contentsOf: output) == png)
    }
    @Test func missingMalformedAndSymlinkStagingNeverPublish() throws {
        for mode in ["missing", "invalid", "symlink", "truncated", "nonzero"] {
            let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
            let output = root.appendingPathComponent("capture.png")
            let source = root.appendingPathComponent("source.png"); try png.write(to: source)
            #expect(throws: (any Error).self) {
                _ = try captureIOSSimulatorPrimaryFramebuffer(simulator: target, outputPath: output.path,
                    resizeProbe: { _, _ in .inactive }, displayProbe: { _, _ in .display(display) }, runner: { command in
                        let path = command.arguments.last!
                        if mode == "invalid" { try Data("not PNG".utf8).write(to: URL(fileURLWithPath: path)) }
                        if mode == "symlink" { try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: source.path) }
                        if mode == "truncated" { try Data(png.prefix(40)).write(to: URL(fileURLWithPath: path)) }
                        if mode == "nonzero" { try png.write(to: URL(fileURLWithPath: path)) }
                        return result(command, exit: mode == "nonzero" ? 1 : 0)
                    })
            }
            #expect(!FileManager.default.fileExists(atPath: output.path))
        }
    }
    @Test func competingOutputAndDanglingSymlinkAreNeverReplaced() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("capture.png")
        let marker = Data("other writer".utf8)
        #expect(throws: (any Error).self) {
            _ = try captureIOSSimulatorPrimaryFramebuffer(simulator: target, outputPath: output.path,
                resizeProbe: { _, _ in .inactive }, displayProbe: { _, _ in .display(display) }, runner: { command in
                    try png.write(to: URL(fileURLWithPath: command.arguments.last!))
                    try marker.write(to: output)
                    return result(command)
                })
        }
        #expect(try Data(contentsOf: output) == marker)
        let link = root.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: root.appendingPathComponent("missing").path)
        var calls = 0
        #expect(throws: (any Error).self) {
            _ = try captureIOSSimulatorPrimaryFramebuffer(simulator: target, outputPath: link.path,
                resizeProbe: { _, _ in calls += 1; return .inactive })
        }
        #expect(calls == 0)
    }
}
