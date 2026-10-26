import XCTest
import TritonKitShared
@testable import TritonKitCLI

final class SimulatorResourceStateTests: XCTestCase {
    func testParsesBothLaunchdFormatsAndPreservesEnabledOverrides() throws {
        let state = try SimulatorResourceOverrideState.parse("""
        disabled services = {
            "com.apple.a" => disabled
            "com.apple.b" => enabled
            "com.apple.c" => true
            "com.apple.d" => false
        }
        """)
        XCTAssertEqual(state.overrides, ["com.apple.a": true, "com.apple.b": false,
                                         "com.apple.c": true, "com.apple.d": false])
        XCTAssertNil(state.overrides["com.apple.absent"])
    }

    func testMalformedOrTruncatedOutputCannotClaimStock() {
        for text in ["", "permission denied", "disabled services = {", "{\nunknown\n}", "{\n\"a\" => true\n}\n}", "{\n\"a\" => unknown\n}"] {
            XCTAssertThrowsError(try SimulatorResourceOverrideState.parse(text))
        }
    }

    func testDuplicateLabelsAreRejected() {
        XCTAssertThrowsError(try SimulatorResourceOverrideState.parse("{\n\"a\" => true\n\"a\" => false\n}"))
    }

    func testEmptyMapIsValid() throws {
        XCTAssertEqual(try SimulatorResourceOverrideState.parse("disabled services = {\n}").overrides, [:])
    }

    func testParsesIndentedRealLaunchctlOutput() throws {
        // Captured print-disabled output: header and closing brace are tab-indented.
        let output = "\n" + """
        \tdisabled services = {
        \t\t"com.apple.nanonewscd" => enabled
        \t\t"com.apple.companionmessagesd" => enabled
        \t\t"com.apple.bulletindistributord" => enabled
        \t\t"com.apple.security.otpaird" => enabled
        \t\t"com.apple.brook.brookcompaniond" => enabled
        \t\t"com.apple.NPKCompanionAgent" => enabled
        \t\t"com.apple.nanomapscd" => enabled
        \t\t"com.apple.pairedsyncd" => enabled
        \t\t"com.apple.eventkitsyncd" => enabled
        \t\t"com.apple.companionfindlocallyd" => enabled
        \t\t"com.apple.appconduitd" => enabled
        \t\t"com.apple.schooltimed" => enabled
        \t\t"com.apple.nanosystemsettingsd" => enabled
        \t\t"com.apple.companionappd" => enabled
        \t\t"com.apple.nanoappregistryd" => enabled
        \t\t"com.apple.pairedunlockd" => enabled
        \t\t"com.apple.addressbooksyncd" => enabled
        \t}
        """
        let state = try SimulatorResourceOverrideState.parse(output)
        XCTAssertEqual(state.overrides.count, 17)
        XCTAssertTrue(state.overrides.values.allSatisfy { !$0 })
        XCTAssertEqual(state.overrides["com.apple.nanonewscd"], false)
        XCTAssertEqual(state.overrides["com.apple.addressbooksyncd"], false)
    }

    func testIndentedWrappersDoNotRelaxContentValidation() {
        for text in [
            "\tdisabled services = {\n\t\"a\" => disabled trailing\n\t}",
            "\tdisabled services = {\n\t\"a\" => unknown\n\t}",
            "\tdisabled services = {\n\t\"a\" => true\n\t\"a\" => false\n\t}",
            "\tdisabled services = { extra\n\t}",
            "\tdisabled services = {\n\t} trailing",
        ] {
            XCTAssertThrowsError(try SimulatorResourceOverrideState.parse(text))
        }
    }

    func testWhitespaceAroundBothWrapperFormatsIsAccepted() throws {
        for header in ["{", "disabled services = {"] {
            let state = try SimulatorResourceOverrideState.parse("\t\(header) \t\n\t\"a\" => disabled\n\t} \t\n")
            XCTAssertEqual(state.overrides, ["a": true])
        }
    }
}


private final class ResourceReadRunner: SimulatorResourceCommandRunning {
    var commands: [TKHostCommand] = []
    let response: (TKHostCommand, Int) throws -> HostProcessResult
    init(_ response: @escaping (TKHostCommand, Int) throws -> HostProcessResult) { self.response = response }
    func run(_ command: TKHostCommand) throws -> HostProcessResult {
        commands.append(command)
        return try response(command, commands.count)
    }
}

