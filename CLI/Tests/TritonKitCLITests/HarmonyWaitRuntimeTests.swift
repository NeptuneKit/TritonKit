import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct HarmonyWaitRuntimeTests {
    private let target = TKHarmonyTarget(target: "127.0.0.1:10100", state: "Connected", transport: "TCP")

    @Test("Harmony wait retries a transient recv timeout and preserves diagnostics")
    func retriesTransientReceiveTimeout() async throws {
        var attempts = 0
        var captureTimeouts: [Double] = []
        let result = try await waitForHarmonyText(
            selected: target,
            hdc: "hdc",
            text: "Ready",
            timeout: 0.5,
            interval: 0.01,
            captureLayout: { selected, hdc, output, timeout in
                attempts += 1
                captureTimeouts.append(try #require(timeout))
                if attempts == 1 {
                    let command = TKHarmonyHDCCommand.recvFile(
                        target: selected.target,
                        remotePath: "/data/local/tmp/layout-1.json",
                        localPath: output ?? "/tmp/layout-1.json",
                        executable: hdc
                    ).withTimeout(timeout)
                    throw HostCommandRunError.timeout(
                        command: command,
                        timeoutSeconds: command.defaultTimeoutSeconds,
                        stdoutLogPath: nil,
                        stderrLogPath: "/tmp/issue-147-hdc-recv.stderr.log"
                    )
                }
                return HarmonyLayoutCapture(
                    localPath: output ?? "/tmp/layout-2.json",
                    remotePath: "/data/local/tmp/layout-2.json",
                    sourceCommands: ["hdc dumpLayout", "hdc file recv layout-2.json"],
                    data: Data(#"{"attributes":{"text":"Ready","bounds":"[0,0][100,50]"}}"#.utf8)
                )
            }
        )

        #expect(result.ok)
        #expect(result.matched)
        #expect(!result.timedOut)
        #expect(result.pollCount == 2)
        #expect(result.transientFailureCount == 1)
        #expect(result.lastTransientError?.code == "harmony_layout_recv_timeout")
        #expect(result.lastTransientError?.message.contains("/data/local/tmp/layout-1.json") == true)
        #expect(result.lastTransientError?.message.contains("/tmp/issue-147-hdc-recv.stderr.log") == true)
        #expect(result.sourceCommands.first?.contains("file recv") == true)
        #expect(result.sourceCommands.suffix(2) == ["hdc dumpLayout", "hdc file recv layout-2.json"])
        #expect(captureTimeouts.allSatisfy { $0 > 0 && $0 <= 0.5 })
    }

    @Test("Harmony gone wait does not treat a failed layout capture as disappearance")
    func goneWaitRetriesBeforeDeclaringDisappearance() async throws {
        var attempts = 0
        let result = try await waitForHarmonyText(
            selected: target,
            hdc: "hdc",
            text: "Loading",
            timeout: 0.5,
            interval: 0.01,
            gone: true,
            captureLayout: { selected, hdc, output, timeout in
                attempts += 1
                if attempts == 1 {
                    let command = TKHarmonyHDCCommand.recvFile(
                        target: selected.target,
                        remotePath: "/data/local/tmp/layout-gone.json",
                        localPath: output ?? "/tmp/layout-gone.json",
                        executable: hdc
                    ).withTimeout(timeout)
                    throw HostCommandRunError.timeout(
                        command: command,
                        timeoutSeconds: command.defaultTimeoutSeconds,
                        stdoutLogPath: nil,
                        stderrLogPath: nil
                    )
                }
                return HarmonyLayoutCapture(
                    localPath: output ?? "/tmp/layout-gone-2.json",
                    remotePath: "/data/local/tmp/layout-gone-2.json",
                    sourceCommands: ["hdc dumpLayout", "hdc file recv layout-gone-2.json"],
                    data: Data(#"{"attributes":{"text":"Other","bounds":"[0,0][100,50]"}}"#.utf8)
                )
            }
        )

        #expect(result.ok)
        #expect(result.condition == "gone")
        #expect(result.pollCount == 2)
        #expect(result.transientFailureCount == 1)
    }

    @Test("Harmony wait converts repeated recv timeouts into the normal wait deadline")
    func repeatedReceiveTimeoutsRespectWaitDeadline() async throws {
        let startedAt = Date()
        let result = try await waitForHarmonyText(
            selected: target,
            hdc: "hdc",
            text: "Never",
            timeout: 0.55,
            interval: 0.005,
            captureLayout: { selected, hdc, output, timeout in
                let command = TKHarmonyHDCCommand.recvFile(
                    target: selected.target,
                    remotePath: "/data/local/tmp/layout-timeout.json",
                    localPath: output ?? "/tmp/layout-timeout.json",
                    executable: hdc
                ).withTimeout(timeout)
                throw HostCommandRunError.timeout(
                    command: command,
                    timeoutSeconds: command.defaultTimeoutSeconds,
                    stdoutLogPath: nil,
                    stderrLogPath: nil
                )
            }
        )

        #expect(!result.ok)
        #expect(!result.matched)
        #expect(result.timedOut)
        #expect(result.transientFailureCount > 0)
        #expect(result.lastTransientError?.code == "harmony_layout_recv_timeout")
        #expect(Date().timeIntervalSince(startedAt) < 0.5)
    }

    @Test("Harmony wait does not start a layout capture with a near-zero remaining budget")
    func doesNotStartLayoutCaptureBelowMinimumBudget() async throws {
        var captureCount = 0
        let startedAt = Date()
        let result = try await waitForHarmonyText(
            selected: target,
            hdc: "hdc",
            text: "Never",
            timeout: 0.05,
            interval: 0.001,
            captureLayout: { _, _, _, _ in
                captureCount += 1
                return HarmonyLayoutCapture(
                    localPath: "/tmp/issue-197-layout.json",
                    remotePath: "/data/local/tmp/issue-197-layout.json",
                    sourceCommands: ["hdc dumpLayout", "hdc file recv"],
                    data: Data(#"{"attributes":{"text":"Other"}}"#.utf8)
                )
            }
        )

        #expect(captureCount == 0)
        #expect(result.pollCount == 0)
        #expect(!result.ok)
        #expect(!result.matched)
        #expect(result.timedOut)
        #expect(Date().timeIntervalSince(startedAt) < 0.25)
    }

    @Test("Harmony layout dump and recv share one bounded capture deadline")
    func layoutDumpAndReceiveShareCaptureDeadline() throws {
        var commands: [TKHostCommand] = []
        let capture = try dumpHarmonyLayout(
            selected: target,
            hdc: "hdc",
            output: "/tmp/issue-147-layout.json",
            timeout: 1.25,
            commandRunner: { command in
                commands.append(command)
                if command.arguments.contains("dumpLayout") {
                    Thread.sleep(forTimeInterval: 0.02)
                    return hostResult(
                        stdout: "DumpLayout saved to:/data/local/tmp/layout-147.json",
                        sourceCommand: hostSourceCommand(command)
                    )
                }
                return hostResult(stdout: "received", sourceCommand: hostSourceCommand(command))
            },
            dataLoader: { path in
                #expect(path == "/tmp/issue-147-layout.json")
                return Data(#"{"attributes":{"text":"Ready"}}"#.utf8)
            }
        )

        #expect(commands.count == 2)
        #expect(commands.allSatisfy { $0.defaultTimeoutSeconds > 0 && $0.defaultTimeoutSeconds <= 1.25 })
        #expect(commands[1].defaultTimeoutSeconds < commands[0].defaultTimeoutSeconds)
        #expect(capture.localPath == "/tmp/issue-147-layout.json")
        #expect(capture.remotePath == "/data/local/tmp/layout-147.json")
        #expect(capture.sourceCommands.count == 2)
    }
}

private func hostResult(stdout: String, sourceCommand: String) -> HostProcessResult {
    let data = Data(stdout.utf8)
    return HostProcessResult(
        stdoutData: data,
        stderrData: Data(),
        exitCode: 0,
        sourceCommand: sourceCommand,
        stdoutTruncated: false,
        stderrTruncated: false,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: data.count,
        stderrBytes: 0
    )
}
