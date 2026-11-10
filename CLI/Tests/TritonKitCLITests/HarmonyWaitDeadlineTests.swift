import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct HarmonyWaitDeadlineTests {
    private func fixture(verboseDelay: Double, plainDelay: Double = 0, connected: Bool = false) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sp266-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let tool = root.appendingPathComponent("hdc")
        let source = """
        #!/bin/sh
        root='\(root.path)'
        printf '%s\\n' "$*" >> "$root/calls"
        printf '%s' "$$" > "$root/pid"
        if [ "$1" = list ] && [ "$2" = targets ]; then
            if [ "$3" = -v ]; then
                \(verboseDelay >= 1 ? "exec /bin/sleep \(verboseDelay)" : verboseDelay > 0 ? "/bin/sleep \(verboseDelay)" : ":")
            else
                \(plainDelay >= 1 ? "exec /bin/sleep \(plainDelay)" : plainDelay > 0 ? "/bin/sleep \(plainDelay)" : ":")
            fi
            \(connected ? "printf 'fake-one TCP Connected localhost\\n'" : ":")
        else
            exit 9
        fi
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

    @Test func discoverySharesWaitDeadlineAndReapsTheBackend() async throws {
        let root = try fixture(verboseDelay: 10)
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try Wait.parse(["--platform", "harmony", "--target", "fake-one", "--text", "Ready", "--hdc", root.appendingPathComponent("hdc").path, "--timeout", "2", "--json"])
        let start = Date()
        let output = try await capture { try await command.run() }
        #expect(Date().timeIntervalSince(start) < 2.8)
        #expect(output.1 is ExitCode)
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(response.error.code == "harmony_discovery_timeout")
        #expect(response.error.endpoint == nil)
        let calls = try String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8)
        #expect(calls == "list targets -v\n")
        let pid = try #require(Int32(String(contentsOf: root.appendingPathComponent("pid"), encoding: .utf8)))
        #expect(kill(pid, 0) == -1)
        #expect(errno == ESRCH)
    }

    @Test func fallbackDiscoveryCannotSwallowTheSharedDeadline() async throws {
        let root = try fixture(verboseDelay: 0.05, plainDelay: 10)
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try Wait.parse(["--platform", "harmony", "--target", "fake-one", "--text", "Ready", "--hdc", root.appendingPathComponent("hdc").path, "--timeout", "2", "--json"])
        let start = Date()
        let output = try await capture { try await command.run() }
        #expect(Date().timeIntervalSince(start) < 2.8)
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(response.error.code == "harmony_discovery_timeout")
        #expect(output.1 is ExitCode)
        let calls = try String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8)
        #expect(calls == "list targets -v\nlist targets\n")
    }

    @Test func discoveryTimeIsIncludedInTheConditionBudget() async throws {
        // Inject an already-spent budget; process-launch scheduling is covered
        // separately by the real fixture tests above.
        var captured = false
        let start = Date().addingTimeInterval(-2)
        let result = try await waitForHarmonyText(
            selected: TKHarmonyTarget(target: "fake-one", state: "Connected", transport: "TCP"),
            hdc: "hdc", text: "Absent", timeout: 2.1, interval: 0.01,
            startedAt: start,
            captureLayout: { _, _, _, _ in
                captured = true
                throw HostCommandRunError.launchFailed("expired budget must not capture")
            }
        )
        #expect(result.timedOut)
        #expect(!result.matched)
        #expect(result.pollCount == 0)
        #expect(result.elapsedMs >= 2_000)
        #expect(!captured)
    }

    private func emptyResult(_ command: TKHostCommand) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0,
                          sourceCommand: hostSourceCommand(command), stdoutTruncated: false,
                          stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil,
                          stdoutBytes: 0, stderrBytes: 0)
    }

    @Test func bothDiscoveryCommandsUseOneDecreasingBudget() throws {
        var budgets: [Double] = []
        let result = try harmonyTargets(hdc: "fake-hdc", deadline: Date().addingTimeInterval(2)) { command in
            budgets.append(command.defaultTimeoutSeconds)
            if budgets.count == 1 { Thread.sleep(forTimeInterval: 0.05) }
            return emptyResult(command)
        }
        #expect(result.targets.isEmpty)
        #expect(budgets.count == 2)
        guard budgets.count == 2 else { return }
        #expect(budgets[0] <= 2)
        #expect(budgets[1] < budgets[0] - 0.04)
    }

    @Test func exhaustedDiscoveryBudgetDoesNotLaunchAnotherProcess() throws {
        var launches = 0
        do {
            _ = try harmonyTargets(hdc: "fake-hdc", deadline: Date().addingTimeInterval(-1)) { command in
                launches += 1
                return emptyResult(command)
            }
            Issue.record("expired discovery unexpectedly succeeded")
        } catch let error as HostCommandRunError {
            guard case .timeout(let command, _, _, _) = error else { throw error }
            #expect(command.arguments == ["list", "targets", "-v"])
        }
        #expect(launches == 0)
    }

    @Test func fallbackTimeoutRetainsItsStageInsteadOfBecomingAnEmptyList() throws {
        var launches = 0
        do {
            _ = try harmonyTargets(hdc: "fake-hdc", deadline: Date().addingTimeInterval(2)) { command in
                launches += 1
                if launches == 2 {
                    throw HostCommandRunError.timeout(command: command, timeoutSeconds: command.defaultTimeoutSeconds, stdoutLogPath: nil, stderrLogPath: nil)
                }
                return emptyResult(command)
            }
            Issue.record("fallback timeout was swallowed")
        } catch let error as HostCommandRunError {
            guard case .timeout(let command, _, _, _) = error else { throw error }
            #expect(command.arguments == ["list", "targets"])
            #expect(harmonyWaitFailureDetail(error, hdc: "fake-hdc")?.code == "harmony_discovery_timeout")
        }
        #expect(launches == 2)
    }

    @Test func customNamedExecutableKeepsDiscoveryClassification() async throws {
        let root = try fixture(verboseDelay: 10)
        defer { try? FileManager.default.removeItem(at: root) }
        let custom = root.appendingPathComponent("custom-hdc")
        try FileManager.default.moveItem(at: root.appendingPathComponent("hdc"), to: custom)
        let command = try Wait.parse(["--platform", "harmony", "--target", "fake-one", "--text", "Ready", "--hdc", custom.path, "--timeout", "2", "--json"])
        let output = try await capture { try await command.run() }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.0.utf8))
        #expect(output.1 is ExitCode)
        #expect(response.error.code == "harmony_discovery_timeout")
        #expect(response.error.endpoint == nil)
        #expect(response.error.nextAction?.args.contains(custom.path) == true)
    }

    @Test func customToolDoesNotMisclassifyLayoutOrAnotherExecutable() {
        let layout = TKHarmonyHDCCommand.dumpLayout(target: "fake-one", executable: "fake-hdc")
        let layoutError = HostCommandRunError.timeout(command: layout, timeoutSeconds: 2, stdoutLogPath: nil, stderrLogPath: nil)
        #expect(harmonyWaitFailureDetail(layoutError, hdc: "fake-hdc") == nil)
        let discovery = TKHarmonyHDCCommand.listTargetsPlain(executable: "different-tool")
        let unrelatedError = HostCommandRunError.timeout(command: discovery, timeoutSeconds: 2, stdoutLogPath: nil, stderrLogPath: nil)
        #expect(harmonyWaitFailureDetail(unrelatedError, hdc: "fake-hdc") == nil)
        #expect(hostCommandTimeoutErrorDetail(command: discovery, message: "timeout").code == "host_command_timeout")
    }

}
