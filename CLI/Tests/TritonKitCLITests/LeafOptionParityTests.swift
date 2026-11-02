import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("SP-261 reported leaf option parity")
struct LeafOptionParityTests {
    @Test func bootFullAndCompactExposeEveryHelpOptionAndRequiredUDID() throws {
        let full = try #require(buildSchemaResponse(command: "sim.boot").commands.first)
        let leaf = try #require(full.subcommands.first)
        let compact = try buildCompactSchemaResponse(command: "sim.boot")
        let expected = helpOptions(SimBoot.helpMessage())
        #expect(expected.contains("--timeout") && expected.contains("--interval"))
        #expect(Set(leaf.optionalOptions) == expected)
        #expect(optionNames(compact.options) == expected)
        #expect(leaf.requiredOptions == ["<udid>"])
        #expect(full.argumentForms.contains { $0.name == "<udid>" })
        #expect(compact.requiredOptions == ["<udid>"])
        #expect(compact.argumentForms.count == 1)
        #expect(compact.argumentForms.first?.name == "<udid>")
        #expect(compact.argumentForms.first?.required == true)
        #expect(!compact.options.contains { $0.name == "--simulator" })
    }

    @Test func bootDefaultsAndOverridesMatchParserWithoutBooting() throws {
        let parsed = try #require(TritonKitCLI.parseAsRoot(["sim", "boot", "fixture-udid"]) as? SimBoot)
        let full = try #require(buildSchemaResponse(command: "sim.boot").commands.first)
        let leaf = try #require(full.subcommands.first)
        let compact = try buildCompactSchemaResponse(command: "sim.boot")
        #expect(parsed.timeout == 60 && parsed.interval == 1)
        let defaults = ["--timeout": String(Int(parsed.timeout)), "--interval": String(Int(parsed.interval)), "--wait": String(parsed.wait), "--jsonl": String(parsed.jsonl), "--json": String(parsed.json), "--format": parsed.format.rawValue]
        for (name, value) in defaults {
            #expect(effectiveOption(name, root: full, leaf: leaf)?.defaultValue == value)
            #expect(compact.options.first { $0.name == name }?.defaultValue == value)
        }
        // The shared catalog keeps the other simulator commands' old timeout.
        #expect(full.options.first { $0.name == "--timeout" }?.defaultValue == "300")
        let explicit = try #require(TritonKitCLI.parseAsRoot(["sim", "boot", "fixture-udid", "--wait", "--timeout", "12.5", "--interval", "0.25", "--jsonl", "--json"]) as? SimBoot)
        #expect(explicit.udid == "fixture-udid")
        #expect(explicit.wait && explicit.jsonl && explicit.json)
        #expect(explicit.timeout == 12.5 && explicit.interval == 0.25)
        #expect(throws: (any Error).self) { try SimBoot.parse([]) }
        #expect(throws: (any Error).self) { try SimBoot.parse(["fixture-udid", "--timeout", "invalid"]) }
        let json = try #require(JSONSerialization.jsonObject(with: Data(encodeJSON(compact).utf8)) as? [String: Any])
        let options = try #require(json["options"] as? [[String: Any]])
        #expect(options.first { $0["name"] as? String == "--timeout" }?["defaultValue"] as? String == "60")
    }

    @Test func tapFullAndCompactMatchHelpOptionsAndOptionalQuery() throws {
        let full = try #require(buildSchemaResponse(command: "act.tap").commands.first)
        let leaf = try #require(full.subcommands.first)
        let compact = try buildCompactSchemaResponse(command: "act.tap")
        let expected = helpOptions(Tap.helpMessage())
        #expect(expected.contains("--width") && expected.contains("--height"))
        #expect(Set(leaf.optionalOptions.filter { $0.hasPrefix("--") }) == expected)
        #expect(optionNames(compact.options) == expected)
        #expect(leaf.optionalOptions.contains("<query>"))
        #expect(compact.argumentForms.count == 1)
        #expect(compact.argumentForms.first?.name == "<query>")
        #expect(compact.argumentForms.first?.required == false)
        #expect(compact.options.contains { $0.name == "--target/--device" })
        #expect(!compact.options.contains { $0.name == "--start-x" })
    }