private func resourceReadResult(_ command: TKHostCommand, exit: Int32 = 0, stdout: String = "{\n}", stderr: String = "", stdoutTruncated: Bool = false, stderrTruncated: Bool = false) -> HostProcessResult {
    HostProcessResult(stdoutData: Data(stdout.utf8), stderrData: Data(stderr.utf8), exitCode: exit,
                      sourceCommand: hostSourceCommand(command), stdoutTruncated: stdoutTruncated,
                      stderrTruncated: stderrTruncated, stdoutLogPath: nil, stderrLogPath: nil,
                      stdoutBytes: stdout.utf8.count, stderrBytes: stderr.utf8.count)
}

extension SimulatorResourceStateTests {
    private var retryUDID: String { "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" }
    private var launchd124: String { "An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=124):\nFailed to start launchd_sim: could not bind to session, launchd_sim may have crashed or quit responding" }

    func testReadRetriesTransientReturnedAndProductionThrownFailuresOnSameArgv() throws {
        for throwsFailure in [false, true] {
            for message in [launchd124, "Domain is tearing down"] {
                let runner = ResourceReadRunner { command, count in
                    if count == 1 {
                        let result = resourceReadResult(command, exit: 124, stdout: "", stderr: message)
                        if throwsFailure { throw HostCommandRunError.nonZeroExit(command: command, result: result) }
                        return result
                    }
                    return resourceReadResult(command, stdout: "{\n\"a\" => false\n}")
                }
                let state = try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID)
                XCTAssertEqual(state.overrides, ["a": false])
                XCTAssertEqual(runner.commands.count, 2)
                XCTAssertTrue(runner.commands.allSatisfy { $0.executable == "xcrun" && $0.arguments == ["simctl", "spawn", retryUDID, "launchctl", "print-disabled", "system"] })
            }
        }
    }

    func testReadRetriesAreLimitedAndPreserveThrownFailure() {
        let runner = ResourceReadRunner { command, _ in
            throw HostCommandRunError.nonZeroExit(command: command, result: resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124))
        }
        XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID)) { error in
            guard case HostCommandRunError.nonZeroExit = error else { return XCTFail("Original thrown failure was replaced: \(error)") }
        }
        XCTAssertEqual(runner.commands.count, 3)
    }

    func testTruncatedSuccessIsRejectedWithoutRetry() {
        for stdoutTruncated in [false, true] {
            let runner = ResourceReadRunner { command, _ in
                resourceReadResult(command, stdoutTruncated: stdoutTruncated, stderrTruncated: !stdoutTruncated)
            }
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID))
            XCTAssertEqual(runner.commands.count, 1)
        }
    }
}


