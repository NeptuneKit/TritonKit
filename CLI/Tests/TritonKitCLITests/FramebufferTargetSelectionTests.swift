import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Framebuffer target selection")
struct FramebufferTargetSelectionTests {
    @Test("Harmony raw, canonical, and host-wrapped selectors use only HDC list", arguments: [
        "127.0.0.1:10101", "harmony:127.0.0.1:10101", "host:harmony:127.0.0.1:10101",
    ])
    func harmonyExplicit(_ selector: String) throws {
        let fixture = FramebufferTargetFixture()
        let result = try fixture.resolve(.harmony, selector)
        #expect(result == "127.0.0.1:10101")
        #expect(fixture.calls == ["fixture-hdc list targets -v"])
    }

    @Test("Android raw, canonical, and host-wrapped selectors use only ADB list", arguments: [
        "emulator-5554", "android:emulator-5554", "host:android:emulator-5554",
    ])
    func androidExplicit(_ selector: String) throws {
        let fixture = FramebufferTargetFixture()
        let result = try fixture.resolve(.android, selector)
        #expect(result == "emulator-5554")
        #expect(fixture.calls == ["fixture-adb devices -l"])
    }

    @Test("Aliases preserve existing resolution without querying foreground apps")
    func aliases() throws {
        for (platform, raw, canonical) in [(HostDevicePlatform.harmony, "127.0.0.1:10101", "harmony:127.0.0.1:10101"), (.android, "emulator-5554", "android:emulator-5554")] {
            let fixture = FramebufferTargetFixture()
            let aliases = HostTargetAliasStore(aliases: ["preview": .init(platform: platform, target: canonical)])
            #expect(try fixture.resolve(platform, "preview", aliases: aliases) == raw)
            #expect(fixture.calls.count == 1)
        }
    }

    @Test("Stored current reuses the alias resolver and never calls the live fallback")
    func storedCurrent() throws {
        let fixture = FramebufferTargetFixture()
        let aliases = HostTargetAliasStore(current: "preview", aliases: ["preview": .init(platform: .harmony, target: "127.0.0.1:10101")])
        var fallbackCalls = 0
        #expect(try fixture.resolve(.harmony, "current", aliases: aliases, fallback: {
            fallbackCalls += 1
            return harmonySelection()
        }) == "127.0.0.1:10101")
        #expect(fallbackCalls == 0)
        #expect(fixture.calls == ["fixture-hdc list targets -v"])
    }

    @Test("Unknown and other-platform canonical selectors fail without a raw fallback", arguments: [
        "missing-device", "android:emulator-5554",
    ])
    func unknown(_ selector: String) {
        let fixture = FramebufferTargetFixture()
        var fallbackCalls = 0
        do {
            _ = try fixture.resolve(.harmony, selector, fallback: {
                fallbackCalls += 1
                return harmonySelection()
            })
            Issue.record("Unknown selector must not become an HDC target")
        } catch HostDeviceSelectionError.targetNotFound(let value) {
            #expect(value == selector)
        } catch { Issue.record("Unexpected error: \(error)") }
        #expect(fallbackCalls == 0)
        #expect(fixture.calls == ["fixture-hdc list targets -v"])
    }

    @Test("Other-platform host wrapper fails before running any tool")
    func wrongHostPlatform() {
        let fixture = FramebufferTargetFixture()
        do {
            _ = try fixture.resolve(.harmony, "host:android:emulator-5554")
            Issue.record("Wrong platform must fail")
        } catch HostDeviceSelectionError.platformMismatch(_, let expected, let actual) {
            #expect(expected == .harmony)
            #expect(actual == .android)
        } catch { Issue.record("Unexpected error: \(error)") }
        #expect(fixture.calls.isEmpty)
    }

    @Test("Other-platform aliases preserve the resolver's mismatch error")
    func wrongAliasPlatform() {
        let fixture = FramebufferTargetFixture()
        let aliases = HostTargetAliasStore(aliases: ["preview": .init(platform: .android, target: "emulator-5554")])
        do {
            _ = try fixture.resolve(.harmony, "preview", aliases: aliases)
            Issue.record("Wrong platform alias must fail")
        } catch HostDeviceSelectionError.platformMismatch(_, let expected, let actual) {
            #expect(expected == .harmony)
            #expect(actual == .android)
        } catch { Issue.record("Unexpected error: \(error)") }
        #expect(fixture.calls == ["fixture-hdc list targets -v"])
    }

    @Test("Only unresolved current may invoke the explicit live fallback", arguments: ["current", "host:harmony:current"])
    func liveCurrent(_ selector: String) throws {
        let fixture = FramebufferTargetFixture()
        var fallbackCalls = 0
        #expect(try fixture.resolve(.harmony, selector, fallback: {
            fallbackCalls += 1
            return harmonySelection()
        }) == "127.0.0.1:10101")
        #expect(fallbackCalls == 1)
        #expect(fixture.calls == ["fixture-hdc list targets -v"])
    }

    @Test("Current without a fallback is an explicit target-not-found error")
    func missingCurrent() {
        let fixture = FramebufferTargetFixture()
        #expect(throws: HostDeviceSelectionError.self) { _ = try fixture.resolve(.harmony, "current") }
        #expect(fixture.calls == ["fixture-hdc list targets -v"])
    }

    @Test("A live fallback cannot switch the route to another platform")
    func crossPlatformFallback() {
        let fixture = FramebufferTargetFixture()
        let target = hostDeviceTarget(from: TKAndroidTarget(serial: "emulator-5554", state: "device"))
        do {
            _ = try fixture.resolve(.harmony, "current", fallback: {
                HostDeviceSelectionResult(platform: .android, target: target, selector: "current", source: .current,
                                          filters: .init(request: .init(device: "current", platform: .android)))
            })
            Issue.record("Fallback must remain scoped to this route")
        } catch HostDeviceSelectionError.platformMismatch(_, let expected, let actual) {
            #expect(expected == .harmony)
            #expect(actual == .android)
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test("Harmony plain-list fallback remains bounded to HDC discovery")
    func plainList() throws {
        let fixture = FramebufferTargetFixture()
        fixture.verbose = "Connect server failed\n"
        #expect(try fixture.resolve(.harmony, "127.0.0.1:10101") == "127.0.0.1:10101")
        #expect(fixture.calls == ["fixture-hdc list targets -v", "fixture-hdc list targets"])
    }

    @Test("Malformed host selectors and empty targets fail before tools", arguments: ["", " ", "host:harmony:", "host:bogus:fixture"])
    func malformed(_ selector: String) {
        let fixture = FramebufferTargetFixture()
        #expect(throws: HostDeviceSelectionError.self) { _ = try fixture.resolve(.harmony, selector) }
        #expect(fixture.calls.isEmpty)
    }

    @Test("iOS is not routed through the Android/Harmony resolver")
    func unsupportedIOS() {
        let fixture = FramebufferTargetFixture()
        do {
            _ = try fixture.resolve(.ios, "fixture")
            Issue.record("iOS uses its own simulator capture resolver")
        } catch HostDeviceSelectionError.parameterConflict { }
        catch { Issue.record("Unexpected error: \(error)") }
        #expect(fixture.calls.isEmpty)
    }

    @Test("Offline alias targets are rejected before capture")
    func offlineAlias() {
        let fixture = FramebufferTargetFixture()
        fixture.android = "List of devices attached\nemulator-5554 offline product:fixture model:Fixture device:fixture\n"
        let aliases = HostTargetAliasStore(aliases: ["preview": .init(platform: .android, target: "emulator-5554")])
        #expect(throws: HostDeviceRunError.self) { _ = try fixture.resolve(.android, "preview", aliases: aliases) }
        #expect(fixture.calls == ["fixture-adb devices -l"])
    }

    @Test("Discovery errors propagate without invoking the live fallback")
    func discoveryFailure() {
        let fixture = FramebufferTargetFixture()
        fixture.fail = true
        var fallbackCalls = 0
        #expect(throws: HostCommandRunError.self) {
            _ = try fixture.resolve(.harmony, "current", fallback: {
                fallbackCalls += 1
                return harmonySelection()
            })
        }
        #expect(fixture.calls == ["fixture-hdc list targets -v"])
        #expect(fallbackCalls == 0)
    }
}

