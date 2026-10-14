import Foundation
import XCTest
import TritonKitShared
@testable import TritonKitCLI

final class SimulatorResourceMutationTests: XCTestCase {
    let udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

    func testKeptWidgetsPreserveNavdInActualProfilePlanner() {
        let profile = TKSimulatorResourceProfile(id: "custom", disabledCategories: [.connectivity])
        XCTAssertFalse(SimulatorResourceMutationPlanner.labels(for: profile).contains("com.apple.navd"))
    }

    func testApplyStockRepairsLegacyProtectedAndManagedWithoutTouchingUserOverrides() throws {
        let runner = ResourceFixtureRunner(overrides: ["com.apple.assistantd": true, "com.apple.gamed": true, "com.apple.apsd": true, "private.custom": true])
        let runtime = CLISimulatorResourceRuntime(runner: runner)
        let receipt = try runtime.apply(.init(action: .apply, udid: udid, profile: "stock", noReboot: true), previous: status)
        XCTAssertEqual(runner.overrides["com.apple.assistantd"], false)
        XCTAssertEqual(runner.overrides["com.apple.gamed"], false)
        XCTAssertEqual(runner.overrides["com.apple.apsd"], false)
        XCTAssertEqual(runner.overrides["private.custom"], true)
        XCTAssertEqual(receipt.previousManagedDisabled, ["com.apple.assistantd", "com.apple.gamed", "com.apple.apsd"])
        XCTAssertEqual(receipt.appliedManagedDisabled, [])
    }

    func testVerifyStockRejectsProtectedDisablementAndUnexpectedManagedLabels() {
        for label in ["com.apple.assistantd", "com.apple.gamed", "com.apple.apsd"] {
            let runner = ResourceFixtureRunner(overrides: [label: true])
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).verify(.init(action: .verify, udid: udid, profile: "stock")))
        }
    }

    func testOfflineApplyPreservesUserLabelsAndUsesSameDesiredProfile() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let oldRoot = SimulatorResourceOfflineStore.root
        SimulatorResourceOfflineStore.root = try resourceFixturePhysicalPath(root)
        defer { SimulatorResourceOfflineStore.root = oldRoot }
        let plist = SimulatorResourceOfflineStore.url(for: udid)
        try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: false)
        try PropertyListSerialization.data(fromPropertyList: ["private.custom": true, "private.enabled": false, "com.apple.assistantd": true, "com.apple.apsd": true], format: .xml, options: 0).write(to: plist)
        let runner = ResourceFixtureRunner(overrides: [:], offlineDevice: udid)
        let receipt = try CLISimulatorResourceRuntime(runner: runner).apply(.init(action: .apply, udid: udid, profile: "stock"), previous: status)
        let entries = try SimulatorResourceOfflineStore.read(udid)
        XCTAssertEqual(entries["private.custom"], true)
        XCTAssertEqual(entries["private.enabled"], false)
        XCTAssertEqual(entries["com.apple.assistantd"], false)
        XCTAssertEqual(entries["com.apple.apsd"], false)
        XCTAssertEqual(receipt.previousManagedDisabled, ["com.apple.assistantd", "com.apple.apsd"])
        XCTAssertEqual(receipt.appliedManagedDisabled, [])
        XCTAssertTrue(runner.commands.contains { $0.arguments.contains("bootstatus") })
    }

    func testRestorePreservesUserChangesAndNeverDisablesProtectedServices() throws {
        let runner = ResourceFixtureRunner(overrides: ["com.apple.apsd": false, "com.apple.searchd": false, "private.custom": true])
        let receipt = TKSimulatorResourceReceipt(udid: udid, profile: .init(id: "custom"), previous: status, applied: status, noReboot: true,
            previousManagedDisabled: ["com.apple.assistantd", "com.apple.gamed", "com.apple.searchd"], appliedManagedDisabled: ["com.apple.apsd"])
        try CLISimulatorResourceRuntime(runner: runner).restore(receipt)
        XCTAssertFalse(runner.commands.contains { $0.arguments.last == "system/com.apple.apsd" })
        XCTAssertNil(runner.overrides["com.apple.assistantd"])
        XCTAssertNil(runner.overrides["com.apple.gamed"])
        XCTAssertEqual(runner.overrides["com.apple.searchd"], true)
        XCTAssertEqual(runner.overrides["private.custom"], true)
    }

    func testRestorePreservesUserRemovalOfEnabledOverride() throws {
        let runner = ResourceFixtureRunner(overrides: [:])
        let receipt = TKSimulatorResourceReceipt(udid: udid, profile: .init(id: "stock"), previous: status, applied: status, noReboot: true, previousManagedDisabled: ["com.apple.searchd"])
        try CLISimulatorResourceRuntime(runner: runner).restore(receipt)
        XCTAssertNil(runner.overrides["com.apple.searchd"])
        XCTAssertFalse(runner.commands.contains { $0.arguments.contains("disable") })
    }

    func testRestoreRejectsForgedUnmanagedLabelBeforeCommands() {
        let runner = ResourceFixtureRunner(overrides: [:])
        let receipt = TKSimulatorResourceReceipt(udid: udid, profile: .init(id: "stock"), previous: status, applied: status, noReboot: true, appliedManagedDisabled: ["private.custom"])
        XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).restore(receipt))
        XCTAssertTrue(runner.commands.isEmpty)
    }

    func testRestoreChecksEnableExitAndReadback() {
        for behavior in [ResourceFixtureRunner.Behavior.fail, .ignore] {
            let runner = ResourceFixtureRunner(overrides: ["com.apple.apsd": true], behavior: behavior)
            let receipt = TKSimulatorResourceReceipt(udid: udid, profile: .init(id: "stock"), previous: status, applied: status, noReboot: true, appliedManagedDisabled: ["com.apple.apsd"])
            XCTAssertThrowsError(try CLISimulatorResourceRuntime(runner: runner).restore(receipt))
        }
    }

    var status: TKSimulatorResourceStatus { .init(udid: udid, runtime: "fixture") }
}

