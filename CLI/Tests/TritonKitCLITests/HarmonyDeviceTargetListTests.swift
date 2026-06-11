import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HarmonyDeviceTargetListTests {
    @Test("Harmony target list parses verbose target output from stderr")
    func harmonyTargetListParsesVerboseTargetOutputFromStderr() throws {
        var commands: [[String]] = []

        let result = try harmonyTargets(hdc: "hdc") { command in
            commands.append(command.arguments)
            return hostProcessResult(
                command,
                stderr: "127.0.0.1:5555\t\tTCP\tConnected\tlocalhost\n"
            )
        }

        #expect(commands == [["list", "targets", "-v"]])
        #expect(result.targets.map(\.target) == ["127.0.0.1:5555"])
        #expect(result.targets.map(\.transport) == ["TCP"])
        #expect(result.targets.map(\.scope) == [.emulator])
        #expect(result.sourceCommand == "hdc list targets -v")
    }

    @Test("Harmony target list falls back to plain hdc targets when verbose output is not parseable")
    func harmonyTargetListFallsBackToPlainHdcTargets() throws {
        var commands: [[String]] = []

        let result = try harmonyHostDeviceTargets(scope: .emulator, hdc: "hdc") { command in
            commands.append(command.arguments)
            if command.arguments == ["list", "targets", "-v"] {
                return hostProcessResult(command, stderr: "Connect server failed\n")
            }
            if command.arguments == ["list", "targets"] {
                return hostProcessResult(command, stdout: "127.0.0.1:5555\n")
            }
            throw HostCommandRunError.launchFailed("unexpected command: \(command.arguments.joined(separator: " "))")
        }

        #expect(commands == [["list", "targets", "-v"], ["list", "targets"]])
        #expect(result.targets.map(\.target) == ["127.0.0.1:5555"])
        #expect(result.targets.map(\.ready) == [true])
        #expect(result.targets.map(\.scope) == ["emulator"])
        #expect(result.sourceCommand == "hdc list targets -v\nhdc list targets")
    }
}

private func hostProcessResult(
    _ command: TKHostCommand,
    stdout: String = "",
    stderr: String = ""
) -> HostProcessResult {
    let stdoutData = Data(stdout.utf8)
    let stderrData = Data(stderr.utf8)
    return HostProcessResult(
        stdoutData: stdoutData,
        stderrData: stderrData,
        exitCode: 0,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: false,
        stderrTruncated: false,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: stdoutData.count,
        stderrBytes: stderrData.count
    )
}
