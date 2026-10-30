import ArgumentParser
import Darwin
import Foundation
import XCTest
@testable import TritonKitCLI

final class AndroidEmulatorStartOptionsTests: XCTestCase {
    func testExplicitAndroidOptionsAreAcceptedByRootParser() throws {
        for option in ["--no-snapshot", "--disable-vulkan"] {
            let command = try Device.parseAsRoot([
                "start", "--platform", "android", "--avd", "Fixture_API_34",
                option, "--plan-only", "--json",
            ])
            XCTAssertTrue(command is DeviceStart)
        }
    }

    func testLowRAMModeIsNotExposed() throws {
        XCTAssertThrowsError(try Device.parseAsRoot([
            "start", "--platform", "android", "--avd", "Fixture_API_34", "--low-ram", "--plan-only",
        ]))
        let schema = try XCTUnwrap(commandSchemas().first { $0.name == "device" })
        XCTAssertFalse(schema.options.contains { $0.name == "--low-ram" })
    }

    func testSchemaDescribesOptInDefaultsAndBehaviorChanges() throws {
        let schema = try XCTUnwrap(commandSchemas().first { $0.name == "device" })
        let start = try XCTUnwrap(schema.subcommands.first { $0.name == "start" })
        for option in ["--no-snapshot", "--disable-vulkan"] {
            let item = try XCTUnwrap(schema.options.first { $0.name == option })
            XCTAssertEqual(item.type, "Bool")
            XCTAssertEqual(item.defaultValue, "false")
            XCTAssertTrue(item.description.contains("Android"))
            XCTAssertTrue(start.optionalOptions.contains(option))
        }
        XCTAssertTrue(try XCTUnwrap(schema.options.first { $0.name == "--disable-vulkan" }).description.contains("incompatible with Vulkan tests"))
        XCTAssertTrue(DeviceStart.helpMessage().contains("Vulkan tests"))
    }

    func testDefaultPlanDoesNotChangeExistingLaunchBehavior() throws {
        let command = try parsed()
        XCTAssertFalse(command.noSnapshot)
        XCTAssertFalse(command.disableVulkan)
        XCTAssertFalse(command.noSnapshotLoad)
        let plan = try command.makePlan()
        XCTAssertEqual(plan.commands.map(\.arguments), [["@Fixture_API_34"]])
        XCTAssertEqual(plan.note, "Android emulator launch is detached. Use the nextAction wait-ready command before app, hierarchy, screenshot, or smoke actions.")
    }

    func testEachOptionMapsToItsNativeArguments() throws {
        let snapshot = try parsed(["--no-snapshot"]).makePlan()
        XCTAssertEqual(snapshot.commands[0].arguments, ["@Fixture_API_34", "-no-snapshot"])
        XCTAssertTrue(snapshot.note.contains("existing snapshots are retained"))
        let vulkan = try parsed(["--disable-vulkan"]).makePlan()
        XCTAssertEqual(vulkan.commands[0].arguments, ["@Fixture_API_34", "-feature", "-Vulkan"])
        XCTAssertTrue(vulkan.note.contains("incompatible with Vulkan tests"))
        XCTAssertTrue(vulkan.note.contains("do not establish memory savings"))
    }

    func testNoSnapshotOverridesLoadOnlyInEveryArgumentOrder() throws {
        for options in [["--no-snapshot", "--no-snapshot-load"], ["--no-snapshot-load", "--no-snapshot"]] {
            let plan = try parsed(options).makePlan()
            XCTAssertEqual(plan.commands[0].arguments, ["@Fixture_API_34", "-no-snapshot"])
        }
        let loadOnly = try parsed(["--no-snapshot-load"]).makePlan()
        XCTAssertEqual(loadOnly.commands[0].arguments, ["@Fixture_API_34", "-no-snapshot-load"])
    }

    func testCombinedOptionsPreserveExplicitGPUAndMemory() throws {
        let plan = try parsed([
            "--no-snapshot", "--no-snapshot-load", "--disable-vulkan", "--gpu", "host",
            "--memory", "2560", "--headless", "--no-audio", "--no-boot-anim",
        ]).makePlan()
        XCTAssertEqual(plan.commands[0].arguments, [
            "@Fixture_API_34", "-no-window", "-gpu", "host", "-memory", "2560",
            "-no-snapshot", "-feature", "-Vulkan", "-no-audio", "-no-boot-anim",
        ])
        XCTAssertFalse(plan.commands[0].arguments.contains("-lowram"))
        XCTAssertFalse(plan.commands[0].arguments.contains("-skin"))
    }

    func testNewOptionsRejectEveryNonAndroidPlatformBeforeLaunchPlanning() throws {
        for platform in ["ios", "harmony"] {
            for option in ["--no-snapshot", "--disable-vulkan"] {
                let command = try XCTUnwrap(DeviceStart.parseAsRoot([
                    "--platform", platform, "--hvd", "Fixture", "--path", "/fixture/hvd",
                    "--emulator", "/nonexistent/emulator", option, "--plan-only",
                ]) as? DeviceStart)
                XCTAssertThrowsError(try command.makePlan()) { error in
                    guard case HostDeviceSelectionError.parameterConflict(let message) = error else {
                        return XCTFail("Unexpected failure: \(error)")
                    }
                    XCTAssertTrue(message.contains("require --platform android"))
                }
            }
        }
    }

    func testHarmonyDefaultStartPlanIsUnchanged() throws {
        let command = try XCTUnwrap(DeviceStart.parseAsRoot([
            "--platform", "harmony", "--hvd", "Fixture", "--path", "/fixture/hvd",
            "--emulator", "/fixture/Emulator", "--plan-only",
        ]) as? DeviceStart)
        let plan = try command.makePlan()
        XCTAssertEqual(plan.commands[0].arguments, ["-start", "Fixture", "-path", "/fixture/hvd", "-hdcPort", "10100", "-bootmode", "coldboot"])
    }

    func testPlanOnlyEmitsLedgerWithoutStartingExecutable() async throws {
        let command = try parsed(["--no-snapshot", "--disable-vulkan", "--emulator", "/nonexistent/sp244-emulator", "--plan-only", "--json"])
        let text = try await captureOutput { try await command.run() }
        let output = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(output["ok"] as? Bool, true)
        XCTAssertEqual(output["planOnly"] as? Bool, true)
        XCTAssertEqual(output["started"] as? Bool, false)
        XCTAssertEqual(output["executedSourceCommands"] as? [String], [])
        let ledger = try XCTUnwrap(output["sourceCommands"] as? [String])
        XCTAssertEqual(ledger.count, 1)
        XCTAssertTrue(ledger[0].contains("-no-snapshot -feature -Vulkan"))
    }

    private func parsed(_ options: [String] = []) throws -> DeviceStart {
        try XCTUnwrap(DeviceStart.parseAsRoot(["--platform", "android", "--avd", "Fixture_API_34"] + options) as? DeviceStart)
    }

    private func captureOutput(_ operation: () async throws -> Void) async throws -> String {
        let pipe = Pipe()
        fflush(stdout)
        let saved = dup(STDOUT_FILENO)
        XCTAssertGreaterThanOrEqual(saved, 0)
        defer { fflush(stdout); dup2(saved, STDOUT_FILENO); close(saved); try? pipe.fileHandleForWriting.close() }
        XCTAssertGreaterThanOrEqual(dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO), 0)
        try await operation()
        fflush(stdout)
        dup2(saved, STDOUT_FILENO)
        try pipe.fileHandleForWriting.close()
        return String(decoding: try pipe.fileHandleForReading.readToEnd() ?? Data(), as: UTF8.self)
    }
}