extension SimulatorResourceStateTests {
    func testReturnedTransientExhaustionKeepsCommandFailed() {
        let runner = ResourceReadRunner { command, _ in
            resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124)
        }
        XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID, pause: { _ in })) {
            XCTAssertEqual($0 as? SimulatorResourceMutationError, .commandFailed)
        }
        XCTAssertEqual(runner.commands.count, 3)
    }

    func testBudgetIncludesCommandTimeAndBackoffAndCapsEachTimeout() throws {
        var clock: TimeInterval = 100
        var delays: [TimeInterval] = []
        let runner = ResourceReadRunner { command, count in
            clock += 2
            return count < 3 ? resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124)
                : resourceReadResult(command)
        }
        _ = try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID, now: { clock }, pause: { delays.append($0); clock += $0 })
        XCTAssertEqual(delays, [0.1, 0.2])
        for (actual, expected) in zip(runner.commands.map(\.defaultTimeoutSeconds), [30.0, 27.9, 25.7]) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
        XCTAssertEqual(runner.commands.count, 3)
    }

    func testExhaustedBudgetStopsBeforeBackoffOrNextCommand() {
        for exhaustDuringPause in [false, true] {
            var clock: TimeInterval = 0
            var pauses = 0
            let runner = ResourceReadRunner { command, _ in
                clock = exhaustDuringPause ? 29 : 30
                throw HostCommandRunError.nonZeroExit(command: command, result: resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124))
            }
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID, now: { clock }, pause: { _ in pauses += 1; clock = 30 })) {
                guard case HostCommandRunError.nonZeroExit = $0 else { return XCTFail("Original failure lost") }
            }
            XCTAssertEqual(runner.commands.count, 1)
            XCTAssertEqual(pauses, exhaustDuringPause ? 1 : 0)
        }
    }

    func testFailureFromDifferentCommandOrTargetOrTimeoutIsNeverRetried() {
        for kind in 0..<5 {
            var expected: TKHostCommand?
            let runner = ResourceReadRunner { command, _ in
                let mismatch: TKHostCommand
                switch kind {
                case 0: mismatch = TKHostCommand(arguments: ["simctl", "spawn", "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "launchctl", "print-disabled", "system"], defaultTimeoutSeconds: command.defaultTimeoutSeconds)
                case 1: mismatch = TKHostCommand(arguments: ["simctl", "spawn", self.retryUDID, "launchctl", "disable", "system/a"], defaultTimeoutSeconds: command.defaultTimeoutSeconds)
                case 2: mismatch = command.withTimeout(command.defaultTimeoutSeconds + 1)
                case 3: mismatch = TKHostCommand(executable: "/other/xcrun", arguments: command.arguments, defaultTimeoutSeconds: command.defaultTimeoutSeconds)
                default: mismatch = TKHostCommand(arguments: command.arguments, environment: ["OTHER": "1"], defaultTimeoutSeconds: command.defaultTimeoutSeconds)
                }
                expected = mismatch
                throw HostCommandRunError.nonZeroExit(command: mismatch, result: resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124))
            }
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID)) {
                guard case HostCommandRunError.nonZeroExit(let command, _) = $0 else { return XCTFail("Original failure lost") }
                XCTAssertEqual(command, expected)
            }
            XCTAssertEqual(runner.commands.count, 1)
        }
    }

    func testNonTransientReturnedAndThrownFailuresAreNotRetried() {
        for throwsFailure in [false, true] {
            for kind in 0..<13 {
                let runner = ResourceReadRunner { command, _ in
                    var result: HostProcessResult
                    switch kind {
                    case 0: result = resourceReadResult(command, exit: 124, stdout: "", stderr: "Timed out")
                    case 1: result = resourceReadResult(command, exit: 1, stdout: "", stderr: self.launchd124)
                    case 2: result = resourceReadResult(command, exit: 124, stdout: "", stderr: "Failed to start launchd_sim: Permission denied")
                    case 3: result = resourceReadResult(command, exit: 1, stdout: "", stderr: "Domain is tearing down: Operation not permitted")
                    case 4: result = resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124, stdoutTruncated: true)
                    case 5: result = resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124, stderrTruncated: true)
                    case 6: result = resourceReadResult(command, exit: 124, stdout: "{\n\"a\" => true\n\"a\" => false\n}", stderr: self.launchd124)
                    case 7: result = resourceReadResult(command, exit: 124, stdout: "malformed", stderr: self.launchd124)
                    case 8: result = resourceReadResult(command, exit: 124, stdout: "", stderr: "launchd_sim crashed")
                    case 9: result = resourceReadResult(command, exit: 0, stdout: "{\n\"a\" => true\n\"a\" => false\n}", stderr: self.launchd124)
                    case 10: result = resourceReadResult(command, exit: 0, stdout: "malformed", stderr: "Domain is tearing down")
                    case 11: result = resourceReadResult(command, exit: 1, stdout: "", stderr: "Domain is tearing down: Access denied")
                    default: result = resourceReadResult(TKHostCommand(arguments: ["other"]), exit: 124, stdout: "", stderr: self.launchd124)
                    }
                    if throwsFailure { throw HostCommandRunError.nonZeroExit(command: command, result: result) }
                    return result
                }
                XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID), "kind=\(kind), throws=\(throwsFailure)")
                XCTAssertEqual(runner.commands.count, 1, "kind=\(kind), throws=\(throwsFailure)")
            }
        }
    }

    func testTimeoutLaunchFailureCancellationAndArbitraryThrowsAreNotRetried() {
        enum FixtureError: Error { case failed }
        for kind in 0..<4 {
            let runner = ResourceReadRunner { command, _ in
                switch kind {
                case 0: throw HostCommandRunError.timeout(command: command, timeoutSeconds: 30, stdoutLogPath: nil, stderrLogPath: nil)
                case 1: throw HostCommandRunError.launchFailed(self.launchd124)
                case 2: throw CancellationError()
                default: throw FixtureError.failed
                }
            }
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID))
            XCTAssertEqual(runner.commands.count, 1)
        }
    }

    func testBackoffCancellationStopsBeforeNextCommand() {
        let runner = ResourceReadRunner { command, _ in resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124) }
        XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID, pause: { _ in throw CancellationError() })) {
            XCTAssertTrue($0 is CancellationError)
        }
        XCTAssertEqual(runner.commands.count, 1)
    }

    func testCancelledTaskDoesNotReadOrReplayAfterInFlightRead() async {
        for cancelAfterRead in [false, true] {
            let ready = DispatchSemaphore(value: 0)
            let proceed = DispatchSemaphore(value: 0)
            let runner = ResourceReadRunner { command, _ in
                if cancelAfterRead {
                    ready.signal()
                    guard proceed.wait(timeout: .now() + 3) == .success else { throw CancellationError() }
                }
                return resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124)
            }
            let task = Task.detached { () -> Bool in
                if !cancelAfterRead {
                    ready.signal()
                    guard proceed.wait(timeout: .now() + 3) == .success else { return false }
                }
                do { _ = try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: self.retryUDID); return false }
                catch is CancellationError { return true }
                catch { return false }
            }
            XCTAssertEqual(ready.wait(timeout: .now() + 3), .success)
            task.cancel()
            proceed.signal()
            let cancelled = await task.value
            XCTAssertTrue(cancelled)
            XCTAssertEqual(runner.commands.count, cancelAfterRead ? 1 : 0)
        }
    }

    func testMutationFailureInApplyAndRestoreIsNeverReplayed() {
        for restore in [false, true] {
            for throwsFailure in [false, true] {
                let runner = ResourceReadRunner { command, count in
                    if count == 1 { return resourceReadResult(command, stdout: "{\n\"com.apple.apsd\" => true\n}") }
                    let result = resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124)
                    if throwsFailure { throw HostCommandRunError.nonZeroExit(command: command, result: result) }
                    return result
                }
                let runtime = CLISimulatorResourceRuntime(runner: runner)
                let status = TKSimulatorResourceStatus(udid: retryUDID, runtime: "fixture")
                XCTAssertThrowsError(try {
                    if restore {
                        try runtime.restore(TKSimulatorResourceReceipt(udid: retryUDID, profile: .init(id: "stock"), previous: status, applied: status, noReboot: true, appliedManagedDisabled: ["com.apple.apsd"]))
                    } else {
                        _ = try runtime.apply(.init(action: .apply, udid: retryUDID, profile: "stock", noReboot: true), previous: status)
                    }
                }())
                XCTAssertEqual(runner.commands.count, 2)
                XCTAssertEqual(runner.commands.filter { $0.arguments.contains("enable") }.count, 1)
                XCTAssertFalse(runner.commands.contains { $0.arguments.contains("boot") || $0.arguments.contains("disable") })
            }
        }
    }

    func testInvalidUDIDStopsBeforeRunner() {
        let runner = ResourceReadRunner { command, _ in resourceReadResult(command) }
        XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: "booted"))
        XCTAssertTrue(runner.commands.isEmpty)
    }
}


