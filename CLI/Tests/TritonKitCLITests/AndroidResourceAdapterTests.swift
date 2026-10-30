import Foundation
import XCTest
import TritonKitShared
@testable import TritonKitCLI

final class AndroidResourceAdapterTests: XCTestCase {
    private var package: EmulatorResourceItem { EmulatorResourceCatalog.items(.android).first { $0.feature == "assistant" }! }
    private var bluetooth: EmulatorResourceItem { EmulatorResourceCatalog.items(.android).first { $0.kind == .bluetooth }! }

    func testIdentityRequiresReadyEmulatorAndBindsImageInstanceAndBoot() throws {
        let fixture = AndroidResourceFixture()
        let adapter = fixture.adapter(device: "android:emulator-5556")
        let first = try adapter.identity()
        XCTAssertEqual(first.platform, .android)
        XCTAssertEqual(first.target, "emulator-5556")
        XCTAssertEqual(first.instance, "Fixture_API_34")
        XCTAssertEqual(first.image, "google/sdk/arm64:14/ABC/123:userdebug/test-keys")
        for key in ["shell getprop ro.boot.qemu.avd_name", "shell getprop ro.build.fingerprint", "shell cat /proc/sys/kernel/random/boot_id"] {
            let old = fixture.responses[key]
            fixture.responses[key] = key.contains("boot_id") ? "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE\n" : "changed\n"
            XCTAssertNotEqual(first, try adapter.identity())
            fixture.responses[key] = old
        }
        XCTAssertTrue(fixture.commands.allSatisfy { Array($0.arguments.prefix(2)) == ["-s", "emulator-5556"] })
    }

    func testInvalidSerialNeverInvokesRunner() {
        for serial in ["booted", "android", "emulator-5555", "emulator-65536", "emulator-05556", "127.0.0.1:5556", "device123", "emulator-5556;reboot", "android:android:emulator-5556"] {
            let fixture = AndroidResourceFixture()
            XCTAssertThrowsError(try fixture.adapter(device: serial).identity(), serial)
            XCTAssertTrue(fixture.commands.isEmpty, serial)
        }
    }

    func testIdentityRejectsOfflinePhysicalAndMissingOrMalformedFields() {
        for (key, value) in [
            ("get-state", "offline\n"),
            ("shell getprop ro.kernel.qemu", "0\n"),
            ("shell getprop ro.boot.qemu.avd_name", "\n"),
            ("shell getprop ro.build.fingerprint", "unknown\n"),
            ("shell getprop ro.build.fingerprint", "first\nsecond\n"),
            ("shell cat /proc/sys/kernel/random/boot_id", "not-a-uuid\n")
        ] {
            let fixture = AndroidResourceFixture()
            fixture.responses[key] = value
            XCTAssertThrowsError(try fixture.adapter().identity(), key)
        }
    }