private final class ResourceFixtureRunner: SimulatorResourceCommandRunning {
    enum Behavior { case normal, fail, ignore }
    var overrides: [String: Bool]
    var commands: [TKHostCommand] = []
    let behavior: Behavior
    let offlineDevice: String?
    init(overrides: [String: Bool], behavior: Behavior = .normal, offlineDevice: String? = nil) { self.overrides = overrides; self.behavior = behavior; self.offlineDevice = offlineDevice }
    func run(_ command: TKHostCommand) throws -> HostProcessResult {
        commands.append(command)
        var output = ""
        var exit: Int32 = 0
        if command.arguments == ["simctl", "list", "devices", "available", "--json"], let offlineDevice {
            output = "{\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-26-0\":[{\"udid\":\"\(offlineDevice)\",\"name\":\"Fixture\",\"state\":\"Shutdown\",\"isAvailable\":true}]}}"
        } else if command.arguments.contains("bootstatus"), let offlineDevice {
            overrides = try SimulatorResourceOfflineStore.read(offlineDevice)
        } else if command.arguments.contains("print-disabled") {
            output = "disabled services = {\n" + overrides.sorted(by: { $0.key < $1.key }).map { "\"\($0.key)\" => \($0.value ? "true" : "false")" }.joined(separator: "\n") + "\n}"
        } else if command.arguments.contains("enable") || command.arguments.contains("disable") {
            if behavior == .fail { exit = 1 }
            if behavior == .normal, let label = command.arguments.last?.split(separator: "/").last {
                overrides[String(label)] = command.arguments.contains("disable")
            }
        }
        return HostProcessResult(stdoutData: Data(output.utf8), stderrData: Data(), exitCode: exit, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: output.utf8.count, stderrBytes: 0)
    }
}