private func harmonySelection() -> HostDeviceSelectionResult {
    let target = hostDeviceTarget(from: TKHarmonyTarget(target: "127.0.0.1:10101", state: "Connected", transport: "TCP"))
    return HostDeviceSelectionResult(platform: .harmony, target: target, selector: "current", source: .current,
                                    filters: .init(request: .init(device: "current", platform: .harmony)))
}

private final class FramebufferTargetFixture {
    var calls: [String] = []
    var verbose = "127.0.0.1:10101\t\tTCP\tConnected\tlocalhost\n127.0.0.1:10102\t\tTCP\tConnected\tlocalhost\n"
    var android = "List of devices attached\nemulator-5554 device product:fixture model:Fixture device:fixture transport_id:1\n"
    var fail = false
    func run(_ command: TKHostCommand) throws -> HostProcessResult {
        calls.append(([command.executable] + command.arguments).joined(separator: " "))
        if fail { throw HostCommandRunError.launchFailed("fixture discovery failure") }
        let output: String
        switch (command.executable, command.arguments) {
        case ("fixture-hdc", ["list", "targets", "-v"]): output = verbose
        case ("fixture-hdc", ["list", "targets"]): output = "127.0.0.1:10101\n"
        case ("fixture-adb", ["devices", "-l"]): output = android
        default: throw HostCommandRunError.launchFailed("Unexpected external command in fixture: \(calls.last!)")
        }
        let data = Data(output.utf8)
        return HostProcessResult(stdoutData: data, stderrData: Data(), exitCode: 0,
                                 sourceCommand: hostSourceCommand(command), stdoutTruncated: false, stderrTruncated: false,
                                 stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: data.count, stderrBytes: 0)
    }
    func resolve(_ platform: HostDevicePlatform, _ target: String, aliases: HostTargetAliasStore = .empty,
                 fallback: (() throws -> HostDeviceSelectionResult)? = nil) throws -> String {
        try resolveFramebufferTarget(platform: platform, target: target, hdc: "fixture-hdc", adb: "fixture-adb",
                                     runner: run, aliases: aliases, liveCurrentResolver: fallback)
    }
}