    @Test func tapDefaultsGeometryAndTextAliasesMatchParserWithoutTapping() throws {
        let parsed = try #require(TritonKitCLI.parseAsRoot(["act", "tap"]) as? Tap)
        let full = try #require(buildSchemaResponse(command: "act.tap").commands.first)
        let leaf = try #require(full.subcommands.first)
        let compact = try buildCompactSchemaResponse(command: "act.tap")
        let defaults = ["--host": parsed.host, "--port": String(parsed.port), "--target": parsed.target, "--device": parsed.target, "--adb": parsed.adb, "--hdc": parsed.hdc, "--format": parsed.format.rawValue, "--json": String(parsed.json), "--allow-host-hid-fallback": String(parsed.allowHostHIDFallback), "--hid-only": String(parsed.hidOnly), "--webview-aware": String(parsed.webViewAware), "--timeout": String(Int(parsed.timeout))]
        for name in helpOptions(Tap.helpMessage()) {
            #expect(effectiveOption(name, root: full, leaf: leaf)?.defaultValue == defaults[name])
            #expect(compact.options.first { aliases($0.name).contains(name) }?.defaultValue == defaults[name])
        }
        let explicit = try #require(TritonKitCLI.parseAsRoot(["act", "tap", "Fixture label", "--width", "320.5", "--height", "640.5", "--device", "fixture-target", "--json"]) as? Tap)
        #expect(explicit.query == "Fixture label")
        #expect(explicit.width == 320.5 && explicit.height == 640.5)
        #expect(explicit.target == "fixture-target")
        let flag = try #require(TritonKitCLI.parseAsRoot(["act", "tap", "--text", "Fixture label"]) as? Tap)
        #expect(flag.text == explicit.query)
        #expect(throws: (any Error).self) { try Tap.parse(["--width", "invalid"]) }
    }

    @Test func nestedStopCanonicalPathsRemainSelfContained() throws {
        let runner = try buildCompactSchemaResponse(command: "device.runner.stop")
        let spaced = try buildCompactSchemaResponse(command: " device runner stop ")
        let device = try buildCompactSchemaResponse(command: "device.stop")
        #expect(runner.command == "device.runner.stop")
        #expect(device.command == "device.stop")
        #expect(runner.fullSchemaCommand == ["triton", "schema", "--command", "device.runner.stop", "--json"])
        #expect(device.fullSchemaCommand == ["triton", "schema", "--command", "device.stop", "--json"])
        #expect(runner.fingerprint == spaced.fingerprint)
        #expect(runner.fingerprint != device.fingerprint)
        #expect(runner.summary != device.summary)
    }

    @Test func deviceStopOptionsAndDefaultsMatchParserWithoutStopping() throws {
        let parsed = try #require(TritonKitCLI.parseAsRoot(["device", "stop"]) as? DeviceStop)
        let full = try #require(buildSchemaResponse(command: "device.stop").commands.first)
        let leaf = try #require(full.subcommands.first)
        let compact = try buildCompactSchemaResponse(command: "device.stop")
        let expected = helpOptions(DeviceStop.helpMessage())
        #expect(Set(leaf.optionalOptions) == expected)
        #expect(optionNames(compact.options) == expected)
        #expect(compact.argumentForms.isEmpty)
        #expect(leaf.requiresConfirmation && compact.requiresConfirmation)
        #expect(!compact.options.contains { $0.name == "--timeout" || $0.name == "--scope" || $0.name == "--plan-only" })
        let defaults = ["--platform": parsed.platform.rawValue, "--adb": parsed.adb, "--emulator": parsed.emulator, "--launchd-label": parsed.launchdLabel, "--launchd-domain": "gui/<uid>", "--skip-launchd": String(parsed.skipLaunchd), "--confirm": String(parsed.confirm), "--json": String(parsed.json), "--format": parsed.format.rawValue]
        // This process-dependent default is represented symbolically in public metadata.
        #expect(parsed.launchdDomain == defaultLaunchdDomain())
        for name in expected {
            #expect(effectiveOption(name, root: full, leaf: leaf)?.defaultValue == defaults[name])
            #expect(compact.options.first { $0.name == name }?.defaultValue == defaults[name])
        }
        let android = try #require(TritonKitCLI.parseAsRoot(["device", "stop", "--platform", "android", "--device", "fixture-emulator", "--confirm", "--json"]) as? DeviceStop)
        #expect(android.platform == .android && android.device == "fixture-emulator" && android.confirm)
        let harmony = try #require(TritonKitCLI.parseAsRoot(["device", "stop", "--hvd", "Fixture HVD", "--path", "/fixture/deployed", "--emulator", "/fixture/Emulator", "--launchd-label", "fixture-job", "--launchd-domain", "gui/fixture", "--skip-launchd", "--confirm"]) as? DeviceStop)
        #expect(harmony.platform == .harmony && harmony.hvd == "Fixture HVD")
        #expect(harmony.path == "/fixture/deployed" && harmony.emulator == "/fixture/Emulator")
        #expect(harmony.launchdLabel == "fixture-job" && harmony.launchdDomain == "gui/fixture")
        #expect(harmony.skipLaunchd && harmony.confirm)
        #expect(throws: (any Error).self) { try DeviceStop.parse(["--scope", "emulator"]) }
    }