extension SimulatorResourceStateTests {
    func testPermanentDiagnosticWithTransientTextStillFailsClosed() {
        for message in ["Not authorized", "No such file or directory", "Invalid argument", "Could not find service", "Service not found", "Not supported", "Unsupported", "Unrecognized option", "Unknown subcommand", "Timed out", "Timeout", "Cancelled", "Canceled"] {
            let runner = ResourceReadRunner { command, _ in
                resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124 + "\nDomain is tearing down\n" + message)
            }
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID))
            XCTAssertEqual(runner.commands.count, 1, message)
        }
    }

    func testInvalidUTF8IsNotRetriedEvenWithTransientDiagnostic() {
        for invalidStderr in [false, true] {
            let runner = ResourceReadRunner { command, _ in
                HostProcessResult(stdoutData: invalidStderr ? Data() : Data([0xff]),
                                  stderrData: Data(self.launchd124.utf8) + (invalidStderr ? Data([0xff]) : Data()),
                                  exitCode: 124, sourceCommand: hostSourceCommand(command),
                                  stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil,
                                  stdoutBytes: invalidStderr ? 0 : 1, stderrBytes: self.launchd124.utf8.count + (invalidStderr ? 1 : 0))
            }
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID))
            XCTAssertEqual(runner.commands.count, 1)
        }
    }

    func testMalformedReadAfterTransientIsNotRetriedAgain() {
        for text in ["malformed", "{\n\"a\" => true\n\"a\" => false\n}"] {
            let runner = ResourceReadRunner { command, count in
                count == 1 ? resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124)
                    : resourceReadResult(command, stdout: text)
            }
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID, pause: { _ in }))
            XCTAssertEqual(runner.commands.count, 2)
        }
    }

    func testSuccessfulResultPastBudgetCannotSucceedOrRetry() {
        var clock: TimeInterval = 0
        let runner = ResourceReadRunner { command, _ in
            clock = 31
            return resourceReadResult(command)
        }
        XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID, now: { clock })) {
            XCTAssertEqual($0 as? SimulatorResourceMutationError, .commandFailed)
        }
        XCTAssertEqual(runner.commands.count, 1)
    }

    func testApplyAndRestoreReadExhaustionNeverStartsMutation() {
        for restore in [false, true] {
            let runner = ResourceReadRunner { command, _ in
                throw HostCommandRunError.nonZeroExit(command: command, result: resourceReadResult(command, exit: 124, stdout: "", stderr: self.launchd124))
            }
            let runtime = CLISimulatorResourceRuntime(runner: runner)
            let status = TKSimulatorResourceStatus(udid: retryUDID, runtime: "fixture")
            XCTAssertThrowsError(try {
                if restore {
                    try runtime.restore(TKSimulatorResourceReceipt(udid: retryUDID, profile: .init(id: "stock"), previous: status, applied: status, noReboot: true, appliedManagedDisabled: ["com.apple.apsd"]))
                } else {
                    _ = try runtime.apply(.init(action: .apply, udid: retryUDID, profile: "stock", noReboot: true), previous: status)
                }
            }())
            XCTAssertEqual(runner.commands.count, 3)
            XCTAssertTrue(runner.commands.allSatisfy { $0.arguments == ["simctl", "spawn", retryUDID, "launchctl", "print-disabled", "system"] })
        }
    }
}


