import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct AndroidInstallReadinessTests {
    private var target: HostDeviceTarget {
        HostDeviceTarget(platform: "android", id: "android:emulator-5554", target: "emulator-5554", state: "device", ready: true, source: "fixture", name: nil, runtime: nil, transport: nil)
    }

    @Test("package paths before boot completion cannot satisfy install readiness")
    func incompleteBootTimesOut() async throws {
        let root = try makeADBFixture(boot: "printf '\\n'", package: "echo package:/system/framework/framework-res.apk")
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            _ = try await waitForHostDeviceReady(platform: .android, selected: target, hdc: "unused", adb: root.appendingPathComponent("adb").path, timeout: 0.4, interval: 0.1)
            Issue.record("Package availability alone must not report ready before boot completion")
        } catch HostCommandRunError.deviceNotReady { }
        let ledger = try String(contentsOf: root.appendingPathComponent("ledger"), encoding: .utf8)
        #expect(ledger.contains("shell getprop sys.boot_completed"))
        #expect(!ledger.contains("shell pm path android"))
    }

    @Test("readiness waits for boot completion then package service and records each successful probe")
    func slowBootAndPackageService() async throws {
        let root = try makeADBFixture(boot: """
        count=0
        if [ -f "$fixture_root/boot-count" ]; then count=$(cat "$fixture_root/boot-count"); fi
        count=$((count + 1))
        echo "$count" > "$fixture_root/boot-count"
        if [ "$count" -ge 2 ]; then echo 1; fi
        """, package: """
        if [ ! -f "$fixture_root/package-count" ]; then
          touch "$fixture_root/package-count"
          echo 'Cannot access system provider: settings before system providers are installed' >&2
          exit 1
        fi
        echo package:/system/framework/framework-res.apk
        """)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try await waitForHostDeviceReady(platform: .android, selected: target, hdc: "unused", adb: root.appendingPathComponent("adb").path, timeout: 5, interval: 0.1)
        #expect(result.ready)
        #expect(result.attempt == 3)
        #expect(result.sourceCommand.contains("get-state"))
        #expect(result.sourceCommand.contains("sys.boot_completed"))
        #expect(result.sourceCommand.contains("pm path android"))
        let ledger = try String(contentsOf: root.appendingPathComponent("ledger"), encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(Array(ledger.prefix(3)) == ["-s emulator-5554 get-state", "-s emulator-5554 shell getprop sys.boot_completed", "-s emulator-5554 get-state"])
    }

    @Test("remote screencap and pull file errors remain screenshot failures", arguments: [false, true])
    func missingRemoteScreenshotIsNotMissingADB(pull: Bool) throws {
        let command = pull
            ? TKAndroidADBCommand.pullFile(serial: "emulator-5554", remotePath: "/sdcard/triton.png", localPath: "/tmp/triton.png")
            : TKAndroidADBCommand.screenshotToFile(serial: "emulator-5554", remotePath: "/sdcard/triton.png")
        let result = processResult(command, stderr: "Failed to open file /sdcard/triton.png: No such file or directory", code: 1)
        let response = try errorEnvelope(HostCommandRunError.nonZeroExit(command: command, result: result))
        #expect(response.error.code == "android_screenshot_failed")
        #expect(response.error.hint?.contains("Install Android SDK") == false)
    }

    @Test("remote shell status 127 is not evidence that host adb is missing")
    func remoteShellCommandMissing() throws {
        let command = TKAndroidADBCommand.screenshotToFile(serial: "emulator-5554", remotePath: "/sdcard/triton.png")
        let result = processResult(command, stderr: "/system/bin/sh: screencap: not found", code: 127)
        let response = try errorEnvelope(HostCommandRunError.nonZeroExit(command: command, result: result))
        #expect(response.error.code == "android_screenshot_failed")
    }

    @Test("host env executable lookup still reports missing adb")
    func hostADBMissing() throws {
        let command = TKAndroidADBCommand.listDevices()
        let result = processResult(command, stderr: "env: adb: No such file or directory", code: 127)
        let response = try errorEnvelope(HostCommandRunError.nonZeroExit(command: command, result: result))
        #expect(response.error.code == "android_adb_not_found")
    }

    private func makeADBFixture(boot: String, package: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("triton-issue228-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let script = """
        #!/bin/sh
        fixture_root=$(dirname "$0")
        echo "$*" >> "$fixture_root/ledger"
        case "$*" in
          '-s emulator-5554 get-state') echo device ;;
          '-s emulator-5554 shell getprop sys.boot_completed')
        \(boot)
          ;;
          '-s emulator-5554 shell pm path android')
        \(package)
          ;;
          *) echo 'unexpected fixture command' >&2; exit 64 ;;
        esac
        """
        let executable = root.appendingPathComponent("adb")
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return root
    }

    private func processResult(_ command: TKHostCommand, stderr: String, code: Int32) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(), stderrData: Data(stderr.utf8), exitCode: code, sourceCommand: hostSourceCommand(command), stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: stderr.utf8.count)
    }

    private func errorEnvelope(_ error: Error) throws -> TKCLIErrorResponse {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        var failure: Error?
        do { try failHostCommand(error, outputFormat: .json) } catch { failure = error }
        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        pipe.fileHandleForWriting.closeFile()
        #expect(failure is ExitCode)
        return try JSONDecoder().decode(TKCLIErrorResponse.self, from: pipe.fileHandleForReading.readDataToEndOfFile())
    }
}
