import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct HarmonyWaitFailureTests {
    private func fixture(fails: Bool = false) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sp263-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let tool = root.appendingPathComponent("hdc")
        let source = """
        #!/bin/sh
        printf '%s\\n' "$*" >> '\(root.path)/calls'
        \(fails ? "echo 'synthetic host transport failure' >&2; exit 7" : "")
        case "$*" in
            'list targets'*) printf 'fake-one TCP Connected localhost\\n' ;;
            *'dumpLayout'*) printf 'DumpLayout saved to: /data/local/tmp/sp263.json\\n' ;;
            *'file recv'*)
                for path in "$@"; do :; done
                printf '%s' '{"attributes":{"text":"Other","bounds":"[0,0][100,50]"}}' > "$path"
                printf 'File recv finish\\n'
                ;;
            *) exit 9 ;;
        esac
        """
        try source.write(to: tool, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tool.path)
        return root
    }

    private func capture(_ operation: () async throws -> Void) async throws -> (String, Error?) {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        var failure: Error?
        do { try await operation() } catch { failure = error }
        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        try pipe.fileHandleForWriting.close()
        return (String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), failure)
    }

    @Test func missingTargetMatchesObserveAndOffersTargetedDiscovery() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let hdc = root.appendingPathComponent("hdc").path
        for flag in ["--target", "--device"] {
            let wait = try Wait.parse(["--platform", "harmony", flag, "__missing__", "--text", "Ready", "--hdc", hdc, "--json"])
            let output = try await capture { try await wait.run() }
            #expect(output.1 is ExitCode)
            let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
            #expect(response.error.code == "target_not_found")
            #expect(response.error.endpoint == nil)
            #expect(response.error.nextAction?.command == "device")
            #expect(response.error.nextAction?.args == ["list", "--platform", "harmony", "--hdc", hdc, "--json"])
            let observe = try ObserveTree.parse(["--platform", "harmony", "--device", "__missing__", "--hdc", hdc, "--json"])
            let observed = try await capture { try await observe.run() }
            let observedError = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(observed.0.utf8))
            #expect(observedError.error.code == response.error.code)
        }
    }

    @Test func missingExecutableHasConfigurationRecovery() async throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("sp263-missing-\(UUID().uuidString)/hdc").path
        for executable in [missing, "sp263-missing-\(UUID().uuidString)"] {
            let command = try Wait.parse(["--platform", "harmony", "--target", "__missing__", "--text", "Ready", "--hdc", executable, "--json"])
            let output = try await capture { try await command.run() }
            let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
            #expect(output.1 is ExitCode)
            #expect(response.error.code == "harmony_hdc_not_found")
            #expect(response.error.endpoint == nil)
            #expect(response.error.hint?.contains("--hdc") == true)
            #expect(response.error.nextAction?.args.contains(executable) == true)
            #expect(response.error.nextAction?.command != "serve")
        }
    }

    @Test func hostTransportFailureHasNoRuntimeEndpoint() async throws {
        let root = try fixture(fails: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try Wait.parse(["--platform", "harmony", "--target", "fake-one", "--text", "Ready", "--hdc", root.appendingPathComponent("hdc").path, "--json"])
        let output = try await capture { try await command.run() }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(response.error.code == "host_action_failed")
        #expect(response.error.endpoint == nil)
        #expect(response.error.message.contains("synthetic host transport failure"))
    }

    @Test func idleRejectsBeforeInvokingBackend() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try Wait.parse(["--platform", "harmony", "--target", "fake-one", "--idle", "--hdc", root.appendingPathComponent("hdc").path, "--json"])
        let output = try await capture { try await command.run() }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(response.error.code == "unsupported_capability")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("calls").path))
    }

    @Test func conditionTimeoutIsNotAHostOrServerError() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try Wait.parse(["--platform", "harmony", "--target", "fake-one", "--text", "Absent", "--timeout", "2", "--interval", "0.01", "--hdc", root.appendingPathComponent("hdc").path, "--json"])
        let output = try await capture { try await command.run() }
        let json = try #require(JSONSerialization.jsonObject(with: Data(output.0.utf8)) as? [String: Any])
        #expect(json["timedOut"] as? Bool == true)
        #expect(json["matched"] as? Bool == false)
        #expect(json["error"] == nil)
        #expect(output.1 is ExitCode)
    }

    @Test func runtimeTransportErrorStillHasRuntimeRecovery() async throws {
        let command = try Wait.parse(["--text", "Ready", "--host", "127.0.0.1", "--port", "1", "--json"])
        let output = try await capture { try await command.run() }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(response.error.code == "server_unavailable")
        #expect(response.error.endpoint != nil)
        #expect(response.error.nextAction?.command == "serve")
    }
    @Test func remoteExit127DoesNotMeanMissingHostExecutable() {
        let command = TKHarmonyHDCCommand.dumpLayout(target: "fake-one", executable: "hdc")
        let message = "uitest: not found"
        let result = HostProcessResult(stdoutData: Data(), stderrData: Data(message.utf8), exitCode: 127, sourceCommand: "hdc shell uitest", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: message.utf8.count)
        #expect(harmonyWaitFailureDetail(HostCommandRunError.nonZeroExit(command: command, result: result), hdc: "hdc") == nil)
    }

    @Test func structuredServerErrorIsPreservedEvenOnHarmonyBoundary() async throws {
        let detail = TKCLIErrorDetail(code: "runtime_unavailable", message: "Unavailable", endpoint: "/runtime", hint: "Original recovery")
        let encoded = try JSONEncoder().encode(TKCLIErrorResponse(error: detail))
        let output = try await capture {
            try failWaitCommand(CLIHTTPError(statusCode: 503, data: encoded), platform: .harmony, hdc: "hdc", outputFormat: .json, host: "127.0.0.1", port: 19421)
        }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(response.error == detail)
    }

    @Test func discoveryTimeoutRemainsHostTyped() async throws {
        let error = HostCommandRunError.timeout(command: TKHarmonyHDCCommand.listTargets(), timeoutSeconds: 3, stdoutLogPath: nil, stderrLogPath: nil)
        let output = try await capture {
            try failWaitCommand(error, platform: .harmony, hdc: "hdc", outputFormat: .json, host: "127.0.0.1", port: 19421)
        }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(response.error.code == "harmony_discovery_timeout")
        #expect(response.error.endpoint == nil)
    }

    @Test func alreadyPrintedExitDoesNotProduceAnotherEnvelope() async throws {
        let output = try await capture {
            try failWaitCommand(ExitCode.failure, platform: .harmony, hdc: "hdc", outputFormat: .json, host: "127.0.0.1", port: 19421)
        }
        #expect(output.0.isEmpty)
        #expect(output.1 is ExitCode)
    }

}