extension SimulatorResourceStateTests {
    func testTransientSubstringInsideUnknownDiagnosticIsNotRetried() {
        for throwsFailure in [false, true] {
            for message in [
                "Unrecognized command: Domain is tearing down",
                "Domain is tearing down: unsupported operation",
                "Failed to start launchd_sim: unsupported operation",
                "warning: Domain is tearing down",
                "Domain is tearing down\nSome unrelated permanent error",
                "Domain is tearing down but the command is invalid",
                launchd124 + "\nSome unrelated error",
                "An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=1):\nDomain is tearing down",
            ] {
                let runner = ResourceReadRunner { command, _ in
                    let result = resourceReadResult(command, exit: 124, stdout: "", stderr: message)
                    if throwsFailure { throw HostCommandRunError.nonZeroExit(command: command, result: result) }
                    return result
                }
                XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID))
                XCTAssertEqual(runner.commands.count, 1, message)
            }
        }
    }

    func testSuccessFromMismatchedCommandIsRejectedWithoutRetry() {
        let runner = ResourceReadRunner { command, _ in
            resourceReadResult(TKHostCommand(arguments: ["simctl", "spawn", "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "launchctl", "print-disabled", "system"]))
        }
        XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID)) {
            XCTAssertEqual($0 as? SimulatorResourceMutationError, .commandFailed)
        }
        XCTAssertEqual(runner.commands.count, 1)
    }

    func testBoundSuccessMayHaveNonemptyStderr() throws {
        let runner = ResourceReadRunner { command, _ in resourceReadResult(command, stderr: "diagnostic warning") }
        XCTAssertEqual(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID).overrides, [:])
        XCTAssertEqual(runner.commands.count, 1)
    }

    func testExactNativeTeardownHeaderCanRetry() throws {
        for throwsFailure in [false, true] {
            let runner = ResourceReadRunner { command, count in
                guard count == 1 else { return resourceReadResult(command) }
                let result = resourceReadResult(command, exit: 3, stdout: "", stderr: "An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=3):\nDomain is tearing down")
                if throwsFailure { throw HostCommandRunError.nonZeroExit(command: command, result: result) }
                return result
            }
            XCTAssertEqual(try CLISimulatorResourceRuntime(runner: runner).readOverrides(udid: retryUDID, pause: { _ in }).overrides, [:])
            XCTAssertEqual(runner.commands.count, 2)
        }
    }
}
