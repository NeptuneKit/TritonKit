import ArgumentParser
import Testing
@testable import TritonKitCLI

@Suite("Xcode 26 command retention")
struct LegacyAppleCommandRetentionTests {
    @Test("Device Hub adaptation must retain existing sim, app, device and xcode registrations")
    func existingRegistrationsRemain() {
        // Pinned existing CLI surface, including hidden compatibility commands.
        // This is a retention guard, not an assertion that Xcode 26 is installed.
        let expectedSim: Set<String> = ["list", "resource", "use", "create", "boot", "shutdown", "pair", "unpair", "clone", "erase", "upgrade", "screenshot", "tap", "type", "record", "logs", "app-console", "diagnose", "logverbose", "proxy", "runtime", "status-bar", "privacy", "location", "ui", "pasteboard", "push", "media", "personalization", "ax"]
        let expectedApp: Set<String> = ["list", "info", "inspect", "install", "uninstall", "launch", "terminate", "go", "open-url", "container", "pull", "prefs"]
        let expectedDevice: Set<String> = ["doctor", "bridge", "proxy", "list", "alias", "use", "current", "resolve", "wait-ready", "screenshot", "runtime-url", "start", "stop"]
        let expectedXcode: Set<String> = ["discover", "use", "schemes", "status", "wait-idle", "settings", "build", "test", "archive", "export", "run", "derived-data"]
        #expect(expectedSim.isSubset(of: names(Sim.configuration)))
        #expect(expectedApp.isSubset(of: names(HostApp.configuration)))
        #expect(expectedDevice.isSubset(of: names(Device.configuration)))
        #expect(expectedXcode.isSubset(of: names(Xcode.configuration)))
    }

    @Test("old simulator lifecycle arguments still parse without introducing a mandatory workflow")
    func oldArgumentFormsRemain() throws {
        let boot = try #require(TritonKitCLI.parseAsRoot(["sim", "boot", "FIXTURE-SIM", "--wait", "--json"]) as? SimBoot)
        #expect(boot.json && boot.wait)
        #expect(boot.udid == "FIXTURE-SIM")
        let install = try #require(TritonKitCLI.parseAsRoot(["app", "install", "--app", "Fixture.app", "--simulator", "FIXTURE-SIM", "--json"]) as? HostAppInstall)
        #expect(install.json)
        #expect(install.app == "Fixture.app" && install.simulator == "FIXTURE-SIM")
        let launch = try #require(TritonKitCLI.parseAsRoot(["app", "launch", "--bundle-id", "fixture.app", "--simulator", "FIXTURE-SIM", "--json"]) as? HostAppLaunch)
        #expect(launch.json)
        #expect(launch.bundleID == "fixture.app" && launch.simulator == "FIXTURE-SIM")
        let terminate = try #require(TritonKitCLI.parseAsRoot(["app", "terminate", "--bundle-id", "fixture.app", "--simulator", "FIXTURE-SIM", "--json"]) as? HostAppTerminate)
        #expect(terminate.json)
        #expect(terminate.bundleID == "fixture.app" && terminate.simulator == "FIXTURE-SIM")
        let uninstall = try #require(TritonKitCLI.parseAsRoot(["app", "uninstall", "--bundle-id", "fixture.app", "--simulator", "FIXTURE-SIM", "--confirm", "--json"]) as? HostAppUninstall)
        #expect(uninstall.confirm && uninstall.json)
        #expect(uninstall.bundleID == "fixture.app" && uninstall.simulator == "FIXTURE-SIM")
    }

    private func names(_ configuration: CommandConfiguration) -> Set<String> {
        Set(configuration.subcommands.compactMap { $0.configuration.commandName })
    }
}