    func testBootQemuPropertyCanProveEmulatorWhenKernelPropertyMissing() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell getprop ro.kernel.qemu"] = "\n"
        fixture.responses["shell getprop ro.boot.qemu"] = "1\n"
        XCTAssertEqual(try fixture.adapter().identity().instance, "Fixture_API_34")
    }

    func testPackageReadsAllOriginalEnabledStatesAndDoesNotConfuseUserTen() throws {
        let fixture = AndroidResourceFixture()
        for state in 0...4 {
            fixture.responses["shell dumpsys package \(package.id)"] = packageDump("User 10: installed=true enabled=3\n    User 0: installed=true stopped=false enabled=\(state)")
            XCTAssertEqual(try fixture.adapter().read(package).value, String(state))
        }
    }

    func testPackageStateIgnoresQueriesAndHiddenSystemPackageUserSections() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell dumpsys package \(package.id)"] = """
        Activity Resolver Table:
          Non-Data Actions:
            fixture.action:
              \(package.id)/.FixtureActivity

        Packages:
          Package [\(package.id)] (abc123):
            userId=10001
            User 0: ceDataInode=12345 installed=true hidden=false suspended=false distractionFlags=0 stopped=false notLaunched=false enabled=0 instant=false virtual=false
              installReason=0
              runtime permissions:
                android.permission.RECORD_AUDIO: granted=false

        Queries:
          system apps queryable: false
          queryable via interaction:
            User 0:
              [com.example.fixture]

        Hidden system packages:
          Package [\(package.id)] (def456):
            User 0: ceDataInode=0 installed=true enabled=3
        """
        let state = try fixture.adapter().read(package)
        XCTAssertTrue(state.available)
        XCTAssertEqual(state.value, "0")
    }

    func testPackageRejectsBareUserInsideCurrentPackageAndHiddenPackageAsFallback() {
        let fixture = AndroidResourceFixture()
        for dump in [
            packageDump("User 0:"),
            packageDump("User 0: installed=true enabled=0\n    User 0:"),
            "Packages:\n  Package [unrelated.fixture] (abc):\n    User 0: installed=true enabled=0\nHidden system packages:\n  Package [\(package.id)] (def):\n    User 0: installed=true enabled=3\n",
            packageDump("User 0: installed=true enabled=0") + packageDump("User 0: installed=true enabled=0")
        ] {
            fixture.responses["shell dumpsys package \(package.id)"] = dump
            XCTAssertThrowsError(try fixture.adapter().read(package), dump)
        }
    }

    func testMissingAndUninstalledPackagesAreUnavailable() throws {
        let fixture = AndroidResourceFixture()
        for dump in ["Unable to find package: \(package.id)\n", packageDump("User 0: installed=false enabled=0")] {
            fixture.responses["shell dumpsys package \(package.id)"] = dump
            let state = try fixture.adapter().read(package)
            XCTAssertFalse(state.available)
            XCTAssertNil(state.value)
        }
    }

    func testPackageFailsClosedForAmbiguousMissingOrInvalidUserState() {
        let fixture = AndroidResourceFixture()
        for user in ["User 10: installed=true enabled=1", "User 0: installed=true enabled=9", "User 0: installed=true enabled=1 enabled=3", "User 0: installed=true enabled=1\n    User 0: installed=true enabled=3", "User 0: installed=true"] {
            fixture.responses["shell dumpsys package \(package.id)"] = packageDump(user)
            XCTAssertThrowsError(try fixture.adapter().read(package), user)
        }
        fixture.responses["shell dumpsys package \(package.id)"] = "Packages:\n  Package [unrelated.private.app] (a):\n    User 0: installed=true enabled=1\n"
        XCTAssertThrowsError(try fixture.adapter().read(package))
    }

    func testBluetoothUsesCurrentStatusAndIgnoresHistory() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell dumpsys bluetooth_manager"] = "Bluetooth Status\n  enabled: false\n  state: OFF\n\nEnable log:\n  enabled: true\n  state: ON\n"
        XCTAssertEqual(try fixture.adapter().read(bluetooth).value, "off")
        fixture.responses["shell dumpsys bluetooth_manager"] = "Bluetooth Status\n  enabled: true\n  state: ON\n"
        XCTAssertEqual(try fixture.adapter().read(bluetooth).value, "on")
    }

    func testBluetoothTransitionalConflictingOrHistoricalStateIsUnknown() throws {
        let fixture = AndroidResourceFixture()
        for dump in ["Bluetooth Status\n  enabled: true\n  state: TURNING_OFF\n", "Bluetooth Status\n  enabled: true\n  state: OFF\n", "Enable log:\n  enabled: true\n  state: ON\n", "Bluetooth Status\n  enabled: true\n  enabled: false\n", "Bluetooth Status\n  Enable log:\n    enabled: true\n    state: ON\n"] {
            fixture.responses["shell dumpsys bluetooth_manager"] = dump
            let state = try fixture.adapter().read(bluetooth)
            XCTAssertNil(state.value, dump)
            XCTAssertFalse(state.available, dump)
        }
        XCTAssertFalse(fixture.commands.contains { $0.arguments.contains("settings") })
    }

    func testPackageWritesEveryOriginalStateWithFixedArgumentsAndMatchingAcknowledgement() throws {
        let fixture = AndroidResourceFixture()
        let verbs = ["default-state", "enable", "disable", "disable-user", "disable-until-used"]
        let acknowledgements = ["default", "enabled", "disabled", "disabled-user", "disabled-until-used"]
        for state in 0...4 {
            let command = "shell pm \(verbs[state]) --user 0 \(package.id)"
            fixture.responses[command] = "Package \(package.id) new state: \(acknowledgements[state])\n"
            try fixture.adapter().write(package, value: String(state))
            XCTAssertEqual(fixture.commands.last?.arguments, ["-s", "emulator-5556", "shell", "pm", verbs[state], "--user", "0", package.id])
            XCTAssertEqual(fixture.commands.last?.riskLevel, .automation)
        }
    }

    func testBluetoothWritesExplicitEnableDisable() throws {
        let fixture = AndroidResourceFixture()
        for (value, verb) in [("on", "enable"), ("off", "disable")] {
            for output in ["", "true\n", "BluetoothShellCommand: Exec \(verb)\n\(verb): Success\n"] {
                fixture.responses["shell cmd bluetooth_manager \(verb)"] = output
                try fixture.adapter().write(bluetooth, value: value)
                XCTAssertEqual(fixture.commands.last?.arguments, ["-s", "emulator-5556", "shell", "cmd", "bluetooth_manager", verb])
            }
        }
    }

    func testInvalidItemOrStateFailsBeforeAnyCommand() {
        let fixture = AndroidResourceFixture()
        let unknown = EmulatorResourceItem(id: "private.app;reboot", feature: "assistant", kind: .package, disabledValue: "3")
        XCTAssertThrowsError(try fixture.adapter().read(unknown))
        XCTAssertThrowsError(try fixture.adapter().write(unknown, value: "3"))
        for value in ["5", "03", "disable", "3;reboot", "", "-1"] { XCTAssertThrowsError(try fixture.adapter().write(package, value: value)) }
        XCTAssertThrowsError(try fixture.adapter().write(bluetooth, value: "true"))
        XCTAssertTrue(fixture.commands.isEmpty)
    }

    func testMutationRejectsExitZeroErrorsMissingAcknowledgementAndWrongAcknowledgement() {
        let fixture = AndroidResourceFixture()
        for output in ["Error: permission denied\n", "Exception occurred while executing 'disable-user':\njava.lang.SecurityException: denied\n", "", "Package unrelated.private.app new state: disabled-user\n", "Package \(package.id) new state: enabled\n"] {
            fixture.responses["shell pm disable-user --user 0 \(package.id)"] = output
            XCTAssertThrowsError(try fixture.adapter().write(package, value: "3"), output)
        }
        for output in ["cmd: Can't find service: bluetooth_manager\n", "false\n", "Unknown error\n", "Success\n", "BluetoothShellCommand: Exec enable\nenable: Success\n", "BluetoothShellCommand: Exec disable\nenable: Success\n", "BluetoothShellCommand: Exec disable\ndisable: Failed\n"] {
            fixture.responses["shell cmd bluetooth_manager disable"] = output
            XCTAssertThrowsError(try fixture.adapter().write(bluetooth, value: "off"))
        }
    }

    func testRunnerFailureNonzeroTruncationAndInvalidUTF8FailClosed() {
        for mode in [AndroidResourceFixture.Mode.timeout, .nonzero, .stdoutTruncated, .stderrTruncated, .invalidUTF8, .stderrError] {
            let fixture = AndroidResourceFixture()
            fixture.mode = mode
            XCTAssertThrowsError(try fixture.adapter().identity())
            XCTAssertThrowsError(try fixture.adapter().read(package))
            XCTAssertThrowsError(try fixture.adapter().write(bluetooth, value: "off"))
            XCTAssertThrowsError(try fixture.adapter().measure())
        }
    }

    func testMemoryCountsOnlyAllowlistedPSSIncludingProcessSuffixesAndBluetoothHAL() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell dumpsys meminfo --oom"] = """
        Applications Memory Usage (in Kilobytes):
        Total RSS by OOM adjustment:
            999,999K: Native
                999,999K: \(package.id):search (pid 10)
        Total PSS by OOM adjustment:
            556,220K: Native
                118,620K: zygote64 (pid 366)
                13K: android.hardware.bluetooth@1.1-service (pid 13)
                17K: android.hardware.bluetooth-service.default (pid 14)
                19K: android.hardware.bluetooth@1.1-service.sim (pid 17)
            123,550K: Cached
                123,456K: \(package.id):search (pid 10 / activities)
                7K: \(package.id):interactor (pid 11)
                11K: com.android.bluetooth (pid 12)
                22K: private.customer.app (pid 15)
                27K: \(package.id).imposter (pid 16)
        Total RAM: 2,000,000K (status normal)
                888,888K: \(package.id):search (pid 10)
        """
        let memory = try fixture.adapter().measure()
        XCTAssertEqual(memory.metric, "guest_pss_bytes")
        XCTAssertFalse(memory.partial)
        XCTAssertEqual(memory.processes.map(\.pid), [13, 14, 17, 10, 11, 12])
        XCTAssertEqual(memory.processes.first(where: { $0.pid == 10 })?.pssBytes, 123_456 * 1024)
        XCTAssertFalse(memory.processes.contains { $0.name.contains("private") || $0.name.contains("imposter") })
        XCTAssertEqual(fixture.commands.last?.sensitiveOutput, true)
    }

    func testMemoryOverflowDuplicatePIDBadGroupingAndInvalidPIDArePartialWithoutDoubleCounting() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell dumpsys meminfo --oom"] = """
        Total PSS by OOM adjustment:
            100K: Cached
                1K: \(package.id):search (pid 10)
                1K: \(package.id):search (pid 10)
                18014398509481984K: \(package.id) (pid 11)
                1,23K: \(package.id) (pid 12)
                1K: \(package.id) (pid 0)
                1K: \(package.id) (pid 2147483648)
                -1K: \(package.id) (pid 13)
        Total RAM: 100,000K
        """
        let memory = try fixture.adapter().measure()
        XCTAssertTrue(memory.partial)
        XCTAssertNotNil(memory.reason)
        XCTAssertEqual(memory.processes.map(\.pid), [10])
        XCTAssertEqual(memory.processes.first?.pssBytes, 1024)
    }

    func testMemoryOOMCategoriesAreRightAlignedAtDifferentNumericWidths() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell dumpsys meminfo --oom"] = """
        Total PSS by OOM adjustment:
            204,442K: Native
                 11K: android.hardware.bluetooth@1.1-service.sim (pid 10)
              9,442K: System
                  1K: unrelated.system (pid 20)
                442K: Persistent
                  2K: unrelated.persistent (pid 21)
             46,027K: Persistent Service
                 13K: com.android.bluetooth (pid 11)
             78,993K: Foreground
                 17K: \(package.id):search (pid 12)
                  3K: Visible
                  3K: unrelated.visible (pid 22)
             62,649K: Perceptible
                 19K: \(package.id):interactor (pid 13)
                  0K: Cached
                  0K: unrelated.cached (pid 23)
        Total RAM: 2,000,000K
        """
        let memory = try fixture.adapter().measure()
        XCTAssertFalse(memory.partial)
        XCTAssertEqual(memory.processes.map(\.pid), [10, 11, 12, 13])
        XCTAssertEqual(memory.processes.map(\.pssBytes), [11, 13, 17, 19].map { UInt64($0) * 1024 })
    }

    func testMemoryUnknownOrMalformedOOMBucketsRemainPartial() throws {
        let fixture = AndroidResourceFixture()
        for bucket in ["          1K: Unknown Category", "     12,34K: Native", "         -1K: Cached", "          1K: \(package.id)", "          1K: Native (invalid)"] {
            fixture.responses["shell dumpsys meminfo --oom"] = "Total PSS by OOM adjustment:\n\(bucket)\n        1K: \(package.id) (pid 10)\nTotal RAM: 100K\n"
            XCTAssertTrue(try fixture.adapter().measure().partial, bucket)
        }
    }

    func testMemoryMissingRepeatedOrUnterminatedSectionIsPartial() throws {
        let fixture = AndroidResourceFixture()
        for output in ["Total RSS by OOM adjustment:\n    1K: Cached\n        1K: \(package.id) (pid 10)\nTotal RAM: 100K\n", "Total PSS by OOM adjustment:\n    1K: Cached\n        1K: \(package.id) (pid 10)\n", "Total PSS by OOM adjustment:\n    1K: Cached\n        1K: \(package.id) (pid 10)\nTotal PSS by OOM adjustment:\n    1K: Cached\n        1K: \(package.id) (pid 10)\nTotal RAM: 100K\n", "Total PSS by OOM adjustment:\n    malformed category\n        1K: \(package.id) (pid 10)\nTotal RAM: 100K\n"] {
            fixture.responses["shell dumpsys meminfo --oom"] = output
            XCTAssertTrue(try fixture.adapter().measure().partial, output)
        }
    }

    func testMemoryZeroAndLargestNonoverflowingKiBValues() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell dumpsys meminfo --oom"] = "Total PSS by process:\n  0K: \(package.id) (pid 10)\n  18014398509481983K: \(package.id):search (pid 11)\nTotal PSS by OOM adjustment:\n"
        let memory = try fixture.adapter().measure()
        XCTAssertFalse(memory.partial)
        XCTAssertEqual(memory.processes.map(\.pssBytes), [0, (UInt64.max / 1024) * 1024])
    }

    func testMemoryLegacyProcessSectionAndOOMSectionDoNotDoubleCount() throws {
        let fixture = AndroidResourceFixture()
        fixture.responses["shell dumpsys meminfo --oom"] = "Total PSS by process:\n  7K: \(package.id) (pid 10)\nTotal PSS by OOM adjustment:\n    7K: Cached\n        7K: \(package.id) (pid 10)\nTotal RAM: 100K\n"
        let memory = try fixture.adapter().measure()
        XCTAssertFalse(memory.partial)
        XCTAssertEqual(memory.processes.map(\.pssBytes), [7 * 1024])
    }

    private func packageDump(_ user: String) -> String { "Packages:\n  Package [\(package.id)] (abc):\n    \(user)\n" }
}

private final class AndroidResourceFixture {
    enum Mode { case normal, timeout, nonzero, stdoutTruncated, stderrTruncated, invalidUTF8, stderrError }
    enum FixtureError: Error { case timeout, unexpectedCommand }
    var mode = Mode.normal
    var commands: [TKHostCommand] = []
    var responses: [String: String] = [
        "get-state": "device\n",
        "shell getprop ro.kernel.qemu": "1\n",
        "shell getprop ro.boot.qemu": "\n",
        "shell getprop ro.boot.qemu.avd_name": "Fixture_API_34\n",
        "shell getprop ro.build.fingerprint": "google/sdk/arm64:14/ABC/123:userdebug/test-keys\n",
        "shell cat /proc/sys/kernel/random/boot_id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE\n"
    ]

    func adapter(device: String = "emulator-5556") -> AndroidResourceAdapter {
        AndroidResourceAdapter(device: device, executable: "/fixture/adb", runner: run)
    }

    func run(_ command: TKHostCommand) throws -> HostProcessResult {
        commands.append(command)
        if mode == .timeout { throw FixtureError.timeout }
        let key = command.arguments.dropFirst(2).joined(separator: " ")
        guard let value = responses[key] ?? (mode == .normal ? nil : "fixture") else { throw FixtureError.unexpectedCommand }
        let data = mode == .invalidUTF8 ? Data([0xff]) : Data(value.utf8)
        let stderr = mode == .stderrError ? Data("Error: permission denied\n".utf8) : Data()
        return HostProcessResult(stdoutData: data, stderrData: stderr, exitCode: mode == .nonzero ? 1 : 0,
            sourceCommand: "fixture", stdoutTruncated: mode == .stdoutTruncated, stderrTruncated: mode == .stderrTruncated,
            stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: data.count, stderrBytes: stderr.count)
    }
}