    @Test func deviceStopContractMatchesActualEncodedDTOAndOptionalFields() throws {
        let compact = try buildCompactSchemaResponse(command: "device.stop")
        #expect(compact.outputContracts.count == 1)
        let contract = try #require(compact.outputContracts.first)
        #expect(contract.selector == "host.device-stop")
        #expect(contract.model == "HostDeviceStopOutput")
        let required: Set<String> = ["ok", "action", "platform", "sourceCommands", "warnings", "note"]
        #expect(Set(contract.fields.filter(\.required).map(\.name)) == required)
        let fixtures = [
            HostDeviceStopOutput(ok: true, action: "device.stop", platform: "android", target: "android:fixture", adb: "adb", hvd: nil, deployedPath: nil, emulator: nil, launchdLabel: nil, launchdDomain: nil, sourceCommands: ["fixture adb emu kill"], warnings: [], note: "Fixture only"),
            HostDeviceStopOutput(ok: true, action: "device.stop", platform: "harmony", target: nil, adb: nil, hvd: "Fixture HVD", deployedPath: "/fixture/deployed", emulator: "/fixture/Emulator", launchdLabel: "fixture-job", launchdDomain: "gui/fixture", sourceCommands: ["fixture Emulator -stop"], warnings: [], note: "Fixture only"),
            HostDeviceStopOutput(ok: true, action: "device.stop", platform: "harmony", target: nil, adb: nil, hvd: "Fixture HVD", deployedPath: "/fixture/deployed", emulator: "/fixture/Emulator", launchdLabel: nil, launchdDomain: nil, sourceCommands: [], warnings: [], note: "Skip launchd fixture"),
        ]
        var encodedKeys = Set<String>()
        for fixture in fixtures {
            let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture)) as? [String: Any])
            let keys = Set(json.keys)
            #expect(required.isSubset(of: keys))
            encodedKeys.formUnion(keys)
            #expect(json["action"] as? String == "device.stop")
            if fixture.target == nil { #expect(json["target"] == nil) }
            if fixture.launchdLabel == nil { #expect(json["launchdLabel"] == nil && json["launchdDomain"] == nil) }
        }
        #expect(Set(contract.fields.map(\.name)) == encodedKeys)
    }

    private func aliases(_ name: String) -> [String] { name.split(separator: "/").map(String.init) }
    private func optionNames(_ options: [TKCommandSchemaOption]) -> Set<String> { Set(options.flatMap { aliases($0.name) }) }
    private func effectiveOption(_ name: String, root: TKCommandSchema, leaf: TKCommandSubcommandSchema) -> TKCommandSchemaOption? {
        leaf.optionOverrides.last { aliases($0.name).contains(name) } ?? root.options.first { aliases($0.name).contains(name) }
    }

    /// Read only option declaration columns, not mentions in explanatory prose.
    /// Automatic --help/--version are outside the product option inventory.
    private func helpOptions(_ help: String) -> Set<String> {
        let expression = try! NSRegularExpression(pattern: "--[a-z][a-z0-9-]*")
        return Set(help.split(separator: "\n").flatMap { line -> [String] in
            guard line.hasPrefix("  -") else { return [] }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let declaration = trimmed.components(separatedBy: "  ")[0]
            return expression.matches(in: declaration, range: NSRange(declaration.startIndex..., in: declaration)).compactMap {
                Range($0.range, in: declaration).map { String(declaration[$0]) }
            }
        }).subtracting(["--help", "--version"])
    }
}
